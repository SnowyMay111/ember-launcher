import Foundation
import Testing
@testable import LauncherCore

struct EmberFriendsTests {
    @Test func decodesOverviewEntries() throws {
        let json = """
        [
          {
            "user_id": "user-1",
            "tag": "alice#0001",
            "display_name": "Alice",
            "avatar_name": "avatar1",
            "relation": "friend",
            "online": true,
            "activity": "Playing SkyFactory",
            "last_seen_at": "2026-10-30T12:00:00.123Z"
          },
          {
            "user_id": "user-2",
            "tag": "bob#0002",
            "display_name": "Bob",
            "avatar_name": null,
            "relation": "incoming",
            "online": null,
            "activity": null,
            "last_seen_at": null
          }
        ]
        """

        let entries = try EmberFriends.decode(Data(json.utf8))
        #expect(entries.count == 2)

        let alice = entries[0]
        #expect(alice.userID == "user-1")
        #expect(alice.tag == "alice#0001")
        #expect(alice.displayName == "Alice")
        #expect(alice.avatarName == "avatar1")
        #expect(alice.relation == .friend)
        #expect(alice.online == true)
        #expect(alice.activity == "Playing SkyFactory")
        #expect(alice.lastSeenAt != nil)

        let bob = entries[1]
        #expect(bob.userID == "user-2")
        #expect(bob.tag == "bob#0002")
        #expect(bob.avatarName == nil)
        #expect(bob.relation == .incoming)
        #expect(bob.online == false)
        #expect(bob.activity == nil)
        #expect(bob.lastSeenAt == nil)
    }
}
