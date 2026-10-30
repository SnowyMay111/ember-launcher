import LauncherCore
import SwiftUI

/// Workbench: this build on the left, Modrinth search on the right, a basket to install several at once.
struct ModsScreen: View {
    @EnvironmentObject var app: AppState
    @ObservedObject private var lobbyRoom = LobbyRoom.shared
    @StateObject private var mods: ModsController
    @Local private var query = ""
    @Local private var confirmingRemove: String?
    @Local private var searchTask: Task<Void, Never>?
    @Local private var queue: [ModrinthHit] = []
    @Local private var isInstallingQueue = false

    init(app: AppState) {
        _mods = StateObject(wrappedValue: ModsController(app: app))
    }

    private var subtitle: String {
        if mods.kind == .modpack { return "Creates a new instance from a Modrinth pack." }
        guard let current = app.current else { return "Pick an instance in Library first." }
        switch mods.kind {
        case .shader:
            guard !mods.needsFabric else { return L("For %@ · %@", current.name, current.minecraftVersion) }
            return L("For %@ · %@ · Fabric + Iris", current.name, current.minecraftVersion)
        case .resourcepack:
            return L("For %@ · %@", current.name, current.minecraftVersion)
        default:
            guard mods.canInstall else { return L("For %@ · %@", current.name, current.minecraftVersion) }
            return L("For %@ · %@ · %@", current.name, current.minecraftVersion, current.loader.rawValue)
        }
    }

    private var searchPlaceholder: String {
        switch mods.kind {
        case .mod: return "Search mods"
        case .modpack: return "Search modpacks"
        case .shader: return "Search shaders"
        case .resourcepack: return "Search resource packs"
        }
    }

