import Combine
import Foundation
import LauncherCore

/// Joining a lobby only gets you into the room: you see the shared content list
/// and press Play once the host's server is running. LobbyRoom keeps your local
/// instance in sync with that list; LobbyStore polls the lobby and opens the
/// guest tunnel on its own once the lobby is open.
@MainActor
final class LobbyGuestController: ObservableObject {
    static let shared = LobbyGuestController()

    @Published private(set) var state: LobbyHostState = .idle
    @Published private(set) var roomInstance: String?
    @Published private(set) var errorMessage: String?

    private var lobbyWatch: AnyCancellable?

    private init() {
        lobbyWatch = LobbyStore.shared.$current
            .dropFirst()
            .sink { [weak self] current in
                guard let self, current == nil else { return }
                LobbyRoom.shared.detach()
                self.roomInstance = nil
                self.state = .idle
            }
    }

    var isBusy: Bool {
        if case .preparing = state { return true }
        return false
    }

    func join(code: String?, lobbyID: String?, settings: SettingsStore, app: AppState) {
        guard !isBusy else { return }
        errorMessage = nil
        state = .preparing(L("Joining the lobby…"))
        Task { await run(code: code, lobbyID: lobbyID, settings: settings, app: app) }
    }

    private func run(code: String?, lobbyID: String?, settings: SettingsStore, app: AppState) async {
        let lobbies = LobbyStore.shared
        guard await lobbies.join(code: code, lobbyID: lobbyID, nick: settings.nickname),
              let lobby = lobbies.current
        else {
            state = .failed(lobbies.message ?? L("Could not reach the lobby service."))
            if lobbies.current != nil { lobbies.leave() }
            return
        }
        do {
            let item = try instance(for: lobby, app: app)
            roomInstance = item.name
            LobbyRoom.shared.attach(instance: item.name)
            app.modal = .lobby
            state = .room
        } catch {
            lobbies.leave()
            state = .failed(error.localizedDescription)
        }
    }

    /// Installs the lobby's current content list and launches the game against
    /// the host's server, once it is up and the guest tunnel is open.
    func play(settings: SettingsStore, app: AppState, play: PlayController) {
        guard case .room = state, !play.isBusy,
              LobbyStore.shared.current?.isRunning == true,
              let port = LobbyStore.shared.tunnelPort,
              let roomInstance
        else { return }
        errorMessage = nil
        state = .preparing(L("Installing the lobby's content…"))
        Task {
            do {
                try await LobbyRoom.shared.pull(final: true)
                guard let item = app.instances.first(where: { $0.id == roomInstance }) else {
                    throw LobbyGuestError.instanceMissing
                }
                app.modal = nil
                play.play(item, settings: settings, app: app, quickPlayServer: "127.0.0.1:\(port)")
                state = .room
            } catch {
                errorMessage = error.localizedDescription
                state = .room
            }
        }
    }

    func leave() {
        LobbyStore.shared.leave()
        LobbyRoom.shared.detach()
        roomInstance = nil
        state = .idle
    }

    /// An instance on the lobby's Minecraft version, Fabric, dedicated to this
    /// lobby so the synced content list never touches the player's own
    /// instances; created when the player doesn't already have one.
    private func instance(for lobby: ActiveLobby, app: AppState) throws -> LibraryInstance {
        let name = "Lobby \(lobby.mcVersion)"
        if let existing = app.instances.first(where: { $0.id == name && $0.loader == .fabric }) {
            return existing
        }
        let created = try app.createInstance(
            name: name,
            minecraftVersion: lobby.mcVersion,
            loader: .fabric,
            group: nil,
            memoryMB: 4096
        )
        guard let item = app.instances.first(where: { $0.id == created }) else {
            throw LobbyGuestError.instanceMissing
        }
        return item
    }

    private enum LobbyGuestError: LocalizedError {
        case instanceMissing

        var errorDescription: String? {
            L("Could not prepare an instance for this lobby.")
        }
    }
}
