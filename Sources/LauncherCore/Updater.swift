import Foundation

/// A newer launcher build found on GitHub Releases.
public struct UpdateInfo: Equatable, Sendable {
    /// Without the leading "v" of the tag, e.g. "0.2.0".
    public let version: String
    public let notes: String
    public let assetURL: URL
    public let size: Int
    /// Lower-case hex digest from GitHub, when the release has one.
    public let sha256: String?

    public init(version: String, notes: String, assetURL: URL, size: Int, sha256: String?) {
        self.version = version
        self.notes = notes
        self.assetURL = assetURL
        self.size = size
        self.sha256 = sha256
    }
}

/// Every message is a fixed English sentence, so the interface can use it as a translation key.
public enum UpdateError: Error, LocalizedError, Equatable, Sendable {
    case unreachable
    case badResponse
    case insecureDownload
    case downloadFailed
    case sizeMismatch
    case checksumMismatch
    case unpackFailed
    case missingApp
    case wrongBuild
    case badSignature
    case needsApplicationsFolder
    case notAnApp
    case cannotStartInstaller

    public var message: String {
        switch self {
        case .unreachable: return "Couldn't reach GitHub. Check your connection."
        case .badResponse: return "GitHub sent an unexpected reply."
        case .insecureDownload: return "The update download address is not secure."
        case .downloadFailed: return "Couldn't download the update. Check your connection."
        case .sizeMismatch: return "The downloaded update is incomplete. Try again."
        case .checksumMismatch: return "The downloaded update is damaged (checksum mismatch). Try again."
        case .unpackFailed: return "Couldn't unpack the update."
        case .missingApp: return "The update does not contain Ember.app."
        case .wrongBuild: return "The update does not match the release."
        case .badSignature: return "The update's signature is not valid."
        case .needsApplicationsFolder: return "Move Ember to the Applications folder first, then update."
        case .notAnApp: return "Ember is not running as an app, so it can't update itself."
        case .cannotStartInstaller: return "Couldn't start the update installer."
        }
    }

    public var errorDescription: String? { message }
}

/// Dotted numeric versions: "v0.10.0" is newer than "0.9.0". A suffix such as "-beta" is ignored.
public enum UpdateVersion {
    public static func components(_ text: String) -> [Int] {
        var trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") { trimmed.removeFirst() }
        let core = trimmed.split(whereSeparator: { $0 == "-" || $0 == "+" }).first.map(String.init) ?? trimmed
        return core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
    }

    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = components(lhs)
        let b = components(rhs)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(candidate, current) == .orderedDescending
    }
}

/// The fields of GitHub's "latest release" reply that matter here.
private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: String
        let size: Int?
        let digest: String?

        private enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case size
            case digest
        }
    }

    let tagName: String
    let draft: Bool?
    let prerelease: Bool?
    let body: String?
    let assets: [Asset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case draft
        case prerelease
        case body
        case assets
    }
}

/// Looks for a newer launcher on GitHub Releases. No token is sent.
public enum UpdateChecker {
    public static let repository = "SnowyMay111/ember-launcher"
    public static let assetName = "Ember-mac-arm64.zip"
    /// Folder name of the app inside the unpacked update.
    static let appName = "Ember.app"
    /// Points the check at another URL that returns a GitHub-style "latest release" JSON (local tests use a static file).
    public static let overrideVariable = "EMBER_UPDATE_URL"

    private static let session = URLSession(configuration: .ephemeral)

    /// The override exists only in debug builds: a release must never take its update address from the environment.
    static var isOverridden: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment[overrideVariable].flatMap { URL(string: $0) } != nil
        #else
        return false
        #endif
    }

    private static var endpoint: URL {
        #if DEBUG
        if let text = ProcessInfo.processInfo.environment[overrideVariable], let url = URL(string: text) {
            return url
        }
        #endif
        return URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    /// The newer release, or nil when there is none or GitHub cannot be reached (offline is not an error here).
    public static func check(currentVersion: String) async throws -> UpdateInfo? {
        do {
            return try await checkReportingErrors(currentVersion: currentVersion)
        } catch {
            try Task.checkCancellation()
            return nil
        }
    }

    /// Same check, but a network or reply problem is thrown as `UpdateError`, so a manual check can tell it from "up to date".
    public static func checkReportingErrors(currentVersion: String) async throws -> UpdateInfo? {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(LauncherInfo.userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            try Task.checkCancellation()
            throw UpdateError.unreachable
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            // GitHub answers 404 while the repository has no published release yet.
            if http.statusCode == 404 { return nil }
            throw UpdateError.badResponse
        }
        guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
            throw UpdateError.badResponse
        }
        return info(from: release, currentVersion: currentVersion)
    }

    private static func info(from release: GitHubRelease, currentVersion: String) -> UpdateInfo? {
        if release.draft == true || release.prerelease == true { return nil }
        var version = release.tagName.trimmingCharacters(in: .whitespaces)
        if version.hasPrefix("v") || version.hasPrefix("V") { version.removeFirst() }
        guard UpdateVersion.isNewer(version, than: currentVersion) else { return nil }
        guard let asset = release.assets.first(where: { $0.name == assetName }),
              let url = URL(string: asset.browserDownloadURL) else { return nil }
        var digest: String?
        if let raw = asset.digest?.lowercased(), raw.hasPrefix("sha256:") {
            let hex = String(raw.dropFirst("sha256:".count))
            if hex.count == 64, hex.allSatisfy({ $0.isHexDigit }) { digest = hex }
        }
        return UpdateInfo(version: version, notes: release.body ?? "", assetURL: url, size: asset.size ?? 0, sha256: digest)
    }
}

