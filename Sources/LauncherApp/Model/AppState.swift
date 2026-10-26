import SwiftUI

enum Screen: String, CaseIterable, Identifiable {
    case play = "Play"
    case library = "Library"
    case mods = "Mods"
    case skins = "Skins"
    case settings = "Settings"

    var id: String { rawValue }
}

final class AppState: ObservableObject {
    @Published var screen: Screen = .play
    @Published var instances: [LibraryInstance] = SampleData.instances
    @Published var currentID: LibraryInstance.ID?
    @Published var filter: LoaderFilter = .all
    @Published var search: String = ""

    var current: LibraryInstance? {
        instances.first { $0.id == currentID } ?? instances.first
    }

    var filteredInstances: [LibraryInstance] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return instances.filter { item in
            filter.matches(item.loader)
                && (query.isEmpty || item.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }
    }

    /// Clicking a card in Library makes it the current instance and shows it on Play.
    func open(_ item: LibraryInstance) {
        currentID = item.id
        screen = .play
    }
}
