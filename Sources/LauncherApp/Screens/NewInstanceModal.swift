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
    @Local private var quiltVersions: Set<String>?
    @Local private var forgeVersions: [LoaderKind: Set<String>] = [:]
    @Local private var errorText = ""
    @Local private var mode = Mode.custom
    @Local private var pack: MrpackSummary?
    @Local private var packURL: URL?
    @Local private var isImporting = false
    @Local private var importProgress = ""
    @Local private var importReport: MrpackImportReport?
    @Local private var aiText = ""
    @Local private var plan: ModpackPlan?
    @Local private var picked: Set<String> = []
    @Local private var isPlanning = false
    @Local private var isBuilding = false
    @Local private var buildProgress = ""
    @Local private var buildReport: ModpackBuildReport?
    @Local private var step = 1
    @Local private var installFraction: Double?

    private enum Mode { case custom, mrpack, ai }

    /// AI packs are always Fabric.
    private var activeLoader: LoaderKind { mode == .ai ? .fabric : loader }

    /// Versions the chosen loader can run; Fabric, Forge and NeoForge support only some of them.
    private var versions: [ManifestVersion] {
        let all = app.launchableVersions(includeSnapshots: settings.showSnapshots)
        let supported: Set<String>?
        switch activeLoader {
        case .vanilla: supported = nil
        case .fabric: supported = fabricVersions
        case .quilt: supported = quiltVersions
        case .forge, .neoforge: supported = forgeVersions[activeLoader]
        }
        guard let supported else { return all }
        return all.filter { supported.contains($0.id) }
    }

    private var namePlaceholder: String {
        "\(activeLoader.rawValue) \(version)"
    }

    /// True when the wizard flow (Custom mode) is active.
    private var isWizard: Bool { mode == .custom }

    /// True while an mrpack import or AI pack build is in progress.
    private var isWorking: Bool { isImporting || isBuilding }

    /// A non-empty name suitable for display in previews and summaries.
    private var displayName: String { name.trimmingCharacters(in: .whitespaces).isEmpty ? namePlaceholder : name }

    /// The title shown at the top of the modal, varying by flow and state.
    private var wizardTitle: String {
        if isWorking { return "Preparing your world" }
        if isWizard { return ["Name your adventure", "Choose a foundation", "Ready to create"][step - 1] }
        return "New instance"
    }

    /// The title used on the install progress screen.
    private var installTitle: String {
        isImporting ? (pack?.name ?? L("Importing…")) : (plan?.name ?? displayName)
    }

    private static let loaderNotes: [LoaderKind: String] = [
        .vanilla: "The original experience",
        .fabric: "Lightweight and mod-friendly",
        .quilt: "Fabric-compatible community loader",
        .forge: "Built for expansive modpacks",
        .neoforge: "Modern community loader"
    ]

    private var versionMenu: some View {
        ModalField(label: "Minecraft version") {
            VoxelMenu(label: "Minecraft version", value: version.isEmpty ? "…" : version, minWidth: 170) {
                ForEach(versions, id: \.id) { entry in
                    Button(title(for: entry)) { version = entry.id }
                }
            }
        }
    }

    private var showsNameAndGroup: Bool {
        switch mode {
        case .custom: return true
        case .mrpack: return pack != nil
        case .ai: return plan != nil
        }
    }

    var body: some View {
        VoxelModal(title: wizardTitle, eyebrow: "NEW INSTANCE") {
            if isWorking {
                FlowInstallState(title: installTitle, detail: isImporting ? importProgress : buildProgress, fraction: installFraction)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    if isWizard {
                        FlowStepper(step: step).frame(maxWidth: .infinity)
                    }

                    if !isWizard || step == 1 {
                        HStack(spacing: 8) {
                            FilterChip(title: "Custom", isActive: mode == .custom) { mode = .custom }
                            FilterChip(title: "Import .mrpack", isActive: mode == .mrpack) { mode = .mrpack }
                            FilterChip(title: "Describe with AI", isActive: mode == .ai) { mode = .ai }
                        }
                    }

                    if mode == .mrpack {
                        packPicker
                    }
                    if mode == .ai {
                        aiPicker
                    }

                    if mode == .custom && step == 1 {
                        ModalField(label: "Instance name") {
                            VoxelInput(label: "Name", text: $name, placeholder: namePlaceholder)
                        }
                        NamePreviewCard(name: displayName)
                    }

                    if mode == .custom && step == 2 {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                            ForEach(LoaderKind.allCases, id: \.self) { kind in
                                ChoiceCard(title: kind.rawValue, subtitle: Self.loaderNotes[kind] ?? "", isSelected: loader == kind) {
                                    loader = kind
                                }
                            }
                        }
                        versionMenu
                    }

                    if mode == .custom && step == 3 {
                        SummaryCard(rows: [
                            ("NAME", displayName),
                            ("VERSION", "Minecraft " + version),
                            ("LOADER", loader.rawValue),
                            ("MEMORY", "\(Int(settings.memoryGB)) GB")
                        ])
                        ModalField(label: "Group") {
                            GroupPicker(group: $group)
                        }
                    }

                    if !isWizard && showsNameAndGroup {
                        ModalField(label: "Name") {
                            VoxelInput(label: "Name", text: $name, placeholder: mode == .mrpack ? (pack?.name ?? "") : (mode == .ai ? (plan?.name ?? "") : namePlaceholder))
                        }
                    }

                    if !isWizard && showsNameAndGroup {
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
            }
        } footer: {
            if isWorking {
                EmptyView()
            } else if (importReport.map { !$0.failed.isEmpty } ?? false) || buildReport != nil {
                FlowPrimaryButton(title: "Done") { app.modal = nil }
            } else if isWizard {
                if step == 1 {
                    ModalCancel()
                } else {
                    FlowTextButton(title: "Back") { step -= 1 }
                }
                Spacer()
                FlowPrimaryButton(title: step == 3 ? "Create instance →" : "Continue →", isDisabled: step >= 2 && version.isEmpty) {
                    if step < 3 {
                        step += 1
                    } else {
                        create()
                    }
                }
            } else {
                ModalCancel()
                Spacer()
                if mode == .mrpack {
                    FlowPrimaryButton(title: isImporting ? "Importing…" : "Import", isDisabled: pack == nil || isImporting, action: importPack)
                } else if mode == .ai {
                    if plan == nil {
                        FlowPrimaryButton(
                            title: isPlanning ? "Thinking…" : "Suggest mods",
                            isDisabled: isPlanning || version.isEmpty || !settings.hasAIKey || aiText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            action: generate
                        )
                    } else {
                        FlowPrimaryButton(
                            title: isBuilding ? "Installing…" : L("Create with %d mods", picked.count),
                            isDisabled: isBuilding || picked.isEmpty,
                            action: buildAIPack
                        )
                    }
                } else {
                    FlowPrimaryButton(title: "Create", isDisabled: version.isEmpty, action: create)
                }
            }
        }
        .task { await prepare() }
        .onChange(of: loader) { old, new in
            if group == GroupName.automatic(for: old) { group = GroupName.automatic(for: new) }
            chooseVersion()
        }
        .onChange(of: versions.map(\.id)) { chooseVersion() }
        .onChange(of: mode) { _, new in
            if new == .ai { group = GroupName.automatic(for: .fabric) }
            if new == .custom { group = GroupName.automatic(for: loader) }
            errorText = ""
            step = 1
            chooseVersion()
        }
    }

    /// The description box and version first; after "Suggest mods", the list to tick.
    @ViewBuilder
    private var aiPicker: some View {
        if let plan {
            Text(verbatim: plan.summary).style(.secondary)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(plan.mods) { mod in
                        HStack(alignment: .top, spacing: 14) {
                            VoxelCheckbox(label: mod.title, isOn: Binding(
                                get: { picked.contains(mod.projectId) },
                                set: { isOn in
                                    if isOn { picked.insert(mod.projectId) } else { picked.remove(mod.projectId) }
                                }
                            ))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: mod.title).style(.row)
                                Text(verbatim: mod.reason).style(.secondary).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxHeight: 230)
            if !plan.unresolved.isEmpty {
                Text(verbatim: L("No %@ release found for: %@", plan.minecraftVersion, plan.unresolved.joined(separator: ", "))).style(.secondary)
            }
            if isBuilding {
                Text(verbatim: buildProgress).style(.secondary)
            }
            if let buildReport {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: L("Installed %d mods, but %d were skipped:", buildReport.installed.count, buildReport.skipped.count)).style(.secondary)
                    ForEach(buildReport.skipped.prefix(8), id: \.self) { line in
                        Text(verbatim: line).style(.secondary).lineLimit(1)
                    }
                }
            }
        } else {
            ModalField(label: "Describe your pack") {
                VoxelTextArea(
                    label: "Describe your pack",
                    text: $aiText,
                    placeholder: L("A cozy survival pack with better graphics, a minimap and some farming mods")
                )
            }
            versionMenu
            if !settings.hasAIKey {
                Text(tr: "Add your AI key in Settings first.").style(.secondary)
                SecondaryPill(title: "Open Settings") {
                    app.modal = nil
                    app.screen = .settings
                }
            } else {
                Text(tr: "The AI only suggests mods. You tick what to keep before anything is installed.").style(.secondary)
            }
        }
    }

    private func generate() {
        guard !isPlanning else { return }
        isPlanning = true
        errorText = ""
        Task {
            do {
                let result = try await app.planPack(description: aiText, minecraftVersion: version, settings: settings)
                plan = result
                picked = Set(result.mods.map(\.projectId))
            } catch {
                errorText = L(error.localizedDescription)
            }
            isPlanning = false
        }
    }

    private func buildAIPack() {
        guard let plan, !isBuilding else { return }
        let chosen = plan.mods.filter { picked.contains($0.projectId) }
        let trimmed = group.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = trimmed.isEmpty || trimmed == GroupName.automatic(for: .fabric) ? nil : trimmed
        isBuilding = true
        installFraction = nil
        errorText = ""
        Task {
            do {
                let report = try await app.buildPack(
                    name: name.isEmpty ? plan.name : name,
                    minecraftVersion: plan.minecraftVersion,
                    group: saved,
                    memoryMB: Int(settings.memoryGB) * 1024,
                    mods: chosen
                ) { title, done, total in
                    let text = L("Installing %@ (%d of %d)", title, done + 1, total)
                    Task {
                        @MainActor in
                        buildProgress = text
                        installFraction = total > 0 ? Double(done) / Double(total) : nil
                    }
                }
                isBuilding = false
                if report.skipped.isEmpty {
                    app.modal = nil
                } else {
                    buildReport = report
                }
            } catch {
                isBuilding = false
                errorText = error.localizedDescription
            }
        }
    }

    /// The file chooser, and once a pack is picked, what is inside it.
    @ViewBuilder
    private var packPicker: some View {
        if let pack {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: pack.name).style(.row)
                Text(verbatim: packDetails(pack)).style(.secondary)
                if pack.overrideJarCount > 0 {
                    Text(verbatim: L("The pack has %d mods that do not come from Modrinth. Install packs only from people you trust.", pack.overrideJarCount))
                        .style(.secondary)
                        .foregroundColor(Theme.danger)
                }
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
        let loaderName = LoaderKind(coreName: pack.loader).rawValue
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
                    group = GroupName.automatic(for: LoaderKind(coreName: pack?.loader ?? "vanilla"))
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
        let loaderKind = LoaderKind(coreName: pack?.loader ?? "vanilla")
        let saved = chosen.isEmpty || chosen == GroupName.automatic(for: loaderKind) ? nil : chosen
        isImporting = true
        installFraction = nil
        errorText = ""
        importProgress = L("Reading the pack")
        Task {
            do {
                let report = try await app.importPack(
                    packURL, name: name, group: saved, memoryMB: Int(settings.memoryGB) * 1024
                ) { phase, fraction in
                    let text = L(phase) + (fraction > 0 && fraction < 1 ? " · \(Int(fraction * 100))%" : "")
                    Task { @MainActor in
                        importProgress = text
                        installFraction = (fraction > 0 && fraction < 1) ? fraction : nil
                    }
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
        let forge = ForgeInstaller(paths: app.paths, installer: app.versionInstaller, runtimeManager: JavaRuntimeManager(paths: app.paths))
        let candidates = app.launchableVersions(includeSnapshots: true).map(\.id)
        let quilt = QuiltInstaller(paths: app.paths, installer: app.versionInstaller)
        async let fabricSet = try? fabric.supportedGameVersions()
        async let quiltSet = try? quilt.supportedGameVersions()
        async let forgeSet = try? forge.supportedGameVersions(loader: .forge, among: candidates)
        async let neoForgeSet = try? forge.supportedGameVersions(loader: .neoforge, among: candidates)
        fabricVersions = await fabricSet
        quiltVersions = await quiltSet
        if let found = await forgeSet { forgeVersions[.forge] = found }
        if let found = await neoForgeSet { forgeVersions[.neoforge] = found }
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