/// One file download that reports whole percents. The file is moved to `destination` as soon as it has arrived.
private final class FileDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let destination: URL
    private let expectedBytes: Int64
    private let onProgress: @Sendable (Double) -> Void
    private var lastPercent = -1
    private var task: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<Void, Error>?
    private var failure: Error?

    init(destination: URL, expectedBytes: Int64, onProgress: @escaping @Sendable (Double) -> Void) {
        self.destination = destination
        self.expectedBytes = expectedBytes
        self.onProgress = onProgress
    }

    func run(_ request: URLRequest) async throws {
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                self.continuation = continuation
                let task = session.downloadTask(with: request)
                self.task = task
                lock.unlock()
                task.resume()
            }
        } onCancel: {
            lock.lock()
            let task = self.task
            lock.unlock()
            task?.cancel()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : expectedBytes
        guard total > 0 else { return }
        let fraction = min(1, Double(totalBytesWritten) / Double(total))
        lock.lock()
        let changed = lastPercent != Int(fraction * 100)
        lastPercent = Int(fraction * 100)
        lock.unlock()
        if changed { onProgress(fraction) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            setFailure(UpdateError.downloadFailed)
            return
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            setFailure(UpdateError.downloadFailed)
        }
    }

    private func setFailure(_ error: Error) {
        lock.lock()
        failure = error
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        let storedFailure = failure
        lock.unlock()
        if let error = error ?? storedFailure {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }
}

/// Downloads a release, checks it, and swaps it in for the running app.
public enum UpdateInstaller {
    public static let bundleIdentifier = "dev.mclauncher.voxel"

    /// Downloads and unpacks the release into a fresh temp folder. Returns the URL of the unpacked app (Ember.app).
    public static func download(_ info: UpdateInfo, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        guard info.assetURL.scheme == "https" || UpdateChecker.isOverridden else { throw UpdateError.insecureDownload }

        let fileManager = FileManager.default
        let workDir = fileManager.temporaryDirectory.appendingPathComponent("ember-update-\(UUID().uuidString)", isDirectory: true)
        let unpackDir = workDir.appendingPathComponent("app", isDirectory: true)
        let zipURL = workDir.appendingPathComponent(UpdateChecker.assetName)
        do {
            try fileManager.createDirectory(at: unpackDir, withIntermediateDirectories: true, attributes: nil)
            try await fetch(info, to: zipURL, progress: progress)
            guard await run("/usr/bin/ditto", ["-x", "-k", zipURL.path, unpackDir.path]).status == 0 else { throw UpdateError.unpackFailed }
            try? fileManager.removeItem(at: zipURL)

            let app = unpackDir.appendingPathComponent(UpdateChecker.appName, isDirectory: true)
            guard fileManager.isExecutableFile(atPath: app.appendingPathComponent("Contents/MacOS/LauncherApp").path) else {
                throw UpdateError.missingApp
            }
            let plist = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
            let sameVersion = (plist?["CFBundleShortVersionString"] as? String).map {
                UpdateVersion.compare($0, info.version) == .orderedSame
            } ?? false
            guard plist?["CFBundleIdentifier"] as? String == bundleIdentifier, sameVersion else { throw UpdateError.wrongBuild }

            _ = await run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", app.path])
            guard await run("/usr/bin/codesign", ["--verify", "--deep", app.path]).status == 0 else { throw UpdateError.badSignature }
            return app
        } catch {
            try? fileManager.removeItem(at: workDir)
            throw error
        }
    }

