import AppKit
import Combine
import Foundation
import LauncherCore

enum LobbyHostState: Equatable {
    case idle
    case preparing(String)
    case running
    case failed(String)
}

/// One-button hosting: creates the lobby, runs the world as a local Fabric server, opens the tunnel and joins the game.
@MainActor
final class LobbyHostController: ObservableObject {
    static let shared = LobbyHostController()

    @Published private(set) var state: LobbyHostState = .idle
    /// Enabled mods of the hosted instance that guests cannot be given (added by hand, not from Modrinth).
    @Published private(set) var unsyncedMods = 0
    @Published var eulaAccepted: Bool {
        didSet { UserDefaults.standard.set(eulaAccepted, forKey: "lobbyEulaAccepted") }
    }

    /// Live console of the running server, newest last; kept after a stop so the last run can be read.
    @Published private(set) var logLines: [String] = []
    @Published private(set) var players: [String] = []
    @Published private(set) var runningInstance: String?
    @Published private(set) var startedAt: Date?

    private let paths = LauncherPaths()
    private let launcher: GameLauncher
    private var tracker = ServerPlayerTracker()
    var library: ServerLibrary { ServerLibrary(root: paths.root.appendingPathComponent("lobby-servers", isDirectory: true)) }
    private var server: LocalGameServer?
    private var serverDirectory: URL?
    private var rosterWatch: AnyCancellable?
    private var lobbyWatch: AnyCancellable?
    private var terminateWatch: NSObjectProtocol?

    private init() {
        launcher = GameLauncher(paths: paths)
        eulaAccepted = UserDefaults.standard.bool(forKey: "lobbyEulaAccepted")
    }

    var isBusy: Bool {
        if case .preparing = state { return true }
        return false
    }

    func host(
        _ item: LibraryInstance,
        name: String,
        privacy: LobbyPrivacy,
        maxPlayers: Int,
        settings: SettingsStore,
        app: AppState,
        play: PlayController
    ) {
        guard !isBusy, eulaAccepted else { return }
        guard item.loader == .fabric || item.loader == .vanilla else {
            state = .failed(L("Hosting works with Fabric and Vanilla instances for now."))
            return
        }
        guard !play.isBusy else { return }
        state = .preparing(L("Creating the lobby…"))
        Task { await run(item, name: name, privacy: privacy, maxPlayers: maxPlayers, settings: settings, app: app, play: play) }
    }

    func close() {
        let lobbies = LobbyStore.shared
        let wasHosting = lobbies.current?.isHost == true
        Task {
            await stopServer()
            if wasHosting { lobbies.leave() }
            state = .idle
        }
    }

    private func run(
        _ item: LibraryInstance,
        name: String,
        privacy: LobbyPrivacy,
        maxPlayers: Int,
        settings: SettingsStore,
        app: AppState,
        play: PlayController
    ) async {
        let lobbies = LobbyStore.shared
        let nick = settings.nickname
        do {
            let modList = LobbyModList(mods: (try? ModManager(store: launcher.store).list(instance: item.name)) ?? [])
            let pack = modList.packFields
            unsyncedMods = modList.unsyncedCount
            let request = LobbyCreateRequest(
                name: name,
                mcVersion: item.minecraftVersion,
                loader: item.loader.coreName,
                packURL: pack?.url,
                packSHA1: pack?.sha1,
                privacy: privacy,
                maxPlayers: maxPlayers,
                nick: nick
            )
            guard await lobbies.host(request) else { throw HostError.lobbyService }

            state = .preparing(L("Preparing the game files…"))
            try paths.ensureDirectories()
            var instance = try launcher.store.load(name: item.name)
            instance = try await launcher.ensureInstalled(instance) { _, _ in }
            let java = try await launcher.ensureJava(for: instance)

            let directory = library.directory(for: item.name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let port = Int.random(in: 41000...49000)

            state = .preparing(L("Preparing the server…"))
            let server = LocalGameServer(directory: directory, javaExecutable: java, minecraftVersion: item.minecraftVersion)
            let jar = try await server.prepareLauncherJar()
            try LocalServerFiles.writeEula(in: directory)
            try LocalServerFiles.writeServerProperties(in: directory, port: port, maxPlayers: maxPlayers, motd: name)
            try LocalServerFiles.writeWhitelist(in: directory, names: whitelistNames(nick: nick, roster: lobbies.roster))
            if item.loader == .fabric {
                try LocalServerFiles.linkMods(
                    serverDirectory: directory,
                    to: launcher.store.gameDirectory(for: item.name).appendingPathComponent("mods", isDirectory: true)
                )
            }

            state = .preparing(L("Starting the server…"))
            logLines = []
            tracker.reset()
            players = []
            try await server.start(launcherJar: jar, memoryMB: max(2048, min(instance.memoryMB, 4096))) { [weak self] line in
                Task { @MainActor in self?.ingest(line) }
            }
            self.server = server
            serverDirectory = directory
            runningInstance = item.name
            startedAt = Date()
            try? library.save(ServerProfile(
                instanceName: item.name,
                name: name,
                minecraftVersion: item.minecraftVersion,
                loader: item.loader.coreName,
                maxPlayers: maxPlayers,
                lastPlayed: Date()
            ))
            watch(nick: nick)

            lobbies.startHosting(serverPort: UInt16(port))
            state = .running
            app.modal = nil
            play.play(item, settings: settings, app: app, quickPlayServer: "127.0.0.1:\(port)")
        } catch {
            await stopServer()
            if lobbies.current?.isHost == true { lobbies.leave() }
            state = .failed(error.localizedDescription)
        }
    }

    private func ingest(_ line: String) {
        logLines.append(line)
        if logLines.count > 600 { logLines.removeFirst(logLines.count - 600) }
        tracker.apply(line)
        if players != tracker.online { players = tracker.online }
    }

    /// Sends a console command to the running server and echoes it into the log.
    func send(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let server else { return }
        logLines.append("> \(trimmed)")
        try? server.send(command: trimmed)
    }

    private func whitelistNames(nick: String, roster: [LobbyMember]) -> [String] {
        [nick] + roster.map(\.nick)
    }

    /// Keeps the whitelist in step with the lobby roster and shuts the server down when the lobby is gone.
    private func watch(nick: String) {
        let lobbies = LobbyStore.shared
        rosterWatch = lobbies.$roster
            .dropFirst()
            .sink { [weak self] roster in
                Task { @MainActor in
                    guard let self, let server = self.server, let directory = self.serverDirectory else { return }
                    let names = self.whitelistNames(nick: nick, roster: roster)
                    try? LocalServerFiles.writeWhitelist(in: directory, names: names)
                    try? server.reloadWhitelist()
                }
            }
        lobbyWatch = lobbies.$current
            .dropFirst()
            .sink { [weak self] current in
                guard current == nil else { return }
                Task { @MainActor in
                    await self?.stopServer()
                    self?.state = .idle
                }
            }
        terminateWatch = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.server?.terminateNow()
        }
    }

    private func stopServer() async {
        rosterWatch = nil
        lobbyWatch = nil
        if let terminateWatch {
            NotificationCenter.default.removeObserver(terminateWatch)
            self.terminateWatch = nil
        }
        let running = server
        server = nil
        serverDirectory = nil
        runningInstance = nil
        startedAt = nil
        tracker.reset()
        players = []
        await running?.stop()
    }

    private enum HostError: LocalizedError {
        case lobbyService

        var errorDescription: String? {
            L("Could not reach the lobby service.")
        }
    }
}
