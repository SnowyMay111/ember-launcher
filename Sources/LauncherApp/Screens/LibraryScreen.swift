import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayController

    @Local private var pendingDelete: String? = nil
    @Local private var deleteError = ""

    private func columns(for width: CGFloat) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: width >= 1000 ? 3 : 2)
    }

    var body: some View {
        let items = app.groupedInstances.flatMap(\.items)
        GeometryReader { geo in
            let width = min(1120, geo.size.width - 56)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(
                        eyebrow: "Your worlds",
                        title: "Instances",
                        subtitle: "Every world, safe and ready when you are.",
                        alignment: .leading,
                        actionTitle: "New instance"
                    ) { app.modal = .newInstance }
                    .padding(.bottom, 26)

                    WideSearchField(placeholder: "Search instances", text: $app.search, resultText: L("%d found", items.count))
                        .padding(.bottom, 16)

                    HStack(spacing: 8) {
                        ForEach(LoaderFilter.allCases) { filter in
                            FilterChip(title: filter.rawValue, isActive: app.filter == filter, compact: false) { app.filter = filter }
                        }
                        FilterChip(title: "All versions", isActive: false, compact: false) { app.modal = .allVersions }
                        Spacer(minLength: 16)
                        Text(verbatim: L("%d instances", items.count) + " · " + LibraryInstance.duration(minutes: items.reduce(0) { $0 + $1.playtimeSeconds } / 60) + " · " + L("%d mods", items.reduce(0) { $0 + $1.modCount }))
                            .style(.init(size: 13, color: Theme.textSecondary))
                            .lineLimit(1)
                    }
                    .padding(.bottom, 20)

                    if app.instances.isEmpty {
                        Text(tr: "No instances yet. Press New instance to create one.")
                            .style(.body16)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if items.isEmpty {
                        Text(tr: "No instances found.")
                            .style(.body16)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns(for: width), spacing: 14) {
                            ForEach(items) { item in
                                InstanceCard(
                                    instance: item,
                                    onOpen: { app.modal = .instanceDetails(item.name) },
                                    onPlay: {
                                        app.open(item)
                                        player.play(item, settings: settings, app: app)
                                    },
                                    onDelete: {
                                        pendingDelete = item.name
                                    },
                                    onFolder: { app.openFolder(item.name) },
                                    onSettings: { app.modal = .instanceSettings(item.name) }
                                )
                                .contextMenu {
                                    Button(L("Instance settings")) { app.modal = .instanceSettings(item.name) }
                                    Button(L("Open folder")) { app.openFolder(item.name) }
                                    Button(L("Delete…")) { pendingDelete = item.name }
                                }
                            }
                            if app.search.isEmpty {
                                NewInstanceTile { app.modal = .newInstance }
                            }
                        }
                    }
                }
                .frame(width: width)
                .padding(.top, 42)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: app.deleteRequest) { _, name in
            guard let name else { return }
            pendingDelete = name
            app.deleteRequest = nil
        }
        .confirmationDialog(
            L("Delete “%@”?", pendingDelete ?? ""),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { name in
            Button(L("Move to Trash")) {
                if player.isBusy {
                    deleteError = L("Close the game first.")
                    return
                }
                do {
                    try app.trashInstance(name)
                } catch {
                    deleteError = error.localizedDescription
                }
            }
            Button(L("Delete forever"), role: .destructive) {
                if player.isBusy {
                    deleteError = L("Close the game first.")
                    return
                }
                do {
                    try app.deleteInstanceForever(name)
                } catch {
                    deleteError = error.localizedDescription
                }
            }
            Button(L("Keep it"), role: .cancel) {}
        } message: { name in
            Text(L("Move to Trash keeps it recoverable; Delete forever removes “%@”, its worlds and its mods for good.", name))
        }
        .alert(
            L("Could not delete"),
            isPresented: Binding(
                get: { !deleteError.isEmpty },
                set: { if !$0 { deleteError = "" } }
            )
        ) {
            Button(L("OK")) {
                deleteError = ""
            }
        } message: {
            Text(deleteError)
        }
    }
}

private struct NewInstanceTile: View {
    let action: () -> Void

    @Local private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(Theme.font(size: 24, weight: .medium))
                    .foregroundColor(Theme.ember)
                Text(tr: "New instance")
                    .style(.init(size: 16, weight: .semibold, color: Theme.text))
                Text(tr: "Vanilla, Fabric, Quilt, Forge or NeoForge")
                    .style(.init(size: 13, color: Theme.textSecondary))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 330, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                .foregroundColor(isHovered ? Theme.ember.opacity(0.7) : Theme.lineStrong)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .accessibilityLabel(L("New instance"))
    }
}
