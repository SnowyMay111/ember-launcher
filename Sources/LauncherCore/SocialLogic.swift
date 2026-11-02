import Foundation

/// A player met in a lobby, as stored in the recent players list.
public struct RecentPlayerRecord: Codable, Sendable, Identifiable, Equatable {
    public let userID: String
    public var tag: String
    public var name: String
    public var lastSeen: Date

    public var id: String { userID }

    public init(userID: String, tag: String, name: String, lastSeen: Date) {
        self.userID = userID
        self.tag = tag
        self.name = name
        self.lastSeen = lastSeen
    }
}

/// Pure helpers behind the Social screen's recent players and invites.
public enum SocialLogic {
    /// Merges lobby members into the recent list: skips `selfID`, refreshes tag/name/lastSeen
    /// of known players, sorts newest first and keeps at most `limit` entries.
    public static func mergeRecent(
        existing: [RecentPlayerRecord],
        incoming: [LobbyMemberTag],
        selfID: String?,
        now: Date,
        limit: Int
    ) -> [RecentPlayerRecord] {
        var byID = Dictionary(
            existing.filter { $0.userID != selfID }.map { ($0.userID, $0) },
            uniquingKeysWith: { $0.lastSeen >= $1.lastSeen ? $0 : $1 }
        )
        for member in incoming where member.userID != selfID {
            byID[member.userID] = RecentPlayerRecord(
                userID: member.userID,
                tag: member.tag,
                name: member.displayName,
                lastSeen: now
            )
        }
        let sorted = byID.values.sorted {
            $0.lastSeen != $1.lastSeen ? $0.lastSeen > $1.lastSeen : $0.userID < $1.userID
        }
        return Array(sorted.prefix(max(limit, 0)))
    }

    /// Ids from `current` that were never marked seen and are not dismissed, in their original order.
    public static func unseenInvites(current: [String], seen: Set<String>, dismissed: Set<String>) -> [String] {
        current.filter { !seen.contains($0) && !dismissed.contains($0) }
    }

    /// Removes duplicates (the last occurrence wins) and keeps the `limit` most recently appended ids.
    public static func trimmed(_ ids: [String], limit: Int) -> [String] {
        var kept = Set<String>()
        var newestFirst: [String] = []
        for id in ids.reversed() where kept.insert(id).inserted {
            newestFirst.append(id)
        }
        return Array(newestFirst.prefix(max(limit, 0)).reversed())
    }
}
