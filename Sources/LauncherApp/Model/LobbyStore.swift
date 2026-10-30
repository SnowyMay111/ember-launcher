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
}

/// Lobby discovery, hosting and membership, backed by the Ember lobby service.
@MainActor
final class LobbyStore: ObservableObject {
    static let shared = LobbyStore()

    @Published private(set) var visible: [VisibleLobby] = []
    @Published private(set) var current: ActiveLobby?
    @Published private(set) var roster: [LobbyMember] = []
    @Published var message: String?

    private let lobbies = EmberLobbies()
    private var loop: Task<Void, Never>?

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
                }

                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        visible = []
        current = nil
        roster = []
    }

    // MARK: - Actions

    func host(_ request: LobbyCreateRequest) {
        Task {
            guard let session = await EmberAccountStore.shared.validSession() else { return }
            do {
                let created = try await lobbies.create(request, session: session)
                current = ActiveLobby(
                    id: created.id,
                    code: created.code,
                    name: request.name,
                    isHost: true,
                    address: nil,
                    packURL: request.packURL,
                    packSHA1: request.packSHA1,
                    mcVersion: request.mcVersion,
                    loader: request.loader
                )
                message = nil
            } catch {
                message = L("Could not reach the lobby service.")
            }
            await refreshAfterAction()
        }
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
            } catch {
                message = L("Could not reach the lobby service.")
            }
            await refreshAfterAction()
        }
    }

    func join(code: String?, lobbyID: String?, nick: String) {
        Task {
            guard let session = await EmberAccountStore.shared.validSession() else { return }
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
                        loader: lobby.loader
                    )
                    message = nil
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
        }
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
            self.current = nil
            self.roster = []
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
