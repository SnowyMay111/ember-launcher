import Foundation
import LauncherCore
import SwiftUI

enum BrowseSort: String, CaseIterable, Sendable {
    case relevance = "relevance"
    case downloads = "downloads"
    case newest = "newest"
    case updated = "updated"
    case follows = "follows"

    var title: String {
        switch self {
        case .relevance: return "Relevance"
        case .downloads: return "Popular"
        case .newest: return "Newest"
        case .updated: return "Recently updated"
        case .follows: return "Most followed"
        }
    }
}

/// State holder for the Mods screen.
@MainActor
final class ModsController: ObservableObject {
    @Published var installed: [InstalledMod] = []
    @Published var results: [ModrinthHit] = []
    @Published var compat: [String: ModCompatibility] = [:]
    @Published var isSearching: Bool = false
    @Published var updates: [ModUpdate] = []
    @Published var isCheckingUpdates: Bool = false
    @Published var busy: Set<String> = []
    @Published var message: String?
    @Published var sort: BrowseSort?
    @Published var categories: Set<String> = []
    @Published var totalHits: Int = 0
    @Published var isLoadingMore: Bool = false
    /// What Browse searches for. Mods are handled above; shaders, resource packs and modpacks go through `ContentInstaller`.
    @Published var kind: ContentKind = .mod {
        didSet {
            guard kind != oldValue else { return }
            searchCounter += 1
            isSearching = false
            isLoadingMore = false
            results = []
            categories = []
            totalHits = 0
            compat = [:]
            contentCompat = [:]
            isChecking = false
        }
    }
    @Published var contentCompat: [String: ContentCompatibility] = [:]
    /// Browse lists only what fits the current instance; this brings the rest back, greyed out and not installable.
    @Published var showIncompatible = false
    /// True while the compatibility of the current results is still being checked.
    @Published var isChecking = false
    /// Minecraft version the modpack list is limited to: nil follows the current instance, `anyVersion` lifts the limit.
    @Published var modpackVersionChoice: String?
    static let anyVersion = "*"
    /// Installed shaders and resource packs of the current instance.
    @Published var contentRecords: [ContentRecord] = []

    private unowned let app: AppState
    private let manager: ModManager
    private let content: ContentInstaller
    private var searchCounter = 0

    init(app: AppState) {
        self.app = app
        self.manager = ModManager(store: app.store)
        self.content = ContentInstaller(store: app.store)
        reload()
    }

    var instanceName: String? {
        app.current?.name
    }

    var canInstall: Bool {
        app.current?.loader.supportsMods ?? false
    }

    /// Shaders go through Iris, which exists for Fabric only.
    private var canInstallShaders: Bool {
        app.current?.loader == .fabric
    }

    var installedProjectIDs: Set<String> {
        Set(installed.compactMap { $0.record?.projectId })
    }

    /// Whether Browse has anything to offer for the chosen kind (modpacks need no instance; mods and shaders can be looked at on any instance).
    var canBrowse: Bool {
        switch kind {
        case .mod, .shader, .resourcepack: return app.current != nil
        case .modpack: return true
        }
    }

    var canLoadMore: Bool {
        canBrowse && results.count < totalHits
    }

    /// The Minecraft version modpacks are searched for; nil lists them all.
    var modpackGameVersion: String? {
        switch modpackVersionChoice {
        case nil: return app.current?.minecraftVersion
        case Self.anyVersion: return nil
        case let version?: return version
        }
    }

    /// What Browse shows: only results known to fit, unless the toggle is on or the instance cannot install them anyway.
    var visibleResults: [ModrinthHit] {
        if showIncompatible || needsFabric { return results }
        return results.filter(isUsable)
    }

    var hiddenCount: Int {
        showIncompatible || needsFabric || isChecking ? 0 : results.count - visibleResults.count
    }

    /// A result whose check has not finished stays out of the list; one whose check failed is given the benefit of the doubt.
    private func isUsable(_ hit: ModrinthHit) -> Bool {
        if kind == .mod {
            guard let value = compat[hit.projectId] else { return !isChecking }
            switch value {
            case .unavailable, .conflict: return false
            case .ready, .needs, .unknown: return true
            }
        }
        guard let value = contentCompat[hit.projectId] else { return !isChecking }
        switch value {
        case .noRelease: return false
        case .ready: return true
        case .needsOther(let text): return text == "needsShaderLoader"
        }
    }

