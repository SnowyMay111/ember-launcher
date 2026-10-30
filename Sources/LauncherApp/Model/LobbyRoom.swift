import Combine
import Foundation
import LauncherCore

/// Keeps one local instance in sync with the lobby room's shared content list, for
/// both the host (who seeds and publishes new content) and guests (who only pull).
@MainActor
final class LobbyRoom: ObservableObject {
    static let shared = LobbyRoom()

    @Published private(set) var instanceName: String?
    @Published private(set) var progress: String?
    /// Enabled hand-added mods of the source instance that cannot be shared (no Modrinth record).
    @Published private(set) var unsyncedCount = 0

    private let content: ContentInstaller

    private var subscription: AnyCancellable?
    private var pulling = false
    private var pullAgainNeeded = false

    private init() {
        content = ContentInstaller(store: GameLauncher(paths: LauncherPaths()).store)
    }

    /// Starts tracking `instance` as this player's room instance and begins pulling
    /// the lobby's content list into it whenever it changes.
    func attach(instance: String) {
        instanceName = instance
        subscription = LobbyStore.shared.$items
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.coalescedPull()
                }
            }
    }

    func detach() {
        subscription?.cancel()
        subscription = nil
        instanceName = nil
        progress = nil
    }

    /// Seeds the lobby's content list from an existing instance (used when hosting
    /// starts from a pre-existing modpack rather than an empty room).
    func seed(from source: String) async {
        guard let mods = try? content.modManager.list(instance: source) else { return }
        let records = content.loadContentRecords(instance: source)
        let (drafts, unsynced) = LobbyContentDrafts.make(mods: mods, content: records)
        unsyncedCount = unsynced
        await LobbyStore.shared.addItems(drafts)
    }

    /// Host only: adds anything the room instance has that the lobby's content list
    /// doesn't know about yet (e.g. mods added after hosting started).
    func publishNewContent() async {
        guard let instanceName, LobbyStore.shared.current?.canEdit == true else { return }
        guard let mods = try? content.modManager.list(instance: instanceName) else { return }
        let records = content.loadContentRecords(instance: instanceName)
        let (drafts, _) = LobbyContentDrafts.make(mods: mods, content: records)
        let known = Set(LobbyStore.shared.items.map(\.versionID))
        let newDrafts = drafts.filter { !known.contains($0.versionID) }
        guard !newDrafts.isEmpty else { return }
        await LobbyStore.shared.addItems(newDrafts)
    }

    /// Syncs the lobby's content list into the room instance. `final` is true right
    /// before starting the server or the game, and throws on failure; the
    /// incremental background pulls (`final == false`) only install new content and
    /// leave anything extra alone.
    func pull(final: Bool) async throws {
        guard let instanceName else { return }
        let lobby = LobbyStore.shared.current
        let options = LobbyContentSyncOptions(
            syncShaders: lobby?.syncShaders ?? false,
            syncResourcePacks: lobby?.syncResourcePacks ?? true,
            activate: true,
            switchOffExtraMods: final
        )
        let items = LobbyStore.shared.items
        let syncer = LobbyContentSyncer(content: content)
        let relay = ModProgressRelay { [weak self] done, total in
            Task { @MainActor in self?.progress = L("Installing the lobby's content %d/%d", done, total) }
        }
        do {
            _ = try await syncer.sync(items, options: options, into: instanceName) { relay.report($0, $1) }
            progress = nil
        } catch {
            progress = nil
            throw error
        }
    }

    private func coalescedPull() async {
        guard !pulling else {
            pullAgainNeeded = true
            return
        }
        pulling = true
        repeat {
            pullAgainNeeded = false
            try? await pull(final: false)
        } while pullAgainNeeded
        pulling = false
    }

    private final class ModProgressRelay: @unchecked Sendable {
        private let handler: @Sendable (Int, Int) -> Void
        init(_ handler: @escaping @Sendable (Int, Int) -> Void) { self.handler = handler }
        func report(_ done: Int, _ total: Int) { handler(done, total) }
    }
}