    private static func fetch(_ info: UpdateInfo, to zipURL: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        var request = URLRequest(url: info.assetURL, timeoutInterval: 60)
        request.setValue(LauncherInfo.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            try await FileDownload(destination: zipURL, expectedBytes: Int64(info.size), onProgress: progress).run(request)
        } catch let error as UpdateError {
            throw error
        } catch {
            try Task.checkCancellation()
            throw UpdateError.downloadFailed
        }

        if info.size > 0 {
            let actual = (try? FileManager.default.attributesOfItem(atPath: zipURL.path))?[.size] as? Int
            guard actual == info.size else { throw UpdateError.sizeMismatch }
        }
        if let expected = info.sha256, (try? sha256Hex(of: zipURL)) != expected {
            throw UpdateError.checksumMismatch
        }
    }

    /// Throws with a plain message when the running app cannot be swapped: not an .app, translocated, or a read-only folder.
    public static func checkCanReplace(currentApp: URL = Bundle.main.bundleURL) throws {
        guard currentApp.pathExtension == "app" else { throw UpdateError.notAnApp }
        let parent = currentApp.deletingLastPathComponent().path
        guard !currentApp.path.contains("AppTranslocation"), FileManager.default.isWritableFile(atPath: parent) else {
            throw UpdateError.needsApplicationsFolder
        }
    }

    /// Starts a detached script that waits for this process to quit, moves the old app to the Trash, moves the new app in
    /// and opens it. It returns right after the script has started; the caller then quits the app.
    public static func replaceAndRelaunch(
        newApp: URL,
        currentApp: URL = Bundle.main.bundleURL,
        currentVersion: String = LauncherInfo.version,
        trashDirectory: URL? = nil
    ) throws {
        try checkCanReplace(currentApp: currentApp)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: newApp.path) else { throw UpdateError.missingApp }

        let trash = trashDirectory ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        let backupName = "Ember \(currentVersion) \(stamp.string(from: Date())).app"

        let logDirectory = LauncherPaths().root
        let scriptURL = fileManager.temporaryDirectory.appendingPathComponent("ember-update-\(UUID().uuidString).sh")
        do {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
            try swapScript.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
            process.arguments = [
                "/bin/bash", scriptURL.path,
                String(ProcessInfo.processInfo.processIdentifier),
                currentApp.path, newApp.path, trash.path, backupName,
                logDirectory.appendingPathComponent("update.log").path
            ]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
        } catch {
            throw UpdateError.cannotStartInstaller
        }
    }

    /// Arguments: launcher PID, current app, new app, Trash folder, name for the old app, log file.
    /// The old app is moved, never deleted; if any step fails it is moved back and opened again.
    private static let swapScript = #"""
    #!/bin/bash
    PID="$1"; OLD="$2"; NEW="$3"; TRASH="$4"; BACKUP_NAME="$5"; LOG="$6"
    trap '' HUP
    trap 'rm -f "$0"' EXIT
    exec >>"$LOG" 2>&1
    echo "$(date '+%F %T') update: waiting for process $PID to quit"

    # Wait up to a minute for the launcher to quit; if it does not, change nothing.
    for _ in $(seq 1 300); do
        kill -0 "$PID" 2>/dev/null || break
        sleep 0.2
    done
    if kill -0 "$PID" 2>/dev/null; then
        echo "launcher is still running, nothing changed"
        exit 1
    fi

    STAGE="$(dirname "$(dirname "$NEW")")"

    # The old app goes to the Trash. If the Trash cannot be used it stays next to the app instead.
    mkdir -p "$TRASH" 2>/dev/null
    BACKUP="$TRASH/$BACKUP_NAME"
    [ -e "$BACKUP" ] && BACKUP="$TRASH/$$ $BACKUP_NAME"
    if ! mv "$OLD" "$BACKUP"; then
        BACKUP="$(dirname "$OLD")/$BACKUP_NAME"
        if ! mv "$OLD" "$BACKUP"; then
            echo "cannot move the old app away, nothing changed"
            /usr/bin/open "$OLD"
            exit 1
        fi
    fi

    restore() {
        echo "update failed, putting the old app back"
        if [ -e "$OLD" ]; then
            mv "$OLD" "$TRASH/$$ failed $BACKUP_NAME" 2>/dev/null || mv "$OLD" "$(dirname "$OLD")/$$ failed $BACKUP_NAME"
        fi
        mv "$BACKUP" "$OLD"
        /usr/bin/open "$OLD"
        exit 1
    }

    mv "$NEW" "$OLD" || restore
    /usr/bin/xattr -dr com.apple.quarantine "$OLD" 2>/dev/null
    [ -x "$OLD/Contents/MacOS/LauncherApp" ] || restore
    /usr/bin/codesign --verify --deep "$OLD" || restore

    echo "updated, old app is at $BACKUP"
    case "$(basename "$STAGE")" in
        ember-update-*) rmdir "$(dirname "$NEW")" "$STAGE" 2>/dev/null ;;
    esac
    /usr/bin/open "$OLD"
    """#

    private static func run(_ executable: String, _ arguments: [String]) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: (-1, error.localizedDescription))
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: (process.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
        }
    }
}
