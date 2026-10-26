import AppKit
import Foundation
import LauncherCore

enum PlayState: Equatable {
    case idle
    /// Installing or checking files; the text is already translated.
    case preparing(String)
    case running
    case failed(String)
}

private enum PlayError: LocalizedError {
    case forgeUnsupported

    var errorDescription: String? {
        switch self {
        case .forgeUnsupported: return L("Forge is not supported yet.")
        }
    }
}

/// Passes download progress to the interface at most once per whole percent.
private final class ProgressRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var lastPercent: [String: Int] = [:]
    private let send: @Sendable (String, Int) -> Void

    init(send: @escaping @Sendable (String, Int) -> Void) {
        self.send = send
    }

    func report(_ phase: String, _ progress: DownloadProgress) {
        guard progress.totalFiles > 0 else { return }
        let percent = progress.completedFiles * 100 / progress.totalFiles
        lock.lock()
        let changed = lastPercent[phase] != percent
        lastPercent[phase] = percent
        lock.unlock()
        if changed { send(phase, percent) }
    }
}

private extension GameLauncherError {
    /// The game files are missing or incomplete, so installing them may fix it.
    var needsInstall: Bool {
        switch self {
        case .versionNotInstalled, .missingLibrary: return true
        default: return false
        }
    }
}

/// Installs what is missing, starts the game through LauncherCore and follows it until it exits.
@MainActor
final class PlayController: ObservableObject {
    @Published private(set) var state: PlayState = .idle

    private let paths = LauncherPaths()
    private let launcher: GameLauncher

    init() {
        launcher = GameLauncher(paths: paths)
    }

    var isBusy: Bool {
        switch state {
        case .preparing, .running: return true
        case .idle, .failed: return false
        }
    }

    func play(_ item: LibraryInstance, settings: SettingsStore) {
        guard !isBusy else { return }
        state = .preparing(L("Preparing…"))
        let nickname = settings.nickname
        let memoryMB = Int(settings.memoryGB) * 1024
        let hideLauncher = settings.closeOnStart
        Task { await run(item, nickname: nickname, memoryMB: memoryMB, hideLauncher: hideLauncher) }
    }

    private func run(_ item: LibraryInstance, nickname: String, memoryMB: Int, hideLauncher: Bool) async {
        do {
            guard item.loader != .forge else { throw PlayError.forgeUnsupported }
            let account = try OfflineAccount(name: nickname)
            try paths.ensureDirectories()
            let command = try await prepareCommand(item, account: account, memoryMB: memoryMB)
            let process = try launcher.launch(command)
            state = .running
            if hideLauncher { NSApp.hide(nil) }

            let status = await Task.detached {
                process.waitUntilExit()
                return process.terminationStatus
            }.value

            if hideLauncher {
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            state = status == 0 ? .idle : .failed(L("The game closed with code %d.", Int(status)))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Builds the launch command; if the game files are missing, installs them once and tries again.
    private func prepareCommand(_ item: LibraryInstance, account: OfflineAccount, memoryMB: Int) async throws -> LaunchCommand {
        let relay = ProgressRelay { [weak self] phase, percent in
            Task { @MainActor in self?.showDownload(phase: phase, percent: percent) }
        }
        var installed = false
        while true {
            do {
                var instance = try launcher.prepareInstance(
                    name: item.name,
                    minecraftVersion: item.minecraftVersion,
                    fabric: item.loader == .fabric
                )
                if instance.memoryMB != memoryMB {
                    instance.memoryMB = memoryMB
                    try launcher.store.save(instance)
                }
                return try await launcher.makeCommand(instance: instance, account: account) { relay.report("runtime", $0) }
            } catch let error as GameLauncherError where !installed && error.needsInstall {
                installed = true
                try await install(item, relay: relay)
            }
        }
    }

    private func install(_ item: LibraryInstance, relay: ProgressRelay) async throws {
        let progress: @Sendable (String, DownloadProgress) -> Void = { relay.report($0, $1) }
        if item.loader == .fabric {
            let fabric = FabricInstaller(paths: paths, installer: launcher.installer)
            _ = try await fabric.install(minecraftVersion: item.minecraftVersion, progress: progress)
        } else {
            _ = try await launcher.installer.install(versionId: item.minecraftVersion, progress: progress)
        }
    }

    private func showDownload(phase: String, percent: Int) {
        guard case .preparing = state else { return }
        state = .preparing(phase == "runtime" ? L("Downloading Java %d%%", percent) : L("Downloading game files %d%%", percent))
    }
}
