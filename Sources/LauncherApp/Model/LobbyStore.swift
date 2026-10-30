import Foundation
import LauncherCore

/// A lobby the user is currently hosting or has joined.
struct ActiveLobby {
    let id: String
    let code: String?
    let name: String
    let isHost: Bool
    var address: String?
    let packURL: String?
    let packSHA1: String?
    let mcVersion: String
    let loader: String
    /// The host's user id. Empty when we are the host.
    let hostUser: String
    var status: String
    var editPolicy: LobbyEditPolicy
    var syncShaders: Bool
    var syncResourcePacks: Bool
    var canEdit: Bool

    var isRunning: Bool { status == "open" }
}

/// Lobby discovery, hosting and membership, backed by the Ember lobby service.
@MainActor
final class LobbyStore: ObservableObject {
    static let shared = LobbyStore()

    @Published private(set) var visible: [VisibleLobby] = []
    @Published private(set) var current: ActiveLobby?
    @Published private(set) var roster: [LobbyMember] = []
    @Published private(set) var items: [LobbyItem] = []
    @Published var message: String?
    /// Local port the game connects to (127.0.0.1) while a guest tunnel is up.
    @Published private(set) var tunnelPort: UInt16?
    @Published private(set) var tunnelConnecting = false

    private let lobbies = EmberLobbies()
    private var loop: Task<Void, Never>?
    private var hostService: TunnelHostService?
    private var guestService: TunnelGuestService?

    private init() {}

    // MARK: - Lifecycle

    /// Starts the discovery/heartbeat loop. Calling this again while it is running has no effect.
    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard let session = await EmberAccountStore.shared.validSession() else {
                    if !self.visible.isEmpty { self.visible = [] }
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }

