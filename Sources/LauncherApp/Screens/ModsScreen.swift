import LauncherCore
import SwiftUI

/// Mods of the current instance: what is installed, and a Modrinth search to add more.
struct ModsScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var mods: ModsController
    @Local private var tab = ModsTab.installed
    @Local private var query = ""
    @Local private var confirmingRemove: String?
    @Local private var confirmingRemoveContent: String?
    @Local private var searchTask: Task<Void, Never>?

    init(app: AppState) {
        _mods = StateObject(wrappedValue: ModsController(app: app))
    }

    enum ModsTab: String {
        case installed = "Installed"
        case browse = "Browse"
    }

    /// The kind Browse is on; the Installed tab always talks about mods.
    private var activeKind: ContentKind { tab == .browse ? mods.kind : .mod }

    private var subtitle: String {
        if activeKind == .modpack { return "Creates a new instance from a Modrinth pack." }
        guard let current = app.current else { return "Pick an instance in Library first." }
        switch activeKind {
        case .shader:
            guard !mods.needsFabric else { return "Shaders need a Fabric instance." }
            return L("For %@ · %@ · Fabric + Iris", current.name, current.minecraftVersion)
        case .resourcepack:
            return L("For %@ · %@", current.name, current.minecraftVersion)
        default:
            guard mods.canInstall else { return "Mods need a Fabric instance." }
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
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geo in
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(eyebrow: "Discover", title: "Mods", subtitle: subtitle, alignment: .leading)

                    HStack(spacing: 8) {
                        ForEach([ModsTab.installed, .browse], id: \.rawValue) { item in
                            FilterChip(title: item.rawValue, isActive: tab == item, compact: true) { tab = item }
                        }
                        Spacer(minLength: 16)
                        if tab == .browse {
                            SearchField(placeholder: searchPlaceholder, text: $query, compact: true)
                        }
                    }
                    .padding(.top, 14)

                    if tab == .browse {
                        HStack(spacing: 10) {
                            ForEach(ContentKind.allCases, id: \.rawValue) { item in
                                FilterChip(title: Self.title(of: item), isActive: mods.kind == item, compact: true) { mods.kind = item }
                            }
                            Spacer(minLength: 16)
                            if mods.totalHits > 0 {
                                Text(verbatim: L("%d results", mods.totalHits))
                                    .style(.init(size: 10, color: Color(hex: 0x68645e)))
                            }
                            if mods.hiddenCount > 0 {
                                Text(verbatim: L("%d hidden", mods.hiddenCount))
                                    .style(.init(size: 10, color: Color(hex: 0x68645e)))
                            }
                            if mods.kind == .modpack { modpackVersionMenu }
                            sortMenu
                            FilterChip(title: "Show incompatible", isActive: mods.showIncompatible, compact: true) { mods.showIncompatible.toggle() }
                        }
                        .padding(.top, 2)

                        if !mods.needsFabric, !mods.kind.browseCategories.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if !mods.categories.isEmpty {
                                        FilterChip(title: "Clear", isActive: false, compact: true) {
                                            mods.categories.removeAll()
                                        }
                                    }
                                    ForEach(mods.kind.browseCategories, id: \.self) { cat in
                                        FilterChip(
                                            title: Self.prettifyCategory(cat),
                                            isActive: mods.categories.contains(cat),
                                            compact: true
                                        ) {
                                            if mods.categories.contains(cat) {
                                                mods.categories.remove(cat)
                                            } else {
                                                mods.categories.insert(cat)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 3)
                            }
                            .padding(.bottom, 4)
                        }
                    }

                    if tab == .browse, mods.needsFabric {
                        HStack(spacing: 14) {
                            Text(tr: mods.kind == .shader ? "Shaders need a Fabric instance." : "Mods need a Fabric instance.")
                                .style(.secondary)
                            if mods.canSwitchToFabric {
                                SecondaryPill(title: "Switch to Fabric") { Task { await mods.switchToFabric() } }
                            }
                        }
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
                    }

                    ScrollView {
                        VStack(spacing: 0) {
                            if tab == .installed {
                                if app.current == nil {
                                    Color.clear.frame(height: 1)
                                } else {
                                    installedList
                                }
                            } else if mods.canBrowse {
                                browseList
                            } else {
                                Color.clear.frame(height: 1)
                            }
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 24)
                    }
                    .mask(
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: 18)
                            Rectangle().fill(Color.black)
                        }
                    )
                }
                .frame(width: min(1120, geo.size.width - 56), alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 28)
        .onAppear {
            app.activeMods = mods
            mods.reload()
        }
        .onChange(of: app.currentID) { _, _ in
            mods.reload()
            runSearch(delay: 0)
        }
        .onChange(of: query) { _, _ in runSearch(delay: 350) }
        .onChange(of: mods.kind) { _, _ in runSearch(delay: 0) }
        .onChange(of: mods.sort) { _, _ in runSearch(delay: 0) }
        .onChange(of: mods.categories) { _, _ in runSearch(delay: 0) }
        .onChange(of: mods.modpackVersionChoice) { _, _ in runSearch(delay: 0) }
        .onChange(of: tab) { _, value in
            if value == .browse, mods.results.isEmpty { runSearch(delay: 0) }
        }
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
        guard tab == .browse else { return }
        let text = query
        searchTask = Task {
            if delay > 0 { try? await Task.sleep(for: .milliseconds(delay)) }
            guard !Task.isCancelled else { return }
            await mods.search(query: text)
        }
    }

    // MARK: - Installed

    private var installedList: some View {
        VStack(alignment: .leading, spacing: 28) {
            if mods.canInstall {
                modsSection
            }
            if !mods.contentRecords.isEmpty {
                contentSection
            }
        }
        .padding(.vertical, 24)
    }

    private var modsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(verbatim: L("%d mods", mods.installed.count)).style(.eyebrow)
                Spacer(minLength: 16)
                SecondaryPill(title: mods.isCheckingUpdates ? "Checking…" : "Check for updates") {
                    Task { await mods.checkUpdates() }
                }
                if !mods.updates.isEmpty {
                    PrimaryPill(title: L("Update all (%d)", mods.updates.count), height: 36, horizontalPadding: 22) {
                        Task { await mods.applyAll() }
                    }
                }
            }
            .padding(.bottom, 4)

            if mods.installed.isEmpty {
                Text(tr: "No mods yet. Open Browse to add some.")
                    .style(.body16)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
            }
            cardGrid(mods.installed) { installedCard($0) }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr: "Shaders & resource packs").style(.eyebrow).padding(.bottom, 4)
            cardGrid(mods.contentRecords) { contentCard($0) }
        }
    }

    /// Two cards per row so both stretch to the taller one, like the prototype's CSS grid.
    private func cardGrid<Item, Card: View>(_ items: [Item], @ViewBuilder card: @escaping (Item) -> Card) -> some View {
        ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { start in
            HStack(alignment: .top, spacing: 12) {
                card(items[start])
                if start + 1 < items.count {
                    card(items[start + 1])
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    static func paletteIndex(_ seed: String) -> Int {
        Int(seed.utf8.reduce(0) { ($0 &* 31 &+ UInt32($1)) % 1000 })
    }

    private func contentCard(_ record: ContentRecord) -> some View {
        let isBusy = mods.busy.contains(record.fileName)
        let isConfirming = confirmingRemoveContent == record.fileName
        return ModCard(
            iconURL: record.iconURL,
            paletteIndex: Self.paletteIndex(record.projectId),
            category: L(record.kind == .shader ? "Shader" : "Resource pack").uppercased(),
            title: record.title,
            summary: record.fileName,
            footnote: record.versionNumber,
            note: isConfirming ? (L("Move %@ to the Trash?", record.title), true) : nil,
            isDimmed: isBusy
        ) {
            if isConfirming {
                ModActionButton(title: "Move to Trash") {
                    confirmingRemoveContent = nil
                    mods.remove(record)
                }
                ModActionButton(title: "Keep it", kind: .text) { confirmingRemoveContent = nil }
            } else {
                ModActionButton(title: "Remove", kind: .text) { confirmingRemoveContent = record.fileName }
            }
        }
    }

    private func installedCard(_ mod: InstalledMod) -> some View {
        let update = mods.updates.first { $0.record.fileName == mod.fileName }
        let isBusy = mods.busy.contains(mod.fileName)
        let isConfirming = confirmingRemove == mod.fileName
        let isDependency = mod.record?.isDependency == true
        let category = !mod.isEnabled ? L("Off") : (isDependency ? L("Dependency") : L("Mod"))
        var summary = mod.fileName == mod.displayTitle + ".jar" ? "" : mod.fileName
        if isDependency, let owner = mod.record?.installedFor { summary = L("Dependency of %@", owner) }
        let version = mod.record?.versionNumber ?? ""
        return ModCard(
            iconURL: mod.record?.iconURL,
            paletteIndex: Self.paletteIndex(mod.record?.projectId ?? mod.fileName),
            category: category.uppercased(),
            title: mod.displayTitle,
            summary: summary,
            footnote: version == mod.displayTitle ? "" : version,
            note: isConfirming ? (L("Move %@ to the Trash?", mod.displayTitle), true) : nil,
            isDimmed: isBusy || !mod.isEnabled
        ) {
            if isConfirming {
                ModActionButton(title: "Move to Trash") {
                    confirmingRemove = nil
                    mods.remove(mod)
                }
                ModActionButton(title: "Keep it", kind: .text) { confirmingRemove = nil }
            } else {
                if let update {
                    ModActionButton(title: "Update") { Task { await mods.apply(update) } }
                }
                ModActionButton(title: mod.isEnabled ? "Disable" : "Enable") { mods.setEnabled(mod, !mod.isEnabled) }
                ModActionButton(title: "Remove", kind: .text) { confirmingRemove = mod.fileName }
            }
        }
    }

    // MARK: - Browse

    private var sortMenu: some View {
        let value = mods.sort?.title ?? "Best match"
        return VoxelMenu(label: "Sort", value: L(value), compact: true) {
            Button(L("Best match")) { mods.sort = nil }
            ForEach(BrowseSort.allCases, id: \.rawValue) { sort in
                Button(L(sort.title)) { mods.sort = sort }
            }
        }
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

    private var modpackVersionMenu: some View {
        let choice = mods.modpackVersionChoice
        let value = choice == ModsController.anyVersion ? L("Any version") : (mods.modpackGameVersion ?? L("Any version"))
        return VoxelMenu(label: "Minecraft version", value: value, minWidth: 150) {
            Button(L("Current instance")) { mods.modpackVersionChoice = nil }
            Button(L("Any version")) { mods.modpackVersionChoice = ModsController.anyVersion }
            ForEach(app.launchableVersions(includeSnapshots: false).prefix(40), id: \.id) { entry in
                Button(entry.id) { mods.modpackVersionChoice = entry.id }
            }
        }
    }

    private var browseList: some View {
        let shown = mods.visibleResults
        return LazyVStack(alignment: .leading, spacing: 12) {
            if shown.isEmpty, mods.isChecking {
                Text(tr: "Checking compatibility…").style(.body16).frame(maxWidth: .infinity).padding(.top, 50)
            } else if shown.isEmpty, !mods.isSearching {
                Text(tr: mods.hiddenCount > 0 ? "Nothing fits this instance. Turn on Show incompatible to see the rest." : "Nothing found.")
                    .style(.body16).frame(maxWidth: .infinity).padding(.top, 50)
            }
            cardGrid(shown) { browseRow($0) }
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
                .padding(.vertical, 8)

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
        .padding(.vertical, 24)
        .opacity(mods.isSearching ? 0.6 : 1)
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
        let category: String
        if let first = hit.categories.first(where: { !Self.loaderSlugs.contains($0) }) {
            category = Self.prettifyCategory(first).uppercased()
        } else {
            category = Self.title(of: kind).uppercased()
        }
        return ModCard(
            iconURL: hit.iconURL,
            paletteIndex: Self.paletteIndex(hit.projectId),
            category: category,
            title: hit.title,
            summary: hit.description,
            footnote: "↓ " + L("%@ downloads", Self.short(hit.downloads)),
            note: isInstalled ? nil : note,
            isDimmed: !(canInstall || isInstalled || mods.needsFabric),
            onOpen: nil
        ) {
            ModActionButton(title: "Details", kind: .text) { app.modal = .modProject(hit) }
            if isInstalled {
                ModActionButton(title: "Installed", kind: .installed)
            } else {
                ModActionButton(title: isBusy ? "Installing…" : "Install", isDisabled: isBusy || !canInstall) {
                    Task { if kind == .mod { await mods.install(hit) } else { await mods.installContent(hit) } }
                }
            }
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
private struct ModIcon: View {
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line, lineWidth: 1))
    }
}
