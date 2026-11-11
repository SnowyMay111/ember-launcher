import LauncherCore
import SwiftUI

/// Singleplayer worlds of one instance: copy now, see the copies, put one back.
struct WorldsModal: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var player: PlayController

    let instanceName: String

    @Local private var worlds: [SingleplayerWorld] = []
    @Local private var copies: [String: [SingleplayerBackup]] = [:]
    @Local private var restoring: SingleplayerBackup?
    @Local private var restoringWorld = ""
    @Local private var statusText = ""
    @Local private var errorText = ""
    @Local private var reloadRequest = 0

    private var backups: WorldBackups { WorldBackups(store: app.store, instance: instanceName) }

    var body: some View {
        EmberModal(title: "Worlds", width: 560) {
            VStack(alignment: .leading, spacing: 14) {
                if worlds.isEmpty {
                    Text(tr: "No singleplayer worlds yet. Play once and they show up here.").style(.secondary)
                }
                ForEach(worlds) { world in
                    worldCard(world)
                }
                if let restoring {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr: "Restore this copy? The current world is kept as “before-restore”.")
                            .style(.init(size: 14, weight: .regular, color: Theme.text))
                        HStack(spacing: 10) {
                            SecondaryPill(title: "Cancel") { self.restoring = nil }
                            PrimaryPill(title: "Restore") { restore(restoring, as: restoringWorld) }
                        }
                    }
                }
                if !statusText.isEmpty { Text(verbatim: statusText).style(.secondary) }
                if !errorText.isEmpty { Text(verbatim: errorText).style(.secondary) }
            }
        } footer: {
            SecondaryPill(title: "Open backups folder", action: openBackupsFolder)
            ModalCancel(title: "Close")
        }
        .onAppear(perform: reload)
    }

    private func worldCard(_ world: SingleplayerWorld) -> some View {
        let list = copies[world.folderName] ?? []
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: world.folderName).style(.init(size: 15, weight: .semibold, color: Theme.text))
                    Text(verbatim: ByteCountFormatter.string(fromByteCount: world.bytes, countStyle: .file) + " · "
                         + (list.first.map { L("Last copy %@", relative($0.date)) } ?? L("No copies yet")))
                        .style(.secondary)
                }
                Spacer(minLength: 8)
                SecondaryPill(title: "Back up now", height: 32) { backUp(world.folderName) }
            }
            if !list.isEmpty {
                VStack(spacing: 0) {
                    ForEach(list.prefix(6)) { copy in
                        HStack(spacing: 10) {
                            Text(verbatim: relative(copy.date)).style(.init(size: 13, weight: .regular, color: Theme.text))
                            Text(verbatim: L(copy.isAutomatic ? "Automatic copy" : "Manual copy") + " · "
                                 + ByteCountFormatter.string(fromByteCount: copy.bytes, countStyle: .file))
                                .style(.secondary)
                            Spacer(minLength: 8)
                            SecondaryPill(title: "Restore", height: 28) {
                                restoringWorld = world.folderName
                                restoring = copy
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func reload() {
        reloadRequest += 1
        let request = reloadRequest
        let source = backups
        Task {
            // Reading every world and its copies touches a lot of files, so it stays off the main thread.
            let (found, lists) = await Task.detached {
                let found = source.worlds()
                let lists = Dictionary(uniqueKeysWithValues: found.map { ($0.folderName, source.backups(of: $0.folderName)) })
                return (found, lists)
            }.value
            // A slower, older listing must not replace a newer one.
            guard request == reloadRequest else { return }
            worlds = found
            copies = lists
        }
    }

    private func backUp(_ name: String) {
        statusText = ""
        errorText = ""
        do {
            try backups.backUp(name)
            statusText = L("Backed up “%@”.", name)
            reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func restore(_ copy: SingleplayerBackup, as name: String) {
        statusText = ""
        errorText = ""
        restoring = nil
        guard !player.isBusy else {
            errorText = L("Close the game before restoring a world.")
            return
        }
        do {
            try backups.restore(copy, as: name)
            statusText = L("Restored “%@”. The previous version is in the world-backups folder.", name)
            reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func openBackupsFolder() {
        let folder = app.store.instanceDirectory(for: instanceName).appendingPathComponent("world-backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }
}