    private static func title(of kind: ContentKind) -> String {
        switch kind {
        case .mod: return "Mods"
        case .modpack: return "Modpacks"
        case .shader: return "Shaders"
        case .resourcepack: return "Resource packs"
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom, spacing: 16) {
                    PageHeader(eyebrow: "Discover", title: "Mods", subtitle: subtitle, alignment: .leading)
                    Spacer(minLength: 16)
                    kindSwitch
                }

                if lobbyRoom.instanceName != nil, lobbyRoom.instanceName == app.currentID {
                    HStack(spacing: 14) {
                        Text(tr: "Everything you add here goes into the lobby and syncs with your friends.")
                            .style(.secondary)
                        SecondaryPill(title: "Back to the lobby") { app.modal = .lobby }
                    }
                    .padding(.top, 12)
                }

                if mods.needsFabric {
                    HStack(spacing: 14) {
                        Text(tr: mods.kind == .shader ? "Shaders need a Fabric or NeoForge instance." : "Mods need a Fabric instance.")
                            .style(.secondary)
                        if mods.canSwitchToFabric {
                            SecondaryPill(title: "Switch to Fabric") { Task { await mods.switchToFabric() } }
                        }
                    }
                    .padding(.top, 10)
                }

                if let message = mods.message {
                    HStack(spacing: 10) {
                        Text(verbatim: message).style(.secondary).lineLimit(2)
                        Button { mods.message = nil } label: {
                            Text(verbatim: "×").style(.init(size: 16, weight: .medium, color: Theme.muted))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("Dismiss"))
                    }
                    .padding(.top, 10)
                }

                HStack(alignment: .top, spacing: 16) {
                    buildPanel.frame(width: 400)
                    findPanel
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .frame(width: min(1120, geo.size.width - 56), alignment: .leading)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
                if !queue.isEmpty { basketBar.padding(.bottom, 30).transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .animation(.easeOut(duration: 0.2), value: queue.isEmpty)
        }
        .padding(.top, 28)
        .onAppear {
            app.activeMods = mods
            mods.reload()
            if mods.results.isEmpty { runSearch(delay: 0) }
        }
        .onChange(of: app.currentID) { _, _ in
            queue = []
            mods.reload()
            runSearch(delay: 0)
        }
        .onChange(of: query) { _, _ in runSearch(delay: 350) }
        .onChange(of: mods.kind) { _, _ in
            queue = []
            runSearch(delay: 0)
        }
        .onChange(of: mods.sort) { _, _ in runSearch(delay: 0) }
        .onChange(of: mods.categories) { _, _ in runSearch(delay: 0) }
        .onChange(of: mods.modpackVersionChoice) { _, _ in runSearch(delay: 0) }
        .onChange(of: mods.modpackLoader) { _, _ in runSearch(delay: 0) }
    }

    @Environment(\.openURL) private var openURL

    static func projectURL(_ hit: ModrinthHit, kind: ContentKind) -> URL {
        let segment: String
        switch kind {
        case .mod: segment = "mod"
        case .modpack: segment = "modpack"
        case .shader: segment = "shader"
        case .resourcepack: segment = "resourcepack"
        }
        return URL(string: "https://modrinth.com/\(segment)/\(hit.slug)")!
    }

    private func runSearch(delay: Int) {
        searchTask?.cancel()
        let text = query
        searchTask = Task {
            if delay > 0 { try? await Task.sleep(for: .milliseconds(delay)) }
            guard !Task.isCancelled else { return }
            await mods.search(query: text)
        }
    }

    static func paletteIndex(_ seed: String) -> Int {
        Int(seed.utf8.reduce(0) { ($0 &* 31 &+ UInt32($1)) % 1000 })
    }

    // MARK: - Shell

    private var kindSwitch: some View {
        HStack(spacing: 2) {
            ForEach(ContentKind.allCases, id: \.rawValue) { item in
                FilterChip(title: Self.title(of: item), isActive: mods.kind == item, compact: true) { mods.kind = item }
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }

    private var hairline: some View {
        Rectangle().fill(Theme.border).frame(height: 1)
    }

    private func roundButton(_ symbol: String, isActive: Bool = false, isDisabled: Bool = false, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: symbol)
                .style(.init(size: 16, weight: .medium, color: isActive ? Theme.success : Theme.text))
                .frame(width: 34, height: 34)
                .background(Circle().fill(isActive ? Theme.success.opacity(0.16) : Theme.elevated))
                .overlay(Circle().strokeBorder(isActive ? Theme.success.opacity(0.5) : Theme.lineStrong, lineWidth: 1))
                .opacity(isDisabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(L(label))
    }

    // MARK: - This build

    private var buildCountText: String {
        mods.kind == .mod ? L("%d mods", mods.installed.count) : L("%d items", mods.contentRecords.filter { $0.kind == mods.kind }.count)
    }

    private var buildPanel: some View {
        panel {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr: "In this build").style(.init(size: 16, weight: .semibold))
                    if mods.kind != .modpack, app.current != nil {
                        Text(verbatim: buildCountText).style(.init(size: 13, color: Theme.textSecondary))
                    }
                }
                Spacer(minLength: 8)
                if mods.kind == .mod, mods.canInstall, !mods.installed.isEmpty {
                    if !mods.updates.isEmpty {
                        PrimaryPill(title: L("Update all (%d)", mods.updates.count), height: 32, horizontalPadding: 16) {
                            Task { await mods.applyAll() }
                        }
                    } else {
                        SecondaryPill(title: mods.isCheckingUpdates ? "Checking…" : "Check for updates", height: 32) {
                            Task { await mods.checkUpdates() }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            hairline
            ScrollView {
                LazyVStack(spacing: 0) { buildRows }
                    .padding(.bottom, queue.isEmpty ? 6 : 90)
            }
        }
    }

    @ViewBuilder
    private var buildRows: some View {
        if app.current == nil {
            buildNote("Pick an instance in Library first.")
        } else if mods.kind == .modpack {
            buildNote("A modpack creates a new instance. This build stays as it is.")
        } else {
            ForEach(queue, id: \.projectId) { queuedRow($0) }
            if mods.kind == .mod {
                ForEach(mods.installed) { installedRow($0) }
                if mods.installed.isEmpty, queue.isEmpty { buildNote("Nothing here yet. Add the first one from the right.") }
            } else {
                let records = mods.contentRecords.filter { $0.kind == mods.kind }
                ForEach(records, id: \.fileName) { contentRow($0) }
                if records.isEmpty, queue.isEmpty { buildNote("Nothing here yet. Add the first one from the right.") }
            }
        }
    }

    private func buildNote(_ key: String) -> some View {
        Text(tr: key)
            .style(.init(size: 14, color: Theme.textSecondary, lineSpacing: 4))
            .padding(.horizontal, 18)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildRow<Trailing: View>(
        iconURL: URL?,
        title: String,
        subtitle: String,
        subtitleColor: Color = Theme.textSecondary,
        isDimmed: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            ModIcon(url: iconURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).style(.init(size: 14, weight: .semibold)).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(verbatim: subtitle).style(.init(size: 12, color: subtitleColor)).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .opacity(isDimmed ? 0.55 : 1)
        .overlay(alignment: .top) { hairline }
    }

    private func queuedRow(_ hit: ModrinthHit) -> some View {
        buildRow(iconURL: hit.iconURL, title: hit.title, subtitle: L("Waiting to install"), subtitleColor: Theme.ember) {
            roundButton("×", isActive: true, label: "Remove from selection") { queue.removeAll { $0.projectId == hit.projectId } }
        }
    }

    private func confirmRow(_ title: String, iconURL: URL?, onConfirm: @escaping () -> Void) -> some View {
        buildRow(iconURL: iconURL, title: L("Move %@ to the Trash?", title), subtitle: "") {
            HStack(spacing: 6) {
                ModActionButton(title: "Move to Trash") {
                    confirmingRemove = nil
                    onConfirm()
                }
                .frame(width: 112)
                ModActionButton(title: "Keep it", kind: .text) { confirmingRemove = nil }
                    .frame(width: 70)
            }
        }
    }

    private func removeButton(_ fileName: String) -> some View {
        Button { confirmingRemove = fileName } label: {
            Text(verbatim: "×").style(.init(size: 18, weight: .medium, color: Theme.textMuted))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Remove"))
    }

    private func installedRow(_ mod: InstalledMod) -> some View {
        if confirmingRemove == mod.fileName {
            return AnyView(confirmRow(mod.displayTitle, iconURL: mod.record?.iconURL) { mods.remove(mod) })
        }
        let update = mods.updates.first { $0.record.fileName == mod.fileName }
        var subtitle = mod.record?.versionNumber ?? ""
        if mod.record?.isDependency == true, let owner = mod.record?.installedFor { subtitle = L("Dependency of %@", owner) }
        if subtitle == mod.displayTitle { subtitle = "" }
        let toggle = Binding(get: { mod.isEnabled }, set: { mods.setEnabled(mod, $0) })
        return AnyView(buildRow(
            iconURL: mod.record?.iconURL,
            title: mod.displayTitle,
            subtitle: subtitle,
            isDimmed: mods.busy.contains(mod.fileName) || !mod.isEnabled
        ) {
            if let update {
                ModActionButton(title: "Update") { Task { await mods.apply(update) } }.frame(width: 76)
            }
            EmberToggle(label: "Enable", isOn: toggle)
            removeButton(mod.fileName)
        })
    }

    private func contentRow(_ record: ContentRecord) -> some View {
        if confirmingRemove == record.fileName {
            return AnyView(confirmRow(record.title, iconURL: record.iconURL) { mods.remove(record) })
        }
        return AnyView(buildRow(
            iconURL: record.iconURL,
            title: record.title,
            subtitle: record.versionNumber,
            isDimmed: mods.busy.contains(record.fileName)
        ) {
            removeButton(record.fileName)
        })
    }

    // MARK: - Basket

    private var basketBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: L("%d selected", queue.count)).style(.init(size: 14, weight: .semibold))
                Text(verbatim: queue.map(\.title).joined(separator: ", "))
                    .style(.init(size: 12, color: Theme.textSecondary)).lineLimit(1)
            }
            Spacer(minLength: 12)
            SecondaryPill(title: "Clear", height: 36) { queue = [] }
            PrimaryPill(
                title: isInstallingQueue ? "Installing…" : L("Install %d", queue.count),
                height: 36,
                horizontalPadding: 22,
                isDisabled: isInstallingQueue
            ) { installQueue() }
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .background(Color(hex: 0x1b191b))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
    }

    private func installQueue() {
        let items = queue
        let kind = mods.kind
        isInstallingQueue = true
        Task {
            for hit in items {
                if kind == .mod { await mods.install(hit) } else { await mods.installContent(hit) }
                queue.removeAll { $0.projectId == hit.projectId }
            }
            isInstallingQueue = false
        }
    }

    // MARK: - Find

    @ViewBuilder
    private var findPanel: some View {
        if mods.kind == .modpack, mods.previewHit != nil {
            panel { ModpackPreviewPanel(mods: mods) }
        } else {
            browsePanel
        }
    }

    private var browsePanel: some View {
        panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(tr: "Find on Modrinth").style(.init(size: 16, weight: .semibold))
                    Spacer(minLength: 16)
                    if mods.totalHits > 0 {
                        Text(verbatim: L("%d results", mods.totalHits)).style(.init(size: 12, color: Theme.textMuted))
                    }
                    if mods.hiddenCount > 0 {
                        Text(verbatim: L("%d hidden", mods.hiddenCount)).style(.init(size: 12, color: Theme.textMuted))
                    }
                    if mods.kind == .modpack {
                        modpackLoaderMenu
                        modpackVersionMenu
                    }
                }
                HStack(spacing: 10) {
                    SearchField(placeholder: searchPlaceholder, text: $query, compact: true)
                    Spacer(minLength: 8)
                    sortMenu
                    FilterChip(title: "Show incompatible", isActive: mods.showIncompatible, compact: true, outlined: true) { mods.showIncompatible.toggle() }
                }
                if !mods.needsFabric, !mods.kind.browseCategories.isEmpty { categoryChips }
            }
            .padding(18)
            hairline
            ScrollView {
                if mods.canBrowse { browseList.padding(.bottom, queue.isEmpty ? 6 : 90) }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !mods.categories.isEmpty { clearCategoriesButton }
                ForEach(mods.kind.browseGroups, id: \.id) { group in
                    FilterChip(
                        title: mods.kind == .mod || mods.kind == .modpack ? L(group.title) : Self.prettifyCategory(group.id),
                        isActive: mods.categories.contains(group.id),
                        compact: true,
                        outlined: true
                    ) {
                        if mods.categories.contains(group.id) {
                            mods.categories.remove(group.id)
                        } else {
                            mods.categories.insert(group.id)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var clearCategoriesButton: some View {
        Button { mods.categories.removeAll() } label: {
            CloseIcon()
                .stroke(Theme.textSecondary, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .frame(width: 12, height: 12)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.elevated))
                .overlay(Circle().strokeBorder(Theme.lineStrong, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(PressDimStyle())
        .accessibilityLabel(L("Clear"))
        .help(L("Clear"))
    }

    private var sortMenu: some View {
        let value = mods.sort?.title ?? "Best match"
        return EmberMenu(label: "Sort", value: L(value), listWidth: 200, alignTrailing: true, compact: true) {
            Button(L("Best match")) { mods.sort = nil }
            ForEach(BrowseSort.allCases, id: \.rawValue) { sort in
                Button(L(sort.title)) { mods.sort = sort }
            }
        }
    }

    /// "Fabric, NeoForge": the installable loaders a modpack lists among its categories.
    static func packLoaderNames(_ hit: ModrinthHit) -> String {
        ContentInstaller.packLoaders
            .filter { hit.categories.contains($0) }
            .map { LoaderKind(coreName: $0).rawValue }
            .joined(separator: ", ")
    }

    /// Modrinth lists loaders among a project's categories; they say nothing about what the mod does.
    static let loaderSlugs: Set<String> = [
        "fabric", "forge", "neoforge", "quilt", "liteloader", "modloader", "rift",
        "bukkit", "spigot", "paper", "purpur", "sponge", "folia", "bungeecord", "waterfall", "velocity",
    ]

    static func prettifyCategory(_ slug: String) -> String {
        if slug.hasSuffix("-") { return slug }
        let spaced = slug.replacingOccurrences(of: "-", with: " ")
        guard let first = spaced.first else { return slug }
        return first.uppercased() + String(spaced.dropFirst())
    }

    private var modpackLoaderMenu: some View {
        let value = mods.modpackLoader.map { LoaderKind(coreName: $0).rawValue } ?? L("Any loader")
        return EmberMenu(label: "Loader", value: value, minWidth: 130) {
            Button(L("Any loader")) { mods.modpackLoader = nil }
            ForEach(ContentInstaller.packLoaders, id: \.self) { loader in
                Button(LoaderKind(coreName: loader).rawValue) { mods.modpackLoader = loader }
            }
        }
    }

    private var modpackVersionMenu: some View {
        let choice = mods.modpackVersionChoice
        let value = choice == ModsController.anyVersion ? L("Any version") : (mods.modpackGameVersion ?? L("Any version"))
        return EmberMenu(label: "Minecraft version", value: value, minWidth: 150) {
            Button(L("Current instance")) { mods.modpackVersionChoice = nil }
            Button(L("Any version")) { mods.modpackVersionChoice = ModsController.anyVersion }
            ForEach(app.launchableVersions(includeSnapshots: false).prefix(40), id: \.id) { entry in
                Button(entry.id) { mods.modpackVersionChoice = entry.id }
            }
        }
    }

    /// Modpacks with no search text and no category: the hand-picked list goes first.
    private var showsBigBuilds: Bool {
        mods.kind == .modpack && query.isEmpty && mods.categories.isEmpty && !mods.featured.isEmpty
    }

    private var browseList: some View {
        let shown = mods.visibleResults
        return LazyVStack(alignment: .leading, spacing: 0) {
            if shown.isEmpty, mods.isChecking {
                Text(tr: "Checking compatibility…").style(.body16).frame(maxWidth: .infinity).padding(.top, 50)
            } else if shown.isEmpty, !mods.isSearching {
                Text(tr: mods.hiddenCount > 0 ? "Nothing fits this instance. Turn on Show incompatible to see the rest." : "Nothing found.")
                    .style(.body16).frame(maxWidth: .infinity).padding(.top, 50)
            }
            if showsBigBuilds {
                browseHeading("Big builds")
                ForEach(mods.featured, id: \.projectId) { browseRow($0) }
                browseHeading("All modpacks")
                ForEach(shown.filter { hit in !mods.featured.contains { $0.projectId == hit.projectId } }, id: \.projectId) { browseRow($0) }
            } else {
                ForEach(shown, id: \.projectId) { browseRow($0) }
            }
            if mods.isLoadingMore || (!mods.isSearching && mods.canLoadMore) {
                HStack {
                    Spacer()
                    if mods.isLoadingMore {
                        ProgressView()
                            .controlSize(.small)
                    } else if mods.canLoadMore {
                        SecondaryPill(title: "Load more") {
                            Task { await mods.loadMore(query: query) }
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

                Color.clear
                    .frame(height: 1)
                    .id(mods.results.count)
                    .onAppear {
                        if !mods.isSearching {
                            Task { await mods.loadMore(query: query) }
                        }
                    }
            }
        }
        .opacity(mods.isSearching ? 0.6 : 1)
    }

    private func browseHeading(_ key: String) -> some View {
        Text(tr: key)
            .style(.init(size: 14, weight: .semibold, color: Theme.textSecondary))
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func browseRow(_ hit: ModrinthHit) -> some View {
        let kind = mods.kind
        let isInstalled: Bool
        let note: (text: String, isWarning: Bool)?
        let canInstall: Bool
        if mods.needsFabric {
            isInstalled = false
            note = (L("Needs Fabric"), true)
            canInstall = false
        } else if kind == .mod {
            isInstalled = mods.installedProjectIDs.contains(hit.projectId)
            note = Self.compatNote(mods.compat[hit.projectId])
            canInstall = Self.canInstall(mods.compat[hit.projectId])
        } else {
            isInstalled = kind != .modpack && mods.contentProjectIDs.contains(hit.projectId)
            note = Self.contentNote(mods.contentCompat[hit.projectId])
            canInstall = Self.canInstall(content: mods.contentCompat[hit.projectId])
        }
        let isBusy = mods.busy.contains(hit.projectId)
        let isQueued = queue.contains { $0.projectId == hit.projectId }
        return HStack(spacing: 12) {
            ModIcon(url: hit.iconURL)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(verbatim: hit.title).style(.init(size: 14, weight: .semibold)).lineLimit(1)
                    Text(verbatim: hit.author).style(.init(size: 12, color: Theme.textMuted)).lineLimit(1)
                }
                Text(verbatim: hit.description).style(.init(size: 13, color: Theme.textSecondary)).lineLimit(1)
                let loaderNames = kind == .modpack ? Self.packLoaderNames(hit) : ""
                if (note != nil && !isInstalled) || !loaderNames.isEmpty {
                    HStack(spacing: 6) {
                        if let note, !isInstalled {
                            Text(verbatim: note.text)
                                .style(.init(size: 12, color: note.isWarning ? Theme.danger : Theme.success))
                                .lineLimit(1)
                        }
                        if !loaderNames.isEmpty {
                            Text(verbatim: (note != nil && !isInstalled ? "· " : "") + loaderNames)
                                .style(.init(size: 12, color: Theme.textMuted))
                                .lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Text(verbatim: "↓ " + Self.short(hit.downloads)).style(.init(size: 12, color: Theme.textMuted))
            if kind == .modpack {
                ModActionButton(title: isBusy ? "Installing…" : "Install", isDisabled: isBusy || !canInstall) {
                    Task { await mods.installContent(hit) }
                }
                .frame(width: 96)
            } else if isInstalled {
                roundButton("✓", isActive: true, isDisabled: true, label: "Installed") {}
            } else if isQueued {
                roundButton("✓", isActive: true, label: "Remove from selection") { queue.removeAll { $0.projectId == hit.projectId } }
            } else {
                roundButton("+", isDisabled: !canInstall || isBusy, label: "Add to selection") { queue.append(hit) }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .opacity(canInstall || isInstalled || mods.needsFabric ? 1 : 0.55)
        .overlay(alignment: .top) { hairline }
        .contentShape(Rectangle())
        .onTapGesture {
            if kind == .modpack { Task { await mods.openPreview(hit) } } else { app.modal = .modProject(hit) }
        }
    }

    /// The line under the download count; nothing while the check is still running or failed.
    static func compatNote(_ value: ModCompatibility?) -> (text: String, isWarning: Bool)? {
        switch value {
        case .ready: return (L("Compatible"), false)
        case .needs(let count): return (L("Compatible · +%@ required", String(count)), false)
        case .conflict(let title): return (L("Conflicts with %@", title), true)
        case .unavailable: return (L("No release for this version"), true)
        case .unknown, nil: return nil
        }
    }

    static func canInstall(_ value: ModCompatibility?) -> Bool {
        switch value {
        case .conflict, .unavailable: return false
        default: return true
        }
    }

    /// What `ContentInstaller.compatibility` answers for a shader when Iris is not installed yet; Install then adds Iris first.
    private static let needsShaderLoader = "needsShaderLoader"

    static func contentNote(_ value: ContentCompatibility?) -> (text: String, isWarning: Bool)? {
        switch value {
        case .ready: return (L("Compatible"), false)
        case .needsOther(let text) where text == needsShaderLoader: return (L("Compatible · Iris is added"), false)
        case .needsOther(let text): return (L(text), true)
        case .noRelease: return (L("No release for this version"), true)
        case nil: return nil
        }
    }

    static func canInstall(content value: ContentCompatibility?) -> Bool {
        switch value {
        case .needsOther(let text): return text == needsShaderLoader
        case .noRelease: return false
        default: return true
        }
    }

    /// 1234 → "1.2K", 1_500_000 → "1.5M".
    static func short(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...: return String(format: "%.0fK", Double(n) / 1_000)
        default: return "\(n)"
        }
    }
}

/// 36 pt rounded square with the mod's icon, or an empty frame while it loads or when there is none.
struct ModIcon: View {
    let url: URL?

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Theme.white04)
            .frame(width: 36, height: 36)
            .overlay {
                if let url {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
    }
}
