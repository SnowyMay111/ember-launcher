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
                    FilterChip(title: "Custom", isActive: true) {}
                    FilterChip(title: "Import .mrpack", isActive: false, isDisabled: true) {}
                    FilterChip(title: "Describe with AI", isActive: false, isDisabled: true) {}
                }

                ModalField(label: "Name") {
                    VoxelInput(label: "Name", text: $name, placeholder: namePlaceholder)
                }

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

                ModalField(label: "Group") {
                    GroupPicker(group: $group)
                }

                if app.manifest == nil {
                    Text(tr: "Couldn't load the version list. Check your connection.").style(.secondary)
                }
                if !errorText.isEmpty {
                    Text(verbatim: errorText).style(.secondary)
                }
            }
        } footer: {
            ModalCancel()
            PrimaryPill(title: "Create", isDisabled: version.isEmpty, action: create)
        }
        .task { await prepare() }
        .onChange(of: loader) { old, new in
            if group == GroupName.automatic(for: old) { group = GroupName.automatic(for: new) }
            chooseVersion()
        }
        .onChange(of: versions.map(\.id)) { chooseVersion() }
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