    /// Mods and shaders are listed on a vanilla instance too, but cannot be installed until it is switched to Fabric.
    var needsFabric: Bool {
        guard app.current != nil else { return false }
        switch kind {
        case .mod: return !canInstall
        case .shader: return !canInstallShaders
        case .resourcepack, .modpack: return false
        }
    }

    /// Only a vanilla instance can be turned into a Fabric one; a Forge instance keeps its loader.
    var canSwitchToFabric: Bool {
        app.current?.loader == .vanilla
    }

    /// Turns the current vanilla instance into a Fabric one; Fabric itself is downloaded on the next Play.
    func switchToFabric() async {
        guard let instance = app.current, instance.loader == .vanilla else { return }
        do {
            let fabric = FabricInstaller(paths: app.paths, installer: app.versionInstaller)
            if let supported = try? await fabric.supportedGameVersions(), !supported.contains(instance.minecraftVersion) {
                message = L("Fabric does not support Minecraft %@.", instance.minecraftVersion)
                return
            }
            var updated = try app.store.load(name: instance.name)
            updated.loader = "fabric"
            updated.versionId = ""
            updated.loaderVersion = nil
            try app.store.save(updated)
            app.reload()
            reload()
            message = L("Switched %@ to Fabric. It is installed on the next Play.", instance.name)
            await search(query: "")
        } catch {
            message = error.localizedDescription
        }
    }

    /// Project ids of the shaders and resource packs already in the current instance.
    var contentProjectIDs: Set<String> {
        Set(contentRecords.map(\.projectId))
    }

    /// Reads installed mods from disk and prunes outdated update entries.
    func reload() {
        guard let name = instanceName else {
            installed = []
            updates = []
            contentRecords = []
            return
        }
        installed = (try? manager.list(instance: name)) ?? []
        contentRecords = content.loadContentRecords(instance: name)
            .filter { $0.kind == .shader || $0.kind == .resourcepack }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let currentFiles = Set(installed.map(\.fileName))
        updates.removeAll { !currentFiles.contains($0.record.fileName) }
    }

    func search(query: String) async {
        guard kind == .mod else {
            await searchCatalog(query: query)
            return
        }
        guard let instance = app.current else {
            results = []
            totalHits = 0
            return
        }

        searchCounter += 1
        let searchID = searchCounter
        isSearching = true
        isLoadingMore = false
        defer {
            if searchCounter == searchID {
                isSearching = false
            }
        }

        do {
            let page = try await manager.client.searchPage(
                query: query,
                gameVersion: instance.minecraftVersion,
                loader: instance.loader.supportsMods ? instance.loader.coreName : "fabric",
                categories: Array(categories),
                sortBy: sort?.rawValue
            )
            guard searchCounter == searchID else { return }
            results = page.hits
            totalHits = page.totalHits
            compat = [:]
            isChecking = canInstall
            if canInstall {
                Task {
                    await checkCompatibility(of: page.hits, searchID: searchID)
                    if searchCounter == searchID { isChecking = false }
                }
            }
        } catch {
            guard searchCounter == searchID else { return }
            message = error.localizedDescription
        }
    }

    /// Fills `compat` for the search results, a few requests at a time; a newer search cancels the rest.
    private func checkCompatibility(of hits: [ModrinthHit], searchID: Int) async {
        guard let name = instanceName else { return }
        let manager = self.manager
        var index = 0
        while index < hits.count, searchCounter == searchID {
            let batch = hits[index..<min(index + 5, hits.count)]
            let found = await withTaskGroup(of: (String, ModCompatibility).self) { group in
                for hit in batch {
                    group.addTask { (hit.projectId, await manager.compatibility(project: hit.projectId, instance: name)) }
                }
                var pairs: [String: ModCompatibility] = [:]
                for await (id, value) in group { pairs[id] = value }
                return pairs
            }
            guard searchCounter == searchID else { return }
            compat.merge(found) { _, new in new }
            index += 5
        }
    }

    func install(_ hit: ModrinthHit) async {
        guard let name = instanceName else { return }
        busy.insert(hit.projectId)
        defer { busy.remove(hit.projectId) }

        do {
            let result = try await manager.install(project: hit.projectId, into: name)
            reload()
            app.reload()
            if !result.warnings.isEmpty {
                let joined = result.warnings.joined(separator: "; ")
                message = "\(L("Installed %@.", hit.title)) \(joined)"
            }
        } catch {
            message = error.localizedDescription
        }
    }

