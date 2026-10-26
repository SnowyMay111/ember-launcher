import LauncherCore
import SwiftUI

/// Mods of the current instance: what is installed, and a Modrinth search to add more.
struct ModsScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var mods: ModsController
    @Local private var tab = ModsTab.installed
    @Local private var query = ""
    @Local private var confirmingRemove: String?
    @Local private var searchTask: Task<Void, Never>?

    init(app: AppState) {
        _mods = StateObject(wrappedValue: ModsController(app: app))
    }

    enum ModsTab: String {
        case installed = "Installed"
        case browse = "Browse"
    }

    private var subtitle: String {
        guard let current = app.current else { return "Pick an instance in Library first." }
        guard mods.canInstall else { return "Mods need a Fabric instance." }
        return L("For %@ · %@ · Fabric", current.name, current.minecraftVersion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(eyebrow: "Mods", title: "Mods", subtitle: subtitle, alignment: .leading)
                .padding(.horizontal, 40)

            HStack(spacing: 8) {
                ForEach([ModsTab.installed, .browse], id: \.rawValue) { item in
                    FilterChip(title: item.rawValue, isActive: tab == item) { tab = item }
                }
                Spacer(minLength: 16)
                if tab == .browse {
                    SearchField(placeholder: "Search Modrinth", text: $query)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 22)

            if let message = mods.message {
                HStack(spacing: 10) {
                    Text(verbatim: message).style(.secondary).lineLimit(2)
                    Button { mods.message = nil } label: {
                        Text(verbatim: "×").style(.init(size: 16, weight: .medium, color: Theme.muted))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Dismiss"))
                }
                .padding(.horizontal, 40)
                .padding(.top, 14)
            }

            ScrollView {
                if app.current == nil || !mods.canInstall {
                    Color.clear.frame(height: 1)
                } else if tab == .installed {
                    installedList
                } else {
                    browseList
                }
            }
        }
        .padding(.top, 28)
        .onAppear { mods.reload() }
        .onChange(of: app.currentID) { _, _ in
            mods.reload()
            runSearch(delay: 0)
        }
        .onChange(of: query) { _, _ in runSearch(delay: 350) }
        .onChange(of: tab) { _, value in
            if value == .browse, mods.results.isEmpty { runSearch(delay: 0) }
        }
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
        VStack(alignment: .leading, spacing: 10) {
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
            ForEach(mods.installed) { mod in
                installedRow(mod)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
    }

    private func installedRow(_ mod: InstalledMod) -> some View {
        let update = mods.updates.first { $0.record.fileName == mod.fileName }
        let isBusy = mods.busy.contains(mod.fileName)
        return HStack(spacing: 14) {
            ModIcon(url: mod.record?.iconURL)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: mod.displayTitle).style(.row).lineLimit(1)
                Text(verbatim: detail(of: mod)).style(.secondary).lineLimit(1)
            }
            Spacer(minLength: 12)
            if confirmingRemove == mod.fileName {
                Text(verbatim: L("Move %@ to the Trash?", mod.displayTitle)).style(.secondary).lineLimit(1)
                SecondaryPill(title: "Keep it") { confirmingRemove = nil }
                PrimaryPill(title: "Move to Trash", height: 36, horizontalPadding: 22) {
                    confirmingRemove = nil
                    mods.remove(mod)
                }
            } else {
                if let update {
                    SecondaryPill(title: "Update") { Task { await mods.apply(update) } }
                }
                VoxelToggle(label: mod.displayTitle, isOn: Binding(
                    get: { mod.isEnabled },
                    set: { mods.setEnabled(mod, $0) }
                ))
                Button { confirmingRemove = mod.fileName } label: {
                    Text(verbatim: "×").style(.init(size: 20, weight: .regular, color: Theme.muted))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Remove"))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.radiusInput).fill(Theme.white04))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput).strokeBorder(Theme.line, lineWidth: 1))
        .opacity(isBusy ? 0.5 : 1)
    }

    private func detail(of mod: InstalledMod) -> String {
        var parts: [String] = []
        if let version = mod.record?.versionNumber, !version.isEmpty { parts.append(version) }
        if let owner = mod.record?.installedFor, mod.record?.isDependency == true {
            parts.append(L("Dependency of %@", owner))
        }
        if !mod.isEnabled { parts.append(L("Off")) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Browse

    private var browseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mods.results.isEmpty, !mods.isSearching {
                Text(tr: "Nothing found.").style(.body16).frame(maxWidth: .infinity).padding(.top, 50)
            }
            ForEach(mods.results, id: \.projectId) { hit in
                browseRow(hit)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
        .opacity(mods.isSearching ? 0.6 : 1)
    }

    private func browseRow(_ hit: ModrinthHit) -> some View {
        let isInstalled = mods.installedProjectIDs.contains(hit.projectId)
        let isBusy = mods.busy.contains(hit.projectId)
        return HStack(spacing: 14) {
            ModIcon(url: hit.iconURL)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(verbatim: hit.title).style(.row).lineLimit(1)
                    Text(verbatim: hit.author).style(.secondary).lineLimit(1)
                }
                Text(verbatim: hit.description).style(.secondary).lineLimit(2)
            }
            Spacer(minLength: 12)
            Text(verbatim: L("%@ downloads", Self.short(hit.downloads))).style(.eyebrow)
            if isInstalled {
                SecondaryPill(title: "Installed")
                    .allowsHitTesting(false)
                    .opacity(0.6)
            } else {
                PrimaryPill(title: isBusy ? "Installing…" : "Install", height: 36, horizontalPadding: 22, isDisabled: isBusy) {
                    Task { await mods.install(hit) }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.radiusInput).fill(Theme.white04))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput).strokeBorder(Theme.line, lineWidth: 1))
    }

    /// 1234 → "1.2K", 1_500_000 → "1.5M".
    private static func short(_ n: Int) -> String {
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
