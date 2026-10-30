import AppKit
import Combine
import Foundation
import LauncherCore

enum LobbyHostState: Equatable {
    case idle
    case room
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
    @Published private(set) var roomInstance: String?
    @Published private(set) var startedAt: Date?
    @Published private(set) var errorMessage: String?

    private let paths = LauncherPaths()
    private let launcher: GameLauncher
    private var tracker = ServerPlayerTracker()
    var library: ServerLibrary { ServerLibrary(root: paths.root.appendingPathComponent("lobby-servers", isDirectory: true)) }
    private var server: LocalGameServer?
    private var serverDirectory: URL?
    private var rosterWatch: AnyCancellable?
    private var lobbyWatch: AnyCancellable?
    private var roomWatch: AnyCancellable?
    private var terminateWatch: NSObjectProtocol?
    private var serverPort: Int?
    private var roomMaxPlayers: Int?

    private init() {
        launcher = GameLauncher(paths: paths)
        eulaAccepted = UserDefaults.standard.bool(forKey: "lobbyEulaAccepted")
    }

    var isBusy: Bool {
        if case .preparing = state { return true }
        return false
    }

    func createRoom(
        base: LibraryInstance?,
        reuseBase: Bool,
        mcVersion: String,
        name: String,
        privacy: LobbyPrivacy,
        maxPlayers: Int,
        settings: SettingsStore,
        app: AppState,
        startImmediately: Bool = false
    ) {
        guard !isBusy, eulaAccepted else { return }
        if let base, base.loader != .fabric && base.loader != .vanilla {
            state = .failed(L("Hosting works with Fabric and Vanilla instances for now."))
            return
        }

        state = .preparing(L("Creating the lobby…"))
        roomMaxPlayers = maxPlayers
        Task {
            await createRoom(
                base: base,
                reuseBase: reuseBase,
                mcVersion: mcVersion,
                name: name,
                privacy: privacy,
                maxPlayers: maxPlayers,
                settings: settings,
                app: app,
                startImmediately: startImmediately
            )
        }
    }

    private func createRoom(
        base: LibraryInstance?,
        reuseBase: Bool,
        mcVersion: String,
        name: String,
        privacy: LobbyPrivacy,
        maxPlayers: Int,
        settings: SettingsStore,
        app: AppState,
        startImmediately: Bool
    ) async {
        let lobbies = LobbyStore.shared
        roomWatch = lobbies.$current
            .dropFirst()
            .sink { [weak self] current in
                guard current == nil else { return }
                Task { @MainActor in
                    guard let self else { return }
                    LobbyRoom.shared.detach()
                    self.roomInstance = nil
                    self.serverPort = nil
                    self.roomWatch = nil
                    self.state = .idle
                }
            }

        do {
            let roomName: String
            let roomVersion: String
            let roomLoader: String

            if reuseBase, let base {
                roomName = base.name
                roomVersion = base.minecraftVersion
                roomLoader = base.loader.coreName
            } else {
                let requestedName = "Lobby \(name)"
                if let existing = app.instances.first(where: { $0.id == requestedName && $0.loader == .fabric }) {
                    roomName = existing.id
                    roomVersion = existing.minecraftVersion
                    roomLoader = existing.loader.coreName
                } else {
                    roomName = try app.createInstance(
                        name: requestedName,
                        minecraftVersion: base?.minecraftVersion ?? mcVersion,
                        loader: .fabric,
                        group: nil,
                        memoryMB: 4096
                    )
                    roomVersion = base?.minecraftVersion ?? mcVersion
                    roomLoader = "fabric"
                }
            }

            let request = LobbyCreateRequest(
                name: name,
                mcVersion: roomVersion,
                loader: roomLoader,
                packURL: nil,
                packSHA1: nil,
                privacy: privacy,
                maxPlayers: maxPlayers,
                nick: settings.nickname
            )
            guard await lobbies.host(request) else { throw HostError.lobbyService }

            LobbyRoom.shared.attach(instance: roomName)
            roomInstance = roomName
            state = .room
            Task { await LobbyRoom.shared.seed(from: base?.name ?? roomName) }

            if startImmediately {
                startServer(settings: settings, app: app)
            }
        } catch {
            roomWatch = nil
            LobbyRoom.shared.detach()
            roomInstance = nil
            state = .failed(error.localizedDescription)
        }
    }

    func startServer(settings: SettingsStore, app: AppState) {
        guard case .room = state, roomInstance != nil else { return }
        errorMessage = nil
        state = .preparing(L("Installing the lobby's content…"))
        Task { await runServer(settings: settings, app: app) }
    }

