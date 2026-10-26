import LauncherCore
import SwiftUI

struct NewInstanceModal: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

    @Local private var name = ""
    @Local private var version = ""
    @Local private var loader: LoaderKind = .vanilla
    @Local private var group = GroupName.vanilla
    @Local private var fabricVersions: Set<String>?
    @Local private var errorText = ""
    @Local private var mode = Mode.custom
    @Local private var pack: MrpackSummary?
    @Local private var packURL: URL?
    @Local private var isImporting = false
    @Local private var importProgress = ""
    @Local private var importReport: MrpackImportReport?

    private enum Mode { case custom, mrpack }

    /// Versions the chosen loader can run; Fabric supports only some of them.
    private var versions: [ManifestVersion] {
        let all = app.launchableVersions(includeSnapshots: settings.showSnapshots)
        guard loader == .fabric, let fabric = fabricVersions else { return all }
        return all.filter { fabric.contains($0.id) }
    }

    private var namePlaceholder: String {
        "\(loader.rawValue) \(version)"
    }

    var body: some View {
        VoxelModal(title: "New instance") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    FilterChip(title: "Custom", isActive: mode == .custom) { mode = .custom }
                    FilterChip(title: "Import .mrpack", isActive: mode == .mrpack) { mode = .mrpack }
                    FilterChip(title: "Describe with AI", isActive: false, isDisabled: true) {}
                }

                if mode == .mrpack {
                    packPicker
                }

                if mode == .custom || pack != nil {
                    ModalField(label: "Name") {
                        VoxelInput(label: "Name", text: $name, placeholder: mode == .mrpack ? (pack?.name ?? "") : namePlaceholder)
                    }
                }

                if mode == .custom {
                HStack(alignment: .top, spacing: 24) {
                    ModalField(label: "Minecraft version") {
                        VoxelMenu(label: "Minecraft version", value: version.isEmpty ? "…" : version, minWidth: 170) {
                            ForEach(versions, id: \.id) { entry in
                                Button(title(for: entry)) { version = entry.id }
                            }
                        }
                    }
                    ModalField(label: "Loader") {
                        HStack(spacing: 8) {
                            ForEach([LoaderKind.vanilla, .fabric]) { kind in
                                FilterChip(title: kind.rawValue, isActive: loader == kind) { loader = kind }
                            }
                        }
                        .frame(height: 40)
                    }
                }
                }

                if mode == .custom || pack != nil {
                    ModalField(label: "Group") {
                        GroupPicker(group: $group)
                    }
                }

                if app.manifest == nil {
                    Text(tr: "Couldn't load the version list. Check your connection.").style(.secondary)
                }
                if !errorText.isEmpty {
                    Text(verbatim: errorText).style(.secondary)
                }
            }
        } footer: {
            if let importReport, !importReport.failed.isEmpty {
                PrimaryPill(title: "Done") { app.modal = nil }
            } else {
                ModalCancel()
                if mode == .mrpack {
                    PrimaryPill(title: isImporting ? "Importing…" : "Import", isDisabled: pack == nil || isImporting, action: importPack)
                } else {
                    PrimaryPill(title: "Create", isDisabled: version.isEmpty, action: create)
                }
            }
        }
        .task { await prepare() }
        .onChange(of: loader) { old, new in
            if group == GroupName.automatic(for: old) { group = GroupName.automatic(for: new) }
            chooseVersion()
        }
        .onChange(of: versions.map(\.id)) { chooseVersion() }
    }

    /// The file chooser, and once a pack is picked, what is inside it.
    @ViewBuilder
    private var packPicker: some View {
        if let pack {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: pack.name).style(.row)
                Text(verbatim: packDetails(pack)).style(.secondary)
            }
        } else {
            Text(tr: "Packs from Modrinth and other launchers work. Forge packs are not supported yet.").style(.secondary)
        }
        if !isImporting, importReport == nil {
            SecondaryPill(title: pack == nil ? "Choose .mrpack file…" : "Choose another file…", action: choosePack)
        }
        if isImporting {
            Text(verbatim: importProgress).style(.secondary)
        }
        if let importReport, !importReport.failed.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: L("Imported, but %d files could not be downloaded:", importReport.failed.count)).style(.secondary)
                ForEach(importReport.failed.prefix(8), id: \.self) { line in
                    Text(verbatim: line).style(.secondary).lineLimit(1)
                }
            }
        }
    }

    private func packDetails(_ pack: MrpackSummary) -> String {
        let loaderName = pack.loader == "fabric" ? "Fabric" : "Vanilla"
        let size = ByteCountFormatter.string(fromByteCount: pack.downloadBytes, countStyle: .file)
        return L("Minecraft %@ · %@ · %d files · %@", pack.minecraftVersion, loaderName, pack.fileCount, size)
    }

    private func choosePack() {
        guard let url = app.chooseMrpack() else { return }
        errorText = ""
        Task {
            do {
                pack = try await app.inspectPack(url)
                packURL = url
                if group == GroupName.automatic(for: .vanilla) {
                    group = GroupName.automatic(for: pack?.loader == "fabric" ? .fabric : .vanilla)
                }
            } catch {
                pack = nil
                packURL = nil
                errorText = error.localizedDescription
            }
        }
    }

    private func importPack() {
        guard let packURL, !isImporting else { return }
        let chosen = group.trimmingCharacters(in: .whitespacesAndNewlines)
        let loaderKind: LoaderKind = pack?.loader == "fabric" ? .fabric : .vanilla
        let saved = chosen.isEmpty || chosen == GroupName.automatic(for: loaderKind) ? nil : chosen
        isImporting = true
        errorText = ""
        importProgress = L("Reading the pack")
        Task {
            do {
                let report = try await app.importPack(
                    packURL, name: name, group: saved, memoryMB: Int(settings.memoryGB) * 1024
                ) { phase, fraction in
                    let text = L(phase) + (fraction > 0 && fraction < 1 ? " · \(Int(fraction * 100))%" : "")
                    Task { @MainActor in importProgress = text }
                }
                isImporting = false
                if report.failed.isEmpty {
                    app.modal = nil
                } else {
                    importReport = report
                }
            } catch {
                isImporting = false
                errorText = error.localizedDescription
            }
        }
    }

    private func title(for entry: ManifestVersion) -> String {
        var text = entry.id
        if entry.id == app.manifest?.latest.release { text += " · " + L("Latest") }
        if entry.type == "snapshot" { text += " · " + L("Snapshot") }
        return text
    }

    private func prepare() async {
        if app.manifest == nil { await app.loadManifest() }
        let fabric = FabricInstaller(paths: app.paths, installer: app.versionInstaller)
        fabricVersions = try? await fabric.supportedGameVersions()
        chooseVersion()
    }

    /// Keeps the picked version valid: the latest release at first, the newest available after a loader change.
    private func chooseVersion() {
        let ids = versions.map(\.id)
        guard !ids.contains(version) else { return }
        if let latest = app.manifest?.latest.release, ids.contains(latest) {
            version = latest
        } else {
            version = ids.first ?? ""
        }
    }

    private func create() {
        let chosen = group.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = chosen.isEmpty || chosen == GroupName.automatic(for: loader) ? nil : chosen
        do {
            try app.createInstance(
                name: name,
                minecraftVersion: version,
                loader: loader,
                group: saved,
                memoryMB: Int(settings.memoryGB) * 1024
            )
            app.modal = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
