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
    public static let appName = "Ember.app"
    /// Points the check at another URL that returns a GitHub-style "latest release" JSON (local tests use a static file).
    public static let overrideVariable = "EMBER_UPDATE_URL"

    private static let session = URLSession(configuration: .ephemeral)

    /// The override exists only in debug builds: a release must never take its update address from the environment.
    public static var isOverridden: Bool {
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
