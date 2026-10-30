import LauncherCore
import SwiftUI

/// Moves a Fabric instance to another Minecraft version (worlds and mods are backed up first)
/// and lists the backups, each restorable in one click.
struct VersionModal: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayController

    let instance: LibraryInstance

    @Local private var target = ""
    @Local private var fabricVersions: Set<String>?
    @Local private var checks: [ModUpgradeCheck]?
    @Local private var isChecking = false
    @Local private var isUpgrading = false
    @Local private var progress = ""
    @Local private var report: UpgradeReport?
    @Local private var snapshots: [SnapshotInfo] = []
    @Local private var confirmingRestore: String?
    @Local private var isRestoring = false
    @Local private var errorText = ""

    /// Versions Fabric can run, without the one the instance is already on.
    private var versions: [ManifestVersion] {
        let all = app.launchableVersions(includeSnapshots: settings.showSnapshots)
        guard let fabric = fabricVersions else { return [] }
        return all.filter { fabric.contains($0.id) && $0.id != instance.minecraftVersion }
    }

    private var isBusy: Bool { isUpgrading || isRestoring }

    var body: some View {
        EmberModal(title: "Change version", width: 560) {
            VStack(alignment: .leading, spacing: 18) {
                Text(verbatim: instance.versionLine).style(.secondary)

                if instance.loader != .fabric {
                    Text(tr: "Only Fabric instances can change version.").style(.secondary)
                } else if player.isBusy {
                    Text(tr: "Close the game first.").style(.secondary)
                } else {
                    upgradeSection
                }

                backupsSection

                if !errorText.isEmpty {
                    Text(verbatim: errorText).style(.secondary)
                }
            }
        } footer: {
            ModalCancel()
            if instance.loader == .fabric && !player.isBusy {
                PrimaryPill(
                    title: isUpgrading ? "Changing…" : "Change version",
                    isDisabled: target.isEmpty || isBusy,
                    action: upgrade
                )
            }
        }
        .task { await prepare() }
        .task(id: target) { await check() }
        // After a change or a restore the instance is a different version: pick a new target.
        .onChange(of: instance.minecraftVersion) { chooseTarget() }
    }

    // MARK: - Sections

    private var upgradeSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModalField(label: "New Minecraft version") {
                EmberMenu(label: "New Minecraft version", value: target.isEmpty ? "…" : target, minWidth: 170) {
                    ForEach(versions, id: \.id) { entry in
                        Button(title(for: entry)) {
                            target = entry.id
                            report = nil
                        }
                    }
                }
                Text(tr: "Worlds and mods are backed up first. You can roll back from the list below.").style(.secondary)
            }

            if isUpgrading {
                Text(verbatim: progress).style(.secondary)
            } else {
                if let report {
                    reportSection(report)
                }
                if isChecking {
                    Text(tr: "Checking mods…").style(.secondary)
                } else if let checks {
                    checksSection(checks)
                }
            }
        }
    }

    private func checksSection(_ checks: [ModUpgradeCheck]) -> some View {
        let missing = checks.filter { !$0.isAvailable }
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: L("Mods with a compatible version: %d of %d", checks.count - missing.count, checks.count))
                .style(.secondary)
            if !missing.isEmpty {
                Text(verbatim: L("Will be turned off: %@", missing.map(\.record.title).joined(separator: ", ")))
                    .style(.secondary)
            }
        }
    }

    private func reportSection(_ report: UpgradeReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: L("Now on %@.", instance.minecraftVersion)).style(.init(size: 14, weight: .bold, color: Theme.text))
            Text(verbatim: L("Mods updated: %d", report.updated.count)).style(.secondary)
            if !report.disabled.isEmpty {
                Text(verbatim: L("Turned off: %@", report.disabled.joined(separator: ", "))).style(.secondary)
            }
            if !report.failed.isEmpty {
                Text(verbatim: L("Failed: %@", report.failed.joined(separator: ", "))).style(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.black45))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
    }

    private var backupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr: "Backups").style(.eyebrow)
            if snapshots.isEmpty {
                Text(tr: "No backups yet.").style(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(snapshots) { snapshot in
                            snapshotRow(snapshot)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 190)
            }
        }
    }

    private func snapshotRow(_ snapshot: SnapshotInfo) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: reasonTitle(snapshot.reason)).style(.init(size: 14, weight: .bold, color: Theme.text))
                Text(verbatim: confirmingRestore == snapshot.id ? L("Current worlds and mods go to the Trash.") : details(of: snapshot))
                    .style(.secondary)
            }
            Spacer(minLength: 8)
            if confirmingRestore == snapshot.id {
                SecondaryPill(title: "Keep it") { confirmingRestore = nil }
                PrimaryPill(title: isRestoring ? "Restoring…" : "Restore", height: 36, horizontalPadding: 22, isDisabled: isBusy) {
                    restore(snapshot)
                }
            } else if !player.isBusy {
                SecondaryPill(title: "Restore") { confirmingRestore = snapshot.id }
            }
        }
    }

    // MARK: - Text

    private func title(for entry: ManifestVersion) -> String {
        var text = entry.id
        if entry.id == app.manifest?.latest.release { text += " · " + L("Latest") }
        if entry.type == "snapshot" { text += " · " + L("Snapshot") }
        return text
    }

    /// Folder names read `before-1.21.5` or `before-restore`.
    private func reasonTitle(_ reason: String) -> String {
        guard reason.hasPrefix("before-") else { return reason }
        let rest = String(reason.dropFirst("before-".count))
        return rest == "restore" ? L("Before restore") : L("Before %@", rest)
    }

    private func details(of snapshot: SnapshotInfo) -> String {
        let date = snapshot.createdAt.formatted(date: .abbreviated, time: .shortened)
        let size = ByteCountFormatter.string(fromByteCount: snapshot.sizeBytes, countStyle: .file)
        let parts = [snapshot.gameVersion, date, size].compactMap { $0 }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func makeUpgrader() -> InstanceUpgrader {
        InstanceUpgrader(
            store: app.store,
            launcher: GameLauncher(paths: app.paths),
            mods: ModManager(store: app.store)
        )
    }

    private func prepare() async {
        loadSnapshots()
        guard instance.loader == .fabric else { return }
        if app.manifest == nil { await app.loadManifest() }
        let fabric = FabricInstaller(paths: app.paths, installer: app.versionInstaller)
        fabricVersions = try? await fabric.supportedGameVersions()
        chooseTarget()
    }

    /// The latest release at first, the newest available when that is the current version.
    private func chooseTarget() {
        let ids = versions.map(\.id)
        guard !ids.contains(target) else { return }
        if let latest = app.manifest?.latest.release, ids.contains(latest) {
            target = latest
        } else {
            target = ids.first ?? ""
        }
    }

    private func loadSnapshots() {
        snapshots = (try? makeUpgrader().listSnapshots(instance: instance.name)) ?? []
    }

    private func check() async {
        guard !target.isEmpty, !isUpgrading else { return }
        checks = nil
        isChecking = true
        let result = try? await ModManager(store: app.store).checkUpgrade(instance: instance.name, to: target)
        guard !Task.isCancelled else { return }
        checks = result
        isChecking = false
    }

    private func upgrade() {
        guard !player.isBusy else {
            errorText = L("Close the game first.")
            return
        }
        guard !isBusy, !target.isEmpty else { return }
        isUpgrading = true
        errorText = ""
        report = nil
        progress = L("Backing up worlds and mods")
        let version = target
        let name = instance.name
        Task {
            do {
                report = try await makeUpgrader().upgrade(instance: name, to: version) { line in
                    // The core reports plain English lines; the second one carries the version.
                    let text = line.hasPrefix("Installing Minecraft") ? L("Installing Minecraft %@ and Fabric", version) : L(line)
                    Task { @MainActor in progress = text }
                }
                isUpgrading = false
                app.reload()
                loadSnapshots()
            } catch {
                errorText = error.localizedDescription
                isUpgrading = false
            }
        }
    }

    private func restore(_ snapshot: SnapshotInfo) {
        guard !player.isBusy else {
            errorText = L("Close the game first.")
            return
        }
        guard !isBusy else { return }
        isRestoring = true
        errorText = ""
        let name = instance.name
        let id = snapshot.id
        let upgrader = makeUpgrader()
        Task {
            do {
                try await Task.detached { try upgrader.restore(instance: name, snapshot: id) }.value
                confirmingRestore = nil
                isRestoring = false
                report = nil
                app.reload()
                loadSnapshots()
            } catch {
                errorText = error.localizedDescription
                confirmingRestore = nil
                isRestoring = false
            }
        }
    }
}