    // MARK: - Shaders, resource packs, modpacks

    /// Popular projects when the query is empty. Shaders and resource packs follow the current instance's Minecraft version; modpacks have no filter.
    private func searchCatalog(query: String) async {
        let kind = self.kind
        guard canBrowse else {
            results = []
            totalHits = 0
            return
        }

        searchCounter += 1
        let searchID = searchCounter
        isSearching = true
        isLoadingMore = false
        defer {
            if searchCounter == searchID {
                isSearching = false
            }
        }

        do {
            let page = try await manager.client.searchPage(
                query: query,
                projectType: kind.projectType,
                gameVersion: kind == .modpack ? modpackGameVersion : app.current?.minecraftVersion,
                loaders: kind == .modpack ? ContentInstaller.packLoaders : [],
                categories: Array(categories),
                sortBy: sort?.rawValue
            )
            guard searchCounter == searchID else { return }
            results = page.hits
            totalHits = page.totalHits
            contentCompat = [:]
            isChecking = !needsFabric
            if !needsFabric {
                Task {
                    await checkContentCompatibility(of: page.hits, kind: kind, searchID: searchID)
                    if searchCounter == searchID { isChecking = false }
                }
            }
        } catch {
            guard searchCounter == searchID else { return }
            message = error.localizedDescription
        }
    }

    func loadMore(query: String) async {
        guard !isSearching, !isLoadingMore, canLoadMore else { return }

        let searchID = searchCounter
        isLoadingMore = true
        defer {
            if searchCounter == searchID {
                isLoadingMore = false
            }
        }

        let offset = results.count
        let limit = 20
        let currentKind = self.kind

        do {
            let page: ModrinthSearchResult
            if currentKind == .mod {
                guard let instance = app.current else { return }
                page = try await manager.client.searchPage(
                    query: query,
                    gameVersion: instance.minecraftVersion,
                    loader: instance.loader.supportsMods ? instance.loader.coreName : "fabric",
                    categories: Array(categories),
                    sortBy: sort?.rawValue,
                    limit: limit,
                    offset: offset
                )
            } else {
                guard canBrowse else { return }
                page = try await manager.client.searchPage(
                    query: query,
                    projectType: currentKind.projectType,
                    gameVersion: currentKind == .modpack ? modpackGameVersion : app.current?.minecraftVersion,
                    loaders: currentKind == .modpack ? ContentInstaller.packLoaders : [],
                    categories: Array(categories),
                    sortBy: sort?.rawValue,
                    limit: limit,
                    offset: offset
                )
            }

            guard searchCounter == searchID else { return }
            totalHits = page.totalHits

            let existingIDs = Set(results.map(\.projectId))
            let newHits = page.hits.filter { !existingIDs.contains($0.projectId) }
            results.append(contentsOf: newHits)

            if currentKind == .mod {
                if canInstall, !newHits.isEmpty {
                    isChecking = true
                    await checkCompatibility(of: newHits, searchID: searchID)
                    if searchCounter == searchID { isChecking = false }
                }
            } else {
                if !needsFabric, !newHits.isEmpty {
                    isChecking = true
                    await checkContentCompatibility(of: newHits, kind: currentKind, searchID: searchID)
                    if searchCounter == searchID { isChecking = false }
                }
            }
        } catch {
            guard searchCounter == searchID else { return }
            message = error.localizedDescription
        }
    }

    /// Fills `contentCompat` for the search results, a few requests at a time; a newer search cancels the rest.
    private func checkContentCompatibility(of hits: [ModrinthHit], kind: ContentKind, searchID: Int) async {
        guard let name = instanceName else { return }
        let content = self.content
        let modpackVersion = modpackGameVersion
        var index = 0
        while index < hits.count, searchCounter == searchID {
            let batch = hits[index..<min(index + 5, hits.count)]
            let found = await withTaskGroup(of: (String, ContentCompatibility?).self) { group in
                for hit in batch {
                    group.addTask { (hit.projectId, try? await content.compatibility(project: hit.projectId, kind: kind, instance: name, modpackGameVersion: modpackVersion)) }
                }
                var pairs: [String: ContentCompatibility] = [:]
                for await (id, value) in group {
                    if let value { pairs[id] = value }
                }
                return pairs
            }
            guard searchCounter == searchID else { return }
            contentCompat.merge(found) { _, new in new }
            index += 5
        }
    }

