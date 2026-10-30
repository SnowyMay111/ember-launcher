import Foundation
import LauncherCore

/// One-button joining: joins the lobby, opens the tunnel to the host and starts the game on it.
@MainActor
final class LobbyGuestController: ObservableObject {
    static let shared = LobbyGuestController()

    @Published private(set) var state: LobbyHostState = .idle

    private let modManager = ModManager(store: GameLauncher(paths: LauncherPaths()).store)

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
            let mods = LobbyModList(packURL: lobby.packURL, packSHA1: lobby.packSHA1)
            let item = try instance(for: lobby, app: app, dedicated: mods != nil)
            if let mods {
                try await installMods(mods, into: item.name)
            }
            state = .running
            app.modal = nil
            play.play(item, settings: settings, app: app, quickPlayServer: "127.0.0.1:\(port)")
        } catch {
            lobbies.leave()
            state = .failed(error.localizedDescription)
        }
    }

    /// Puts the host's mods into the lobby's own instance; the player's other instances stay as they are.
    private func installMods(_ mods: LobbyModList, into instance: String) async throws {
        state = .preparing(L("Installing the host's mods…"))
        let syncer = LobbySyncer(manager: modManager)
        let relay = ModProgressRelay { [weak self] done, total in
            Task { @MainActor in self?.state = .preparing(L("Installing the host's mods %d/%d", done, total)) }
        }
        _ = try await syncer.sync(mods, into: instance) { relay.report($0, $1) }
    }

    /// An instance on the lobby's Minecraft version, preferring Fabric; made when the player has none.
    /// With `dedicated` the lobby gets its own "Lobby <version>" instance so synced mods never touch the player's own.
    private func instance(for lobby: ActiveLobby, app: AppState, dedicated: Bool) throws -> LibraryInstance {
        if dedicated {
            let name = "Lobby \(lobby.mcVersion)"
            if let existing = app.instances.first(where: { $0.id == name && $0.loader == .fabric }) {
                return existing
            }
        }
        let sameVersion = app.instances.filter { $0.minecraftVersion == lobby.mcVersion }
        if !dedicated, let found = sameVersion.first(where: { $0.loader == .fabric }) ?? sameVersion.first(where: { $0.loader == .vanilla }) {
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

    private final class ModProgressRelay: @unchecked Sendable {
        private let handler: @Sendable (Int, Int) -> Void
        init(_ handler: @escaping @Sendable (Int, Int) -> Void) { self.handler = handler }
        func report(_ done: Int, _ total: Int) { handler(done, total) }
    }

    private enum LobbyGuestError: LocalizedError {
        case instanceMissing

        var errorDescription: String? {
            L("Could not prepare an instance for this lobby.")
        }
    }
}
