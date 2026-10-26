import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayController

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                PageHeader(eyebrow: "Library", title: "Your instances", alignment: .leading)
                Spacer(minLength: 16)
                HStack(spacing: 12) {
                    SearchField(placeholder: "Search instances", text: $app.search)
                    PrimaryPill(title: "New instance", height: 42, horizontalPadding: 22)
                }
            }
            .padding(.horizontal, 40)

            HStack(spacing: 8) {
                ForEach(LoaderFilter.allCases) { filter in
                    FilterChip(title: filter.rawValue, isActive: app.filter == filter) { app.filter = filter }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 22)

            let items = app.filteredInstances
            ScrollView {
                if items.isEmpty {
                    Text(tr: "No instances found.")
                        .style(.body16)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            InstanceCard(instance: item, onOpen: { app.open(item) }, onPlay: {
                                app.open(item)
                                player.play(item, settings: settings)
                            })
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 24)
                }
            }
        }
        .padding(.top, 28)
    }
}
