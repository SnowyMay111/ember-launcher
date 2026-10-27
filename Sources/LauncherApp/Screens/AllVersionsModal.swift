import LauncherCore
import SwiftUI

/// Every version Mojang lists, each one a click away from a Vanilla instance with the game already downloaded.
struct AllVersionsModal: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayController

    @Local private var query = ""
    @Local private var kinds: Set<VersionKind> = [.release]
    @Local private var confirmingDelete: String?
    @Local private var noteOpen = false

    private static let kindChips: [(kind: VersionKind, title: String)] = [
        (.release, "Releases"), (.snapshot, "Snapshots"), (.beta, "Beta"), (.alpha, "Alpha"),
    ]

    /// 1.13 is where the launcher stops being able to treat a version like the current ones.
    private static let fallbackCutoff = "2018-07-18T08:58:32+00:00"

    private static let isoParser = ISO8601DateFormatter()
    private static let dayFormat: DateFormatter = {
        let format = DateFormatter()
        format.dateStyle = .medium
        format.timeStyle = .none
        return format
    }()

    private var versions: [ManifestVersion] {
        guard let manifest = app.manifest else { return [] }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return VersionCatalog.launchable(manifest, includeSnapshots: true, includeOld: true).filter { version in
            kinds.contains(VersionCatalog.kind(for: version))
                && (text.isEmpty || version.id.range(of: text, options: .caseInsensitive) != nil)
        }
    }

    var body: some View {
        let list = versions
        let existing = Set(app.instances.map(\.name))
        let cutoff = app.manifest?.versions.first { $0.id == "1.13" }?.releaseTime ?? Self.fallbackCutoff
        return VoxelModal(title: "All versions", width: 640) {
            VStack(alignment: .leading, spacing: 16) {
                SearchField(placeholder: "Search versions", text: $query)

                HStack(spacing: 8) {
                    ForEach(Self.kindChips, id: \.kind) { chip in
                        FilterChip(title: chip.title, isActive: kinds.contains(chip.kind)) { toggle(chip.kind) }
                    }
                }

                if player.isBusy {
                    Text(tr: "Close the game first.").style(.secondary)
                }
                if app.manifest == nil {
                    Text(tr: "Couldn't load the version list. Check your connection.").style(.secondary)
                } else if list.isEmpty {
                    Text(tr: "Nothing found.").style(.secondary)
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(list, id: \.id) { version in
                            row(version, existing: existing, cutoff: cutoff)
                        }
                    }
                }
                .frame(height: 360)

                if list.contains(where: { Self.isOld($0, cutoff: cutoff) }) {
                    oldVersionsNote
                }
            }
        } footer: {
            ModalCancel(title: "Close")
        }
        .task { if app.manifest == nil { await app.loadManifest() } }
    }

    /// One folded note under the list instead of a warning on every old row.
    private var oldVersionsNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { noteOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(tr: "Old versions").style(.eyebrow)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.muted)
                        .rotationEffect(.degrees(noteOpen ? 180 : 0))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if noteOpen {
                Text(tr: "Old versions may run slowly or not at all.").style(.secondary)
                    .transition(.opacity)
            }
        }
    }

    private func toggle(_ kind: VersionKind) {
        if kinds.contains(kind) { kinds.remove(kind) } else { kinds.insert(kind) }
    }

    private func row(_ version: ManifestVersion, existing: Set<String>, cutoff: String) -> some View {
        let id = version.id
        let name = AppState.vanillaName(for: id)
        let percent = app.downloads[id]
        let error = app.downloadErrors[id]
        let hasInstance = existing.contains(name)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 10) {
                        Text(verbatim: id).style(.row).lineLimit(1)
                        Text(tr: Self.kindTitle(VersionCatalog.kind(for: version))).style(.eyebrow)
                    }
                    Text(verbatim: Self.dateText(version.releaseTime)).style(.secondary).lineLimit(1)
                }
                Spacer(minLength: 12)
                if let percent {
                    PrimaryPill(title: L("Downloading… %d%%", percent), height: 36, horizontalPadding: 22, isDisabled: true)
                } else {
                    if app.isDownloaded(id) {
                        SecondaryPill(title: "Delete files") { confirmingDelete = id }
                    }
                    if hasInstance, error == nil {
                        if app.isDownloaded(id) {
                            Text(tr: "Installed").style(.eyebrow)
                        }
                        SecondaryPill(title: "Open") { open(name) }
                    } else {
                        PrimaryPill(title: error == nil ? "Install" : "Retry", height: 36, horizontalPadding: 22, isDisabled: player.isBusy) {
                            app.installVersion(id, memoryMB: Int(settings.memoryGB) * 1024)
                        }
                    }
                }
            }
            if confirmingDelete == id {
                let users = app.usersOfVersion(id)
                VStack(alignment: .leading, spacing: 8) {
                    if !users.isEmpty {
                        Text(verbatim: L("Used by: %@. Delete those instances first.", users.joined(separator: ", ")))
                            .style(.init(size: 13, weight: .regular, color: Theme.text))
                        HStack(spacing: 10) {
                            SecondaryPill(title: "OK") { confirmingDelete = nil }
                        }
                    } else {
                        Text(verbatim: L("Delete Minecraft %@ from disk? Libraries and assets shared with other versions stay.", id))
                            .style(.init(size: 13, weight: .regular, color: Theme.text))
                        HStack(spacing: 10) {
                            SecondaryPill(title: "Keep it") { confirmingDelete = nil }
                            PrimaryPill(title: "Delete files") {
                                do {
                                    try app.deleteVersion(id)
                                    app.downloadErrors[id] = nil
                                    confirmingDelete = nil
                                } catch {
                                    app.downloadErrors[id] = error.localizedDescription
                                    confirmingDelete = nil
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            if let error {
                Text(verbatim: error).style(.secondary).lineLimit(3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radiusInput).fill(Theme.white04))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func open(_ name: String) {
        app.currentID = name
        app.screen = .play
        app.modal = nil
    }

    private static func kindTitle(_ kind: VersionKind) -> String {
        switch kind {
        case .release: return "Release"
        case .snapshot: return "Snapshot"
        case .beta: return "Beta"
        case .alpha: return "Alpha"
        }
    }

    /// Beta and alpha, and everything released before 1.13.
    private static func isOld(_ version: ManifestVersion, cutoff: String) -> Bool {
        switch VersionCatalog.kind(for: version) {
        case .beta, .alpha: return true
        case .release, .snapshot: return (version.releaseTime ?? "") < cutoff
        }
    }

    private static func dateText(_ releaseTime: String?) -> String {
        guard let releaseTime else { return "" }
        guard let date = isoParser.date(from: releaseTime) else { return String(releaseTime.prefix(10)) }
        return dayFormat.string(from: date)
    }
}
