import AppKit
import Foundation
import LauncherCore

enum UpdateState: Equatable {
    case idle
    case available(UpdateInfo)
    /// Fraction 0...1 of the download.
    case downloading(Double)
    /// Downloaded and checked; waits for a restart.
    case ready
    /// The message is already translated.
    case failed(String)
}

/// What the Check for updates button in Settings found.
enum UpdateCheckStatus: Equatable {
    case idle
    case checking
    case upToDate
    /// The message is already translated.
    case failed(String)
}

/// Looks for a newer launcher on GitHub (at start and every 6 hours), downloads it, and restarts into it.
@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var state: UpdateState = .idle
    /// The release found by the last check. It stays after a failure, so the pill can offer it again.
    @Published private(set) var info: UpdateInfo?
    @Published private(set) var checkStatus: UpdateCheckStatus = .idle
    /// Restart was asked for while the game runs; it happens when the game closes.
    @Published private(set) var isWaitingForGame = false

    /// Set from the root view while PlayController is busy.
    var gameIsBusy = false {
        didSet {
            if oldValue && !gameIsBusy && isWaitingForGame { restart() }
        }
    }

    private let settings: SettingsStore
    private var loopTask: Task<Void, Never>?
    private var downloadedApp: URL?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// First check a few seconds after start, then every 6 hours. Does nothing outside a .app (swift run).
    func start() {
        guard loopTask == nil, Bundle.main.bundleURL.pathExtension == "app" else { return }
        loopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            while !Task.isCancelled {
                await self?.check(silent: true)
                try? await Task.sleep(for: .seconds(6 * 3600))
            }
        }
    }

    /// The Check for updates button: looks now and reports the result.
    func checkNow() {
        guard checkStatus != .checking else { return }
        Task { await check(silent: false) }
    }

    /// The pill in the top bar.
    func pillAction() {
        switch state {
        case .available, .failed:
            // The temporary folder may have been cleaned since the download: then the copy is gone and must be fetched again.
            if let app = downloadedApp, !FileManager.default.fileExists(atPath: app.path) {
                downloadedApp = nil
            }
            if downloadedApp != nil {
                state = .ready
                restart()
            } else {
                startDownload(restartWhenDone: true)
            }
        case .ready:
            restart()
        case .idle, .downloading:
            break
        }
    }

    /// Update automatically was switched on while a release was waiting.
    func autoUpdateEnabled() {
        if case .available = state { startDownload(restartWhenDone: false) }
    }

    func dismissError() {
        guard case .failed = state else { return }
        state = info.map { .available($0) } ?? .idle
    }

    private func check(silent: Bool) async {
        switch state {
        case .downloading, .ready: return
        default: break
        }
        if !silent { checkStatus = .checking }
        do {
            let found = silent
                ? try await UpdateChecker.check(currentVersion: LauncherInfo.version)
                : try await UpdateChecker.checkReportingErrors(currentVersion: LauncherInfo.version)
            if let found {
                if found.version != info?.version { downloadedApp = nil }
                info = found
                state = .available(found)
                checkStatus = .idle
                if settings.autoUpdate { startDownload(restartWhenDone: false) }
            } else if !silent {
                info = nil
                state = .idle
                checkStatus = .upToDate
            }
        } catch {
            if !silent { checkStatus = .failed(Self.message(for: error)) }
        }
    }

    private func startDownload(restartWhenDone: Bool) {
        guard let info else { return }
        if case .downloading = state { return }
        do {
            try UpdateInstaller.checkCanReplace()
        } catch {
            state = .failed(Self.message(for: error))
            return
        }
        state = .downloading(0)
        Task {
            do {
                let app = try await UpdateInstaller.download(info) { fraction in
                    Task { @MainActor in self.showProgress(fraction) }
                }
                downloadedApp = app
                state = .ready
                if restartWhenDone { restart() }
            } catch {
                state = .failed(Self.message(for: error))
            }
        }
    }

    private func showProgress(_ fraction: Double) {
        if case .downloading = state { state = .downloading(fraction) }
    }

    /// Swaps the app in and quits. While a game runs it only waits, so the game is never interrupted.
    private func restart() {
        guard case .ready = state, let app = downloadedApp else { return }
        guard !gameIsBusy else {
            isWaitingForGame = true
            return
        }
        isWaitingForGame = false
        do {
            try UpdateInstaller.replaceAndRelaunch(newApp: app)
            NSApp.terminate(nil)
        } catch {
            downloadedApp = nil
            state = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        if let update = error as? UpdateError { return L(update.message) }
        return error.localizedDescription
    }
}
