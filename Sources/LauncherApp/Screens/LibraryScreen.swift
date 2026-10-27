import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayController

    @Local private var pendingDelete: String? = nil
    @Local private var deleteError = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                PageHeader(eyebrow: "Library", title: "Your instances", alignment: .leading)
                Spacer(minLength: 16)
                HStack(spacing: 12) {
                    SearchField(placeholder: "Search instances", text: $app.search)
                    PrimaryPill(title: "New instance", height: 42, horizontalPadding: 22) { app.modal = .newInstance }
                }
            }
            .padding(.horizontal, 40)

            HStack(spacing: 8) {
                ForEach(LoaderFilter.allCases) { filter in
                    FilterChip(title: filter.rawValue, isActive: app.filter == filter) { app.filter = filter }
                }
                Spacer(minLength: 16)
                SecondaryPill(title: "All versions") { app.modal = .allVersions }
            }
            .padding(.horizontal, 40)
            .padding(.top, 22)

            let groups = app.groupedInstances
            ScrollView {
                if app.instances.isEmpty {
                    Text(tr: "No instances yet. Press New instance to create one.")
                        .style(.body16)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if groups.isEmpty {
                    Text(tr: "No instances found.")
                        .style(.body16)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(groups, id: \.name) { group in
                            VStack(alignment: .leading, spacing: 14) {
                                Text(verbatim: L(group.name) + " · \(group.items.count)").style(.eyebrow)
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(group.items) { item in
                                        InstanceCard(instance: item, onOpen: { app.open(item) }, onPlay: {
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
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 24)
                }
            }
        }
        .padding(.top, 28)
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