    private func runServer(settings: SettingsStore, app: AppState) async {
        let lobbies = LobbyStore.shared
        do {
            try await LobbyRoom.shared.pull(final: true)
            guard let roomInstance else { throw HostError.roomInstance }

            state = .preparing(L("Preparing the game files…"))
            try paths.ensureDirectories()
            var instance = try launcher.store.load(name: roomInstance)
            instance = try await launcher.ensureInstalled(instance) { _, _ in }
            let java = try await launcher.ensureJava(for: instance)

            let lobby = lobbies.current
            let name = lobby?.name ?? roomInstance
            let maxPlayers = lobby == nil ? 8 : (roomMaxPlayers ?? 8)
            let directory = library.directory(for: roomInstance)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let port = Int.random(in: 41000...49000)

            state = .preparing(L("Preparing the server…"))
            let server = LocalGameServer(
                directory: directory,
                javaExecutable: java,
                minecraftVersion: instance.minecraftVersion
            )
            let jar = try await server.prepareLauncherJar()
            try LocalServerFiles.writeEula(in: directory)
            try LocalServerFiles.writeServerProperties(
                in: directory,
                port: port,
                maxPlayers: maxPlayers,
                motd: name
            )
            try LocalServerFiles.writeWhitelist(
                in: directory,
                names: whitelistNames(nick: settings.nickname, roster: lobbies.roster)
            )
            if instance.loader == "fabric" {
                try LocalServerFiles.linkMods(
                    serverDirectory: directory,
                    to: launcher.store.gameDirectory(for: roomInstance).appendingPathComponent("mods", isDirectory: true)
                )
            }

            state = .preparing(L("Starting the server…"))
            await LocalGameServer.stopStrayProcesses(in: directory)
            logLines = []
            tracker.reset()
            players = []
            try await server.start(launcherJar: jar, memoryMB: max(2048, min(instance.memoryMB, 4096))) { [weak self] line in
                Task { @MainActor in self?.ingest(line) }
            }
            self.server = server
            serverDirectory = directory
            runningInstance = roomInstance
            startedAt = Date()
            try? library.save(ServerProfile(
                instanceName: roomInstance,
                name: name,
                minecraftVersion: instance.minecraftVersion,
                loader: instance.loader == "fabric" ? "fabric" : "vanilla",
                maxPlayers: maxPlayers,
                lastPlayed: Date()
            ))
            watch(nick: settings.nickname)

            lobbies.startHosting(serverPort: UInt16(port))
            serverPort = port
            state = .running
        } catch {
            await stopServer()
            serverPort = nil
            errorMessage = error.localizedDescription
            state = .room
        }
    }

    func play(settings: SettingsStore, app: AppState, play: PlayController) {
        guard
            case .running = state,
            let port = serverPort,
            !play.isBusy,
            let roomInstance,
            let item = app.instances.first(where: { $0.id == roomInstance })
        else { return }
        app.modal = nil
        play.play(item, settings: settings, app: app, quickPlayServer: "127.0.0.1:\(port)")
    }

    func stopRunningServer() {
        Task {
            await stopServer()
            await LobbyStore.shared.reopen()
            serverPort = nil
            state = .room
        }
    }

    func close() {
        let lobbies = LobbyStore.shared
        let wasHosting = lobbies.current?.isHost == true
        Task {
            await stopServer()
            if wasHosting { lobbies.leave() }
            LobbyRoom.shared.detach()
            roomWatch = nil
            roomInstance = nil
            serverPort = nil
            roomMaxPlayers = nil
            errorMessage = nil
            state = .idle
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
        var appliedNames = Set(whitelistNames(nick: nick, roster: lobbies.roster).map { $0.lowercased() })
        rosterWatch = lobbies.$roster
            .dropFirst()
            .sink { [weak self] roster in
                Task { @MainActor in
                    guard let self, let server = self.server, let directory = self.serverDirectory else { return }
                    let names = self.whitelistNames(nick: nick, roster: roster)
                    // The lobby is polled every few seconds and re-publishes an unchanged roster; reloading each time spams the in-game chat.
                    let lowered = Set(names.map { $0.lowercased() })
                    guard lowered != appliedNames else { return }
                    appliedNames = lowered
                    try? LocalServerFiles.writeWhitelist(in: directory, names: names)
                    try? server.reloadWhitelist()
                }
            }
        lobbyWatch = lobbies.$current
            .dropFirst()
            .sink { [weak self] current in
                guard current == nil else { return }
                Task { @MainActor in
                    guard let self else { return }
                    await self.stopServer()
                    LobbyRoom.shared.detach()
                    self.roomInstance = nil
                    self.serverPort = nil
                    self.state = .idle
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
        case roomInstance

        var errorDescription: String? {
            switch self {
            case .lobbyService:
                return L("Could not reach the lobby service.")
            case .roomInstance:
                return L("Could not find the lobby instance.")
            }
        }
    }
}
