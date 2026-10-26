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

/// Thread-safe holder for the screen refresh rate read on the main actor.
private final class DisplayRefreshRateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int?

    var value: Int? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}

/// Hands out the seconds played since it was last asked, so a periodic save and the final save never count the same second twice.
private final class PlayClock: @unchecked Sendable {
    private let lock = NSLock()
    private var mark: Date

    init(start: Date) {
        mark = start
    }

    func take() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let seconds = max(0, Int(Date().timeIntervalSince(mark)))
        mark = mark.addingTimeInterval(Double(seconds))
        return seconds
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
    /// Why the last run ended badly, and which instance it was; nil after a clean run or before the first run.
    @Published private(set) var diagnosis: CrashDiagnosis?
    @Published private(set) var diagnosisInstance: String?
    /// When the running game was started.
    @Published private(set) var runningSince: Date?
    /// Counts game starts, so the log console knows the log file was started over.
    @Published private(set) var runCount = 0

    private let paths = LauncherPaths()
    private let launcher: GameLauncher
    private let refreshRateBox = DisplayRefreshRateBox()

    init() {
        launcher = GameLauncher(paths: paths)
        let box = refreshRateBox
        launcher.displayRefreshRateProvider = { box.value }
    }

    var isBusy: Bool {
        switch state {
        case .preparing, .running: return true
        case .idle, .failed: return false
        }
    }

    func play(_ item: LibraryInstance, settings: SettingsStore, app: AppState) {
        guard !isBusy else { return }
        refreshRateBox.value = NSScreen.main?.maximumFramesPerSecond
        state = .preparing(L("Preparing…"))
        let nickname = settings.nickname
        let hideLauncher = settings.closeOnStart
        Task { await run(item, nickname: nickname, hideLauncher: hideLauncher, app: app) }
    }

    private func run(_ item: LibraryInstance, nickname: String, hideLauncher: Bool, app: AppState) async {
        do {
            guard item.loader != .forge else { throw PlayError.forgeUnsupported }
            let account = try OfflineAccount(name: nickname)
            try paths.ensureDirectories()
            let command = try await prepareCommand(item.name, account: account)
            let process = try launcher.launch(command)
            let started = Date()
            runCount += 1
            diagnosis = nil
            diagnosisInstance = nil
            runningSince = started
            state = .running
            if hideLauncher { NSApp.hide(nil) }

            // Playtime is saved every minute, so quitting the launcher mid-game loses at most a minute.
            let clock = PlayClock(start: started)
            let checkpoint = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { return }
                    try? launcher.store.recordPlay(name: item.name, seconds: clock.take(), at: started)
                    app.reload()
                }
            }

            let status = await Task.detached {
                process.waitUntilExit()
                return process.terminationStatus
            }.value

            checkpoint.cancel()
            runningSince = nil
            if hideLauncher {
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            try? launcher.store.recordPlay(name: item.name, seconds: clock.take(), at: started)
            app.reload()
            if status != 0 {
                diagnosis = await Self.diagnose(
                    logURL: command.logURL,
                    gameDirectory: command.workingDirectory,
                    since: started,
                    exitCode: status
                )
                diagnosisInstance = item.name
            }
            state = status == 0 ? .idle : .failed(L("The game closed with code %d.", Int(status)))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Reads the game's log and its crash report (if it wrote one) off the main thread and names the likely cause.
    private nonisolated static func diagnose(logURL: URL, gameDirectory: URL, since: Date, exitCode: Int32) async -> CrashDiagnosis {
        await Task.detached {
            let log = GameLog.tail(of: logURL)
            let file = GameLog.latestCrashFile(gameDirectory: gameDirectory, since: since.addingTimeInterval(-5))
            let report = file.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            return CrashAnalyzer.analyze(log: log, crashReport: report, reportFile: file, exitCode: exitCode)
        }.value
    }

    /// Builds the launch command; installs the game files first when they are missing, and once more if the build still reports a gap.
    private func prepareCommand(_ name: String, account: OfflineAccount) async throws -> LaunchCommand {
        let relay = ProgressRelay { [weak self] phase, percent in
            Task { @MainActor in self?.showDownload(phase: phase, percent: percent) }
        }
        let progress: @Sendable (String, DownloadProgress) -> Void = { relay.report($0, $1) }
        var instance = try launcher.store.load(name: name)
        instance = try await launcher.ensureInstalled(instance, progress: progress)
        do {
            return try await launcher.makeCommand(instance: instance, account: account) { relay.report("runtime", $0) }
        } catch let error as GameLauncherError where error.needsInstall {
            instance = try await launcher.ensureInstalled(instance, force: true, progress: progress)
            return try await launcher.makeCommand(instance: instance, account: account) { relay.report("runtime", $0) }
        }
    }

    private func showDownload(phase: String, percent: Int) {
        guard case .preparing = state else { return }
        state = .preparing(phase == "runtime" ? L("Downloading Java %d%%", percent) : L("Downloading game files %d%%", percent))
    }
}
