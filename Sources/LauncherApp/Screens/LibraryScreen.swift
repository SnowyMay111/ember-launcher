import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayController

    @Local private var pendingDelete: String? = nil
    @Local private var deleteError = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)

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
                    .padding(.bottom, 34)

                    HStack(spacing: 6) {
                        ForEach(LoaderFilter.allCases) { filter in
                            FilterChip(title: filter.rawValue, isActive: app.filter == filter, compact: true) { app.filter = filter }
                        }
                        FilterChip(title: "All versions", isActive: false, compact: true) { app.modal = .allVersions }
                        Spacer(minLength: 16)
                        SearchField(placeholder: "Search instances", text: $app.search, compact: true)
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
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(items) { item in
                                InstanceCard(instance: item, onOpen: { app.modal = .instanceDetails(item.name) }, onPlay: {
                                    app.open(item)
                                    player.play(item, settings: settings, app: app)
                                }, onDelete: {
                                    pendingDelete = item.name
                                })
                                .contextMenu {
                                    Button(L("Instance settings")) { app.modal = .instanceSettings(item.name) }
                                    Button(L("Open folder")) { app.openFolder(item.name) }
                                    Button(L("Delete…")) { pendingDelete = item.name }
                                }
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
