import AppKit
import LauncherCore
import SwiftUI

enum Screen: String, CaseIterable, Identifiable {
    case play = "Play"
    case library = "Library"
    case mods = "Mods"
    case skins = "Skins"
    case settings = "Settings"

    var id: String { rawValue }
}

/// A dialog shown over the current screen.
enum AppModal: Equatable {
    case newInstance
    case instanceSettings(String)
    case gameLog(String)
    case optimize(String)
    case changeVersion(String)
    case sessionHealth(String)
    case allVersions
}

@MainActor
final class AppState: ObservableObject {
    private static let currentKey = "currentInstance"

    @Published var screen: Screen = .play
    @Published private(set) var instances: [LibraryInstance] = []
    @Published var currentID: String? {
        didSet { UserDefaults.standard.set(currentID, forKey: Self.currentKey) }
    }
    @Published var filter: LoaderFilter = .all
    @Published var search: String = ""
    @Published var modal: AppModal?
    /// Mojang's version list; nil until it has been fetched, or while offline.
    @Published private(set) var manifest: VersionManifest?
    /// Versions being downloaded from All versions: Minecraft version → percent done.
    @Published var downloads: [String: Int] = [:]
    /// Why the last download of a version failed; cleared when it is started again.
    @Published var downloadErrors: [String: String] = [:]

    let paths: LauncherPaths
    let store: InstanceStore
    let versionInstaller: VersionInstaller

    init() {
        let paths = LauncherPaths()
        self.paths = paths
        store = InstanceStore(paths: paths)
        versionInstaller = VersionInstaller(paths: paths)
        currentID = UserDefaults.standard.string(forKey: Self.currentKey)
        reload()
        Task { await loadManifest() }
    }

    // MARK: - Reading

    /// The chosen instance, else the one played last, else the first.
    var current: LibraryInstance? {
        instances.first { $0.id == currentID }
            ?? instances.filter { $0.lastPlayed != nil }.max { ($0.lastPlayed ?? .distantPast) < ($1.lastPlayed ?? .distantPast) }
            ?? instances.first
    }

    var filteredInstances: [LibraryInstance] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return instances.filter { item in
            filter.matches(item.loader)
                && (query.isEmpty || item.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }
    }

    /// Filtered instances split by group: Favorites, Vanilla, Mods, then the user's own groups.
    var groupedInstances: [(name: String, items: [LibraryInstance])] {
        let items = filteredInstances
        let present = Set(items.map(\.group))
        let custom = present.subtracting(GroupName.defaults).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let order = GroupName.defaults.filter(present.contains) + custom
        return order.map { name in (name: name, items: items.filter { $0.group == name }) }
    }

    /// Every group a user can pick: the three defaults and any group already in use.
    var groupNames: [String] {
        let custom = Set(instances.map(\.group)).subtracting(GroupName.defaults).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return GroupName.defaults + custom
    }

    func launchableVersions(includeSnapshots: Bool) -> [ManifestVersion] {
        manifest.map { VersionCatalog.launchable($0, includeSnapshots: includeSnapshots) } ?? []
    }

    func reload() {
        let saved = (try? store.list()) ?? []
        instances = saved.map { LibraryInstance($0, modCount: store.modCount(for: $0.name)) }
    }

    func loadManifest() async {
        if let fetched = try? await versionInstaller.fetchManifest() {
            manifest = fetched
        }
    }

    // MARK: - Choosing

    /// Clicking a card in Library makes it the current instance and shows it on Play.
    func open(_ item: LibraryInstance) {
        currentID = item.id
        screen = .play
    }

    /// Quick start: the latest release or snapshot as a vanilla instance, created on first use.
    func useLatest(snapshot: Bool, memoryMB: Int) {
        guard let latest = manifest?.latest else { return }
        let version = snapshot ? latest.snapshot : latest.release
        let name = "Vanilla \(version)"
        if store.exists(name: name) {
            currentID = name
        } else {
            _ = try? createInstance(name: name, minecraftVersion: version, loader: .vanilla, group: nil, memoryMB: memoryMB)
        }
    }

    // MARK: - Changing

    /// Makes the instance (files are downloaded on its first Play) and selects it. Returns the final name.
    @discardableResult
    func createInstance(name: String, minecraftVersion: String, loader: LoaderKind, group: String?, memoryMB: Int) throws -> String {
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = store.uniqueName(base: base.isEmpty ? "\(loader.rawValue) \(minecraftVersion)" : base)
        // Fabric, Forge and NeoForge are installed on the first Play, which fills in the version id.
        let isVanilla = loader == .vanilla
        try store.create(Instance(
            name: finalName,
            minecraftVersion: minecraftVersion,
            loader: loader.coreName,
            versionId: isVanilla ? minecraftVersion : "",
            memoryMB: memoryMB,
            group: group
        ))
        reload()
        currentID = finalName
        return finalName
    }

    func updateInstance(_ name: String, newName: String, memoryMB: Int, gcProfile: GCProfile, javaArgs: [String], group: String?) throws {
        defer { reload() }
        var instance = try store.load(name: name)
        instance.memoryMB = memoryMB
        instance.gcProfile = gcProfile
        instance.extraJVMArgs = javaArgs
        instance.group = group
        try store.save(instance)
        if newName != name {
            let renamed = try store.rename(name, to: newName)
            if currentID == name { currentID = renamed.name }
        }
    }

    func setLockFps(_ name: String, _ on: Bool) throws {
        defer { reload() }
        var instance = try store.load(name: name)
        instance.lockFpsToMonitor = on
        try store.save(instance)
    }

    /// Copies the whole instance folder (worlds and mods included) on a background thread.
    func duplicateInstance(_ name: String) async throws -> String {
        let copyName = store.uniqueName(base: "\(name) copy")
        let store = self.store
        try await Task.detached { _ = try store.duplicate(name, as: copyName) }.value
        reload()
        currentID = copyName
        return copyName
    }

    /// Moves the instance to the macOS Trash; it is never deleted for good.
    func trashInstance(_ name: String) throws {
        try store.moveToTrash(name)
        if currentID == name { currentID = nil }
        reload()
    }

    func openFolder(_ name: String) {
        let folder = store.gameDirectory(for: name)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }
}
