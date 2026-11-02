import Foundation
import Testing
@testable import LauncherCore

private func member(_ id: String, _ name: String = "Name") -> LobbyMemberTag {
    LobbyMemberTag(userID: id, tag: "#\(id)", displayName: name)
}

@Test func mergeRecentSkipsSelf() {
    let merged = SocialLogic.mergeRecent(
        existing: [],
        incoming: [member("me"), member("a")],
        selfID: "me",
        now: Date(timeIntervalSince1970: 100),
        limit: 30
    )
    #expect(merged.map(\.userID) == ["a"])
}

@Test func mergeRecentUpdatesExisting() {
    let old = RecentPlayerRecord(userID: "a", tag: "#old", name: "Old", lastSeen: Date(timeIntervalSince1970: 1))
    let now = Date(timeIntervalSince1970: 100)
    let merged = SocialLogic.mergeRecent(existing: [old], incoming: [member("a", "New")], selfID: nil, now: now, limit: 30)
    #expect(merged == [RecentPlayerRecord(userID: "a", tag: "#a", name: "New", lastSeen: now)])
}

@Test func mergeRecentSortsNewestFirstAndTrims() {
    let existing = (0..<5).map {
        RecentPlayerRecord(userID: "u\($0)", tag: "", name: "", lastSeen: Date(timeIntervalSince1970: Double($0)))
    }
    let merged = SocialLogic.mergeRecent(
        existing: existing,
        incoming: [member("fresh")],
        selfID: nil,
        now: Date(timeIntervalSince1970: 100),
        limit: 3
    )
    #expect(merged.map(\.userID) == ["fresh", "u4", "u3"])
}

@Test func unseenInvitesExcludesSeenAndDismissed() {
    let unseen = SocialLogic.unseenInvites(current: ["a", "b", "c", "d"], seen: ["b"], dismissed: ["d"])
    #expect(unseen == ["a", "c"])
}

@Test func trimmedKeepsNewestUnique() {
    #expect(SocialLogic.trimmed(["a", "b", "a", "c", "d"], limit: 3) == ["a", "c", "d"])
    #expect(SocialLogic.trimmed(["a", "b"], limit: 0) == [])
}