                await self.loadVisible(session: session)
                if let current = self.current {
                    if current.isHost {
                        try? await self.lobbies.heartbeat(lobby: current.id, session: session)
                    }
                    await self.loadRoster(lobby: current.id, session: session)
                    await self.loadInfo(session: session)
                    await self.loadItems(lobby: current.id, session: session)
                }

                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        stopTunnel()
        visible = []
        current = nil
        roster = []
        items = []
    }

    // MARK: - Actions

    /// Creates the lobby; true when it exists afterwards.
    @discardableResult
    func host(_ request: LobbyCreateRequest) async -> Bool {
        guard let session = await EmberAccountStore.shared.validSession() else { return false }
        var created = false
        do {
            let lobby = try await lobbies.create(request, session: session)
            current = ActiveLobby(
                id: lobby.id,
                code: lobby.code,
                name: request.name,
                isHost: true,
                address: nil,
                packURL: request.packURL,
                packSHA1: request.packSHA1,
                mcVersion: request.mcVersion,
                loader: request.loader,
                hostUser: "",
                status: "starting",
                editPolicy: .host,
                syncShaders: false,
                syncResourcePacks: true,
                canEdit: true
            )
            message = nil
            created = true
        } catch {
            message = L("Could not reach the lobby service.")
        }
        await refreshAfterAction()
        return created
    }

    /// Host: the game server listens on `serverPort`. Starts accepting guest tunnels and opens the lobby.
    func startHosting(serverPort: UInt16) {
        Task {
            guard
                let session = await EmberAccountStore.shared.validSession(),
                let current, current.isHost,
                let key = try? await lobbies.tunnelKey(lobby: current.id, session: session)
            else {
                message = L("Could not reach the lobby service.")
                return
            }
            hostService?.stop()
            let service = TunnelHostService(
                signaling: Self.signaling(for: current.id),
                tunnelKeyHex: key,
                serverPort: serverPort
            )
            service.start()
            hostService = service
            publishAddress("p2p")
        }
    }

    /// Guest: opens the tunnel to the host and exposes it on a local port for the game.
    private func connectTunnel(lobbyID: String, hostUser: String) async {
        tunnelConnecting = true
        defer { tunnelConnecting = false }
        guard
            let session = await EmberAccountStore.shared.validSession(),
            let key = try? await lobbies.tunnelKey(lobby: lobbyID, session: session)
        else {
            message = L("Could not reach the lobby service.")
            return
        }
        let service = TunnelGuestService(
            signaling: Self.signaling(for: lobbyID),
            hostUser: hostUser,
            tunnelKeyHex: key
        )
        service.onClosed = { [weak self] in
            Task { @MainActor in self?.tunnelPort = nil }
        }
        do {
            let port = try await service.connect()
            guestService = service
            tunnelPort = port
        } catch TunnelError.noPublicEndpoint {
            message = L("Could not find a route to the host. Check your internet connection.")
        } catch {
            message = L("Could not connect to the host. Your networks may block direct connections.")
        }
    }

    private func stopTunnel() {
        hostService?.stop()
        hostService = nil
        guestService?.stop()
        guestService = nil
        tunnelPort = nil
    }

    private static func signaling(for lobby: String) -> EmberLobbySignaling {
        EmberLobbySignaling(lobby: lobby) { await EmberAccountStore.shared.validSession() }
    }

    /// Publishes the server address for the lobby you are hosting.
    func publishAddress(_ address: String) {
        Task {
            guard
                let session = await EmberAccountStore.shared.validSession(),
                let current, current.isHost
            else { return }
            do {
                try await lobbies.setAddress(lobby: current.id, address: address, session: session)
                self.current?.address = address
                self.current?.status = "open"
            } catch {
                message = L("Could not reach the lobby service.")
            }
            await refreshAfterAction()
        }
    }

    /// Joins the lobby; true when the lobby was joined, regardless of whether the
    /// server is running yet. Use `current?.isRunning` to check that separately.
    @discardableResult
    func join(code: String?, lobbyID: String?, nick: String) async -> Bool {
        guard let session = await EmberAccountStore.shared.validSession() else { return false }
        var joined = false
        do {
            let outcome = try await lobbies.join(code: code, lobbyID: lobbyID, nick: nick, session: session)
            switch outcome {
            case .ok(let lobby):
                current = ActiveLobby(
                    id: lobby.id,
                    code: nil,
                    name: lobby.name,
                    isHost: false,
                    address: lobby.address,
                    packURL: lobby.packURL,
                    packSHA1: lobby.packSHA1,
                    mcVersion: lobby.mcVersion,
                    loader: lobby.loader,
                    hostUser: lobby.host,
                    status: lobby.status,
                    editPolicy: lobby.editPolicy,
                    syncShaders: lobby.syncShaders,
                    syncResourcePacks: lobby.syncResourcePacks,
                    canEdit: lobby.canEdit
                )
                message = nil
                if lobby.status == "open", lobby.address != nil {
                    await connectTunnel(lobbyID: lobby.id, hostUser: lobby.host)
                }
                joined = true
            case .notFound:
                message = L("No lobby with that code.")
            case .closed:
                message = L("This lobby has closed.")
            case .forbidden:
                message = L("You cannot join this lobby.")
            case .full:
                message = L("The lobby is full.")
            case .nickTaken:
                message = L("Someone in the lobby already uses this nickname.")
            case .notReady:
                message = L("The host is still starting the server. Try again in a moment.")
            }
        } catch {
            message = L("Could not reach the lobby service.")
        }
        await refreshAfterAction()
        return joined
    }

    func leave() {
        Task {
            guard
                let session = await EmberAccountStore.shared.validSession(),
                let current
            else { return }
            do {
                if current.isHost {
                    try await lobbies.close(lobby: current.id, session: session)
                } else {
                    try await lobbies.leave(lobby: current.id, session: session)
                }
            } catch {
                message = L("Could not reach the lobby service.")
            }
            self.stopTunnel()
            self.current = nil
            self.roster = []
            self.items = []
            await refreshAfterAction()
        }
    }

    func invite(userID: String) {
        Task {
            guard
                let session = await EmberAccountStore.shared.validSession(),
                let current, current.isHost
            else { return }
            do {
                let result = try await lobbies.invite(lobby: current.id, user: userID, session: session)
                message = Self.message(for: result)
            } catch {
                message = L("Could not reach the lobby service.")
            }
        }
    }

    /// Adds each draft to the lobby's content list. Duplicates are skipped silently.
    func addItems(_ drafts: [LobbyContentDraft]) async {
        guard
            let session = await EmberAccountStore.shared.validSession(),
            let current
        else { return }
        do {
            for draft in drafts {
                let result = try await lobbies.addItem(
                    lobby: current.id,
                    kind: draft.kind,
                    projectID: draft.projectID,
                    versionID: draft.versionID,
                    title: draft.title,
                    session: session
                )
                switch result {
                case .ok, .duplicate, .invalid, .notFound:
                    break
                case .forbidden:
                    message = L("You are not allowed to change this lobby's content.")
                case .locked:
                    message = L("The server is already running; stop it to change the content.")
                case .limit:
                    message = L("The lobby content list is full.")
                }
            }
        } catch {
            message = L("Could not reach the lobby service.")
        }
        await loadItems(lobby: current.id, session: session)
    }

    func removeItem(_ item: LobbyItem) async {
        guard
            let session = await EmberAccountStore.shared.validSession(),
            let current
        else { return }
        do {
            _ = try await lobbies.removeItem(lobby: current.id, item: item.id, session: session)
        } catch {
            message = L("Could not reach the lobby service.")
        }
        await loadItems(lobby: current.id, session: session)
    }

    /// Host only: updates the lobby's edit policy and sync defaults, optimistically
    /// then via the RPC.
    func setSettings(editPolicy: LobbyEditPolicy, syncShaders: Bool, syncResourcePacks: Bool) async {
        guard
            let session = await EmberAccountStore.shared.validSession(),
            let current, current.isHost
        else { return }
        self.current?.editPolicy = editPolicy
        self.current?.syncShaders = syncShaders
        self.current?.syncResourcePacks = syncResourcePacks
        do {
            try await lobbies.setSettings(
                lobby: current.id,
                editPolicy: editPolicy,
                syncShaders: syncShaders,
                syncResourcePacks: syncResourcePacks,
                session: session
            )
        } catch {
            message = L("Could not reach the lobby service.")
        }
        await loadInfo(session: session)
    }

    /// Host only: grants or revokes a member's permission to edit the content list.
    func setCanEdit(userID: String, can: Bool) async {
        guard
            let session = await EmberAccountStore.shared.validSession(),
            let current, current.isHost
        else { return }
        do {
            try await lobbies.setMemberCanEdit(lobby: current.id, user: userID, can: can, session: session)
        } catch {
            message = L("Could not reach the lobby service.")
        }
        await loadRoster(lobby: current.id, session: session)
    }

    /// Host only: reopens a closed server, putting the lobby back into "starting"
    /// so a new address can be published.
    func reopen() async {
        guard
            let session = await EmberAccountStore.shared.validSession(),
            let current, current.isHost
        else { return }
        do {
            try await lobbies.reopen(lobby: current.id, session: session)
            hostService?.stop()
            hostService = nil
            self.current?.status = "starting"
            self.current?.address = nil
        } catch {
            message = L("Could not reach the lobby service.")
        }
        await loadInfo(session: session)
    }

    // MARK: - Internals

    private func loadVisible(session: EmberSession) async {
        do {
            visible = try await lobbies.visibleLobbies(session: session)
        } catch {
            message = L("Could not reach the lobby service.")
        }
    }

    /// Refreshes the roster. Errors are swallowed: a transient failure should not
    /// drop the user out of the lobby they are currently in.
    private func loadRoster(lobby: String, session: EmberSession) async {
        do {
            roster = try await lobbies.roster(lobby: lobby, session: session)
        } catch {
            // Keep the existing roster/current state as is.
        }
    }

    /// Refreshes the active lobby's room state. Clears `current` when the lobby has
    /// closed or we have been removed from it, unless we are the host.
    private func loadInfo(session: EmberSession) async {
        guard let current else { return }
        do {
            guard let info = try await lobbies.info(lobby: current.id, session: session) else {
                if !current.isHost {
                    message = L("This lobby has closed.")
                    stopTunnel()
                    self.current = nil
                    roster = []
                    items = []
                }
                return
            }
            self.current?.status = info.status
            self.current?.editPolicy = info.editPolicy
            self.current?.syncShaders = info.syncShaders
            self.current?.syncResourcePacks = info.syncResourcePacks
            self.current?.canEdit = info.canEdit
            self.current?.address = info.address

            guard !current.isHost else { return }
            if info.status == "open", info.address != nil, guestService == nil, !tunnelConnecting {
                await connectTunnel(lobbyID: current.id, hostUser: current.hostUser)
            } else if info.status == "starting", guestService != nil {
                stopTunnel()
            }
        } catch {
            // Keep the existing lobby state as is; a transient failure should not drop the user.
        }
    }

    /// Refreshes the active lobby's content list. Errors are swallowed, same as loadRoster.
    private func loadItems(lobby: String, session: EmberSession) async {
        do {
            items = try await lobbies.items(lobby: lobby, session: session)
        } catch {
            // Keep the existing items as is.
        }
    }

    private func refreshAfterAction() async {
        guard let session = await EmberAccountStore.shared.validSession() else {
            visible = []
            return
        }
        await loadVisible(session: session)
        if let current {
            await loadRoster(lobby: current.id, session: session)
        }
    }

    private static func message(for result: LobbyInviteResult) -> String {
        switch result {
        case .invited: return L("Invitation sent.")
        case .forbidden, .notFriends: return L("You can only invite friends to your own lobby.")
        }
    }
}
