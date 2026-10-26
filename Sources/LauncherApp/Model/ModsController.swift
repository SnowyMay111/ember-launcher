import Foundation
import LauncherCore
import SwiftUI

/// State holder for the Mods screen.
@MainActor
final class ModsController: ObservableObject {
    @Published var installed: [InstalledMod] = []
    @Published var results: [ModrinthHit] = []
    @Published var isSearching: Bool = false
    @Published var updates: [ModUpdate] = []
    @Published var isCheckingUpdates: Bool = false
    @Published var busy: Set<String> = []
    @Published var message: String?

    private unowned let app: AppState
    private let manager: ModManager
    private var searchCounter = 0

    init(app: AppState) {
        self.app = app
        self.manager = ModManager(store: app.store)
        reload()
    }

    var instanceName: String? {
        app.current?.name
    }

    var canInstall: Bool {
        app.current?.loader == .fabric
    }

    var installedProjectIDs: Set<String> {
        Set(installed.compactMap { $0.record?.projectId })
    }

    /// Reads installed mods from disk and prunes outdated update entries.
    func reload() {
        guard let name = instanceName else {
            installed = []
            updates = []
            return
        }
        installed = (try? manager.list(instance: name)) ?? []
        let currentFiles = Set(installed.map(\.fileName))
        updates.removeAll { !currentFiles.contains($0.record.fileName) }
    }

    func search(query: String) async {
        guard canInstall, let instance = app.current else {
            results = []
            return
        }

        searchCounter += 1
        let searchID = searchCounter
        isSearching = true
        defer {
            if searchCounter == searchID {
                isSearching = false
            }
        }

        do {
            let hits = try await manager.client.search(
                query: query,
                gameVersion: instance.minecraftVersion,
                loader: "fabric"
            )
            guard searchCounter == searchID else { return }
            results = hits
        } catch {
            guard searchCounter == searchID else { return }
            message = error.localizedDescription
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