    /// The one Install button for shaders, resource packs and modpacks.
    func installContent(_ hit: ModrinthHit) async {
        busy.insert(hit.projectId)
        defer { busy.remove(hit.projectId) }

        do {
            switch kind {
            case .shader:
                guard let name = instanceName else { return }
                var withIris = false
                var result = try await content.install(project: hit.projectId, kind: .shader, into: name)
                if result == .needsShaderLoader {
                    try await content.ensureShaderSupport(into: name)
                    withIris = true
                    result = try await content.install(project: hit.projectId, kind: .shader, into: name)
                }
                finishInstall(result, title: hit.title, withIris: withIris)
            case .resourcepack:
                guard let name = instanceName else { return }
                let result = try await content.install(project: hit.projectId, kind: .resourcepack, into: name)
                finishInstall(result, title: hit.title, withIris: false)
            case .modpack:
                let report = try await content.createInstance(fromModpack: hit.projectId, gameVersion: modpackGameVersion)
                app.reload()
                app.currentID = report.instanceName
                app.screen = .play
                let loader = report.loader.lowercased() == "fabric" ? "Fabric" : "Vanilla"
                message = ([L("Created %@ (Minecraft %@, %@)", report.instanceName, report.minecraftVersion, loader)] + report.warnings)
                    .joined(separator: " ")
            case .mod:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func finishInstall(_ result: ContentInstallResult, title: String, withIris: Bool) {
        reload()
        app.reload()
        switch result {
        case .installed:
            message = withIris ? L("Installed %@ with Iris.", title) : L("Installed %@.", title)
        case .skipped:
            message = L("%@ is already in this instance.", title)
        case .unsupported(let text):
            message = text
        case .needsShaderLoader:
            message = L("Shaders need Iris, but it could not be installed.")
        case .mod:
            break
        }
    }

    /// Moves the file to the Trash and drops its record; nothing is deleted for good.
    func remove(_ record: ContentRecord) {
        guard let name = instanceName else { return }
        busy.insert(record.fileName)
        defer { busy.remove(record.fileName) }

        do {
            let fm = FileManager.default
            let file = content.contentDirectory(for: record.kind, in: name).appendingPathComponent(record.fileName)
            if fm.fileExists(atPath: file.path) {
                try fm.trashItem(at: file, resultingItemURL: nil)
            }
            // The installer also leaves a link beside the instance folder; it points nowhere now.
            if let folder = record.kind.subfolder {
                let link = app.store.instanceDirectory(for: name)
                    .appendingPathComponent(folder, isDirectory: true)
                    .appendingPathComponent(record.fileName)
                if (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil {
                    try? fm.trashItem(at: link, resultingItemURL: nil)
                }
            }
            var records = content.loadContentRecords(instance: name)
            records.removeAll { $0.fileName == record.fileName }
            try content.saveContentRecords(records, instance: name)
            reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func setEnabled(_ mod: InstalledMod, _ enabled: Bool) {
        guard let name = instanceName else { return }
        busy.insert(mod.fileName)
        defer { busy.remove(mod.fileName) }

        do {
            try manager.setEnabled(instance: name, fileName: mod.fileName, enabled: enabled)
            reload()
            app.reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func remove(_ mod: InstalledMod) {
        guard let name = instanceName else { return }
        busy.insert(mod.fileName)
        defer { busy.remove(mod.fileName) }

        do {
            try manager.remove(instance: name, fileName: mod.fileName)
            reload()
            app.reload()
        } catch {
            message = error.localizedDescription
        }
    }

    func checkUpdates() async {
        guard let name = instanceName else { return }
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        do {
            let found = try await manager.updates(instance: name)
            updates = found
            if found.isEmpty {
                message = L("Everything is up to date.")
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func apply(_ update: ModUpdate) async {
        guard let name = instanceName else { return }
        let fileName = update.record.fileName
        busy.insert(fileName)
        defer { busy.remove(fileName) }

        do {
            try await manager.apply(update: update, instance: name)
            reload()
            app.reload()
            updates.removeAll { $0.record.fileName == fileName }
        } catch {
            message = error.localizedDescription
        }
    }

    func applyAll() async {
        let pending = updates
        for update in pending {
            await apply(update)
        }
    }
}
