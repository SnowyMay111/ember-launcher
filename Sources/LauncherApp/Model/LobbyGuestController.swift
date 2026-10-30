import Foundation
import LauncherCore

/// One-button joining: joins the lobby, opens the tunnel to the host and starts the game on it.
@MainActor
final class LobbyGuestController: ObservableObject {
    static let shared = LobbyGuestController()

    @Published private(set) var state: LobbyHostState = .idle

    private init() {}

    var isBusy: Bool {
        if case .preparing = state { return true }
        return false
    }

    func join(code: String?, lobbyID: String?, settings: SettingsStore, app: AppState, play: PlayController) {
        guard !isBusy, !play.isBusy else { return }
        state = .preparing(L("Joining the lobby…"))
        Task { await run(code: code, lobbyID: lobbyID, settings: settings, app: app, play: play) }
    }

    private func run(code: String?, lobbyID: String?, settings: SettingsStore, app: AppState, play: PlayController) async {
        let lobbies = LobbyStore.shared
        guard await lobbies.join(code: code, lobbyID: lobbyID, nick: settings.nickname),
              let lobby = lobbies.current, let port = lobbies.tunnelPort
        else {
            state = .failed(lobbies.message ?? L("Could not reach the lobby service."))
            if lobbies.current != nil { lobbies.leave() }
            return
        }
        do {
            let item = try instance(for: lobby, app: app)
            state = .running
            app.modal = nil
            play.play(item, settings: settings, app: app, quickPlayServer: "127.0.0.1:\(port)")
        } catch {
            lobbies.leave()
            state = .failed(error.localizedDescription)
        }
    }

    /// An instance on the lobby's Minecraft version, preferring Fabric; made when the player has none.
    private func instance(for lobby: ActiveLobby, app: AppState) throws -> LibraryInstance {
        let sameVersion = app.instances.filter { $0.minecraftVersion == lobby.mcVersion }
        if let found = sameVersion.first(where: { $0.loader == .fabric }) ?? sameVersion.first(where: { $0.loader == .vanilla }) {
            return found
        }
        let name = try app.createInstance(
            name: "Lobby \(lobby.mcVersion)",
            minecraftVersion: lobby.mcVersion,
            loader: .fabric,
            group: nil,
            memoryMB: 4096
        )
        guard let created = app.instances.first(where: { $0.id == name }) else {
            throw LobbyGuestError.instanceMissing
        }
        return created
    }

    private enum LobbyGuestError: LocalizedError {
        case instanceMissing

        var errorDescription: String? {
            L("Could not prepare an instance for this lobby.")
        }
    }
}
