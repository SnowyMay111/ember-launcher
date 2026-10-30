import LauncherCore
import SwiftUI

struct ModpackPreviewPanel: View {
    @ObservedObject var mods: ModsController

    private var busy: Bool {
        mods.previewHit.map { mods.busy.contains($0.projectId) } ?? false
    }

    private var groupedEntries: [(ModpackPreviewKind, [ModpackPreviewEntry])] {
        guard let preview = mods.preview else { return [] }
        let order: [ModpackPreviewKind] = [.mod, .resourcePack, .shader, .other]
        return order.compactMap { kind in
            let entries = preview.entries.filter { $0.kind == kind }
            return entries.isEmpty ? nil : (kind, entries)
        }
    }

    private func heading(for kind: ModpackPreviewKind) -> String {
        switch kind {
        case .mod: return "Mods"
        case .resourcePack: return "Resource packs"
        case .shader: return "Shaders"
        case .other: return "Other files"
        }
    }

    private var byteFormatter: ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }

    private var hairline: some View {
        Rectangle().fill(Theme.border).frame(height: 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            hairline
            if mods.isLoadingPreview || mods.preview == nil {
                Spacer(minLength: 0)
                Text(tr: "Downloading the pack…").style(.init(size: 14, color: Theme.textSecondary))
                Spacer(minLength: 0)
            } else {
                if let warning = mods.dependencyWarning {
                    dependencyBanner(warning)
                }
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedEntries, id: \.0) { kind, entries in
                            Text(tr: heading(for: kind))
                                .style(.init(size: 13, weight: .semibold, color: Theme.textSecondary))
                                .padding(.horizontal, 18)
                                .padding(.top, 14)
                                .padding(.bottom, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(entries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
                bottomBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: { mods.closePreview() }) {
                    Text(verbatim: L("← Packs")).style(.init(size: 13, color: Theme.textSecondary))
                }
                .buttonStyle(.plain)
                Text(verbatim: mods.previewHit?.title ?? "")
                    .style(.init(size: 16, weight: .semibold))
                Text(verbatim: subtitle)
                    .style(.init(size: 13, color: Theme.textSecondary))
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            SecondaryPill(title: "Select all", height: 32) { mods.excludedPaths = [] }
            SecondaryPill(title: "Clear", height: 32) {
                mods.excludedPaths = Set(mods.preview?.entries.map(\.path) ?? [])
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var subtitle: String {
        guard let preview = mods.preview else { return "" }
        let summary = preview.summary
        let total = preview.entries.count
        let selected = mods.selectedEntryCount
        let bytes = byteFormatter.string(fromByteCount: mods.selectedEntryBytes)
        return L(
            "Minecraft %@ · %@ · %d/%d selected · %@",
            summary.minecraftVersion,
            summary.loader.capitalized,
            selected,
            total,
            bytes
        )
    }

    private func dependencyBanner(_ warning: ModsController.DependencyWarning) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: L("%@ is needed by %@.", warning.title, warning.dependents.joined(separator: ", ")))
                .style(.init(size: 13, color: Theme.danger))
            Spacer(minLength: 8)
            SecondaryPill(title: "Remove anyway", height: 28) { mods.confirmDependencyWarning() }
            SecondaryPill(title: "Keep", height: 28) { mods.dependencyWarning = nil }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Theme.elevated)
    }

    private func requiredByLine(_ entry: ModpackPreviewEntry) -> String? {
        guard !entry.requiredBy.isEmpty else { return nil }
        let shown = entry.requiredBy.prefix(2).joined(separator: ", ")
        let remaining = entry.requiredBy.count - 2
        let names = remaining > 0 ? "\(shown) +\(remaining)" : shown
        return L("Needed by %@", names)
    }

    private func entryRow(_ entry: ModpackPreviewEntry) -> some View {
        let selected = mods.isSelected(entry)
        return HStack(spacing: 12) {
            checkbox(selected: selected)
            ModIcon(url: entry.iconURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: entry.title).style(.init(size: 14, weight: .semibold)).lineLimit(1)
                if let summary = entry.summary {
                    Text(verbatim: summary).style(.init(size: 13, color: Theme.textSecondary)).lineLimit(1)
                }
                if let requiredByLine = requiredByLine(entry) {
                    Text(verbatim: requiredByLine).style(.init(size: 12, color: Theme.textMuted)).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(verbatim: byteFormatter.string(fromByteCount: entry.size))
                .style(.init(size: 12, color: Theme.textMuted))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .opacity(selected ? 1 : 0.5)
        .overlay(alignment: .top) { hairline }
        .contentShape(Rectangle())
        .onTapGesture { mods.toggle(entry) }
    }

    private func checkbox(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(selected ? Theme.success : Theme.white04)
            .overlay {
                if selected {
                    Text(verbatim: "✓").style(.init(size: 12, color: .white))
                } else {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.lineStrong, lineWidth: 1)
                }
            }
            .frame(width: 20, height: 20)
    }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            Text(verbatim: byteFormatter.string(fromByteCount: mods.selectedEntryBytes))
                .style(.init(size: 13, color: Theme.textSecondary))
            Spacer(minLength: 12)
            PrimaryPill(
                title: busy ? "Installing…" : L("Install %d of %d", mods.selectedEntryCount, mods.preview?.entries.count ?? 0),
                height: 36,
                horizontalPadding: 22,
                isDisabled: mods.selectedEntryCount == 0 || busy
            ) {
                Task { await mods.installPreview() }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { hairline }
    }
}
