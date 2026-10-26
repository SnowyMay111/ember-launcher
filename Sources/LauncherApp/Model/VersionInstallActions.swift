import Foundation
import LauncherCore

/// Folds the download phases (libraries, assets, client, Java) into one 0...100 percent and passes it on only when it grows.
private final class VersionProgress: @unchecked Sendable {
    /// Where each phase starts on the bar and how much of it the phase covers.
    private static let phases: [String: (start: Int, span: Int)] = [
        "libraries": (0, 15),
        "assets": (15, 55),
        "client": (70, 10),
        "runtime": (80, 20),
    ]

    private let lock = NSLock()
    private var last = 0
    private let send: @Sendable (Int) -> Void

    init(send: @escaping @Sendable (Int) -> Void) {
        self.send = send
    }

    func report(_ phase: String, _ progress: DownloadProgress) {
        guard progress.totalFiles > 0, let slot = Self.phases[phase] else { return }
        let percent = slot.start + slot.span * progress.completedFiles / progress.totalFiles
        lock.lock()
        let changed = percent > last
        if changed { last = percent }
        lock.unlock()
        if changed { send(percent) }
    }
}

/// Lets one task at a time through, so two installs never unpack the same Java at once.
private actor JavaGate {
    private var isLocked = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func lock() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    func unlock() {
        if waiting.isEmpty {
            isLocked = false
        } else {
            waiting.removeFirst().resume()
        }
    }
}

private let javaGate = JavaGate()

/// The All versions window: make a Vanilla instance for any Mojang version and download the game right away.
extension AppState {
    static func vanillaName(for version: String) -> String {
        "Vanilla \(version)"
    }

    /// The client jar is the last file the installer writes, so its presence means the game files are complete.
    func isDownloaded(_ version: String) -> Bool {
        FileManager.default.fileExists(atPath: paths.versionJAR(version).path)
    }

    /// Creates "Vanilla <version>" if it is missing (without switching to it), then downloads the game and its Java.
    /// Progress is in `downloads`, a failure in `downloadErrors`.
    func installVersion(_ version: String, memoryMB: Int) {
        guard downloads[version] == nil else { return }
        downloadErrors[version] = nil
        downloads[version] = 0
        Task {
            do {
                try paths.ensureDirectories()
                let name = Self.vanillaName(for: version)
                if !store.exists(name: name) {
                    let previous = currentID
                    try createInstance(name: name, minecraftVersion: version, loader: .vanilla, group: nil, memoryMB: memoryMB)
                    currentID = previous
                }
                let launcher = GameLauncher(paths: paths)
                let instance = try launcher.store.load(name: name)
                let relay = VersionProgress { percent in
                    Task { @MainActor in self.downloads[version] = percent }
                }
                // A version file without the jar is a download that stopped halfway: fetch everything again.
                let installed = try await launcher.ensureInstalled(instance, force: !isDownloaded(version)) { relay.report($0, $1) }
                _ = try await withJavaGate {
                    try await launcher.ensureJava(for: installed) { relay.report("runtime", $0) }
                }
                downloads[version] = nil
            } catch {
                downloads[version] = nil
                downloadErrors[version] = error.localizedDescription
            }
        }
    }

    private func withJavaGate<T>(_ body: () async throws -> T) async throws -> T {
        await javaGate.lock()
        do {
            let value = try await body()
            await javaGate.unlock()
            return value
        } catch {
            await javaGate.unlock()
            throw error
        }
    }
}
