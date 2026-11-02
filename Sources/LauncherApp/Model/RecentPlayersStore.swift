import Foundation
import LauncherCore

/// Players met in lobbies, newest first. Kept in a file on this Mac only.
@MainActor
final class RecentPlayersStore: ObservableObject {
    static let shared = RecentPlayersStore()

    @Published private(set) var players: [RecentPlayerRecord] = []

    private static let limit = 30
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? LauncherPaths().root.appendingPathComponent("recent-players.json")
        if let data = try? Data(contentsOf: self.fileURL),
           let saved = try? JSONDecoder().decode([RecentPlayerRecord].self, from: data) {
            players = saved
        }
    }

    func record(_ members: [LobbyMemberTag], selfID: String?) {
        players = SocialLogic.mergeRecent(existing: players, incoming: members, selfID: selfID, now: Date(), limit: Self.limit)
        save()
    }

    func remove(userID: String) {
        players.removeAll { $0.userID == userID }
        save()
    }

    private func save() {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(players) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
