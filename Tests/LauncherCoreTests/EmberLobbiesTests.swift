import Foundation
import Testing
@testable import LauncherCore

struct EmberLobbiesTests {
    @Test func decodesJoinRowOk() throws {
        let json = """
        [
          {
            "result": "ok",
            "lobby": {
              "id": "lobby-1",
              "name": "Friday Pack",
              "mc_version": "1.20.1",
              "loader": "fabric",
              "pack_url": "https://example.com/pack.zip",
              "pack_sha1": "deadbeef",
              "address": "127.0.0.1:25565",
              "max_players": 6,
              "host": "user-1"
            }
          }
        ]
        """

        let outcome = try EmberLobbies.decodeJoin(Data(json.utf8))
        guard case .ok(let lobby) = outcome else {
            Issue.record("expected .ok outcome")
            return
        }
        #expect(lobby.id == "lobby-1")
        #expect(lobby.name == "Friday Pack")
        #expect(lobby.mcVersion == "1.20.1")
        #expect(lobby.loader == "fabric")
        #expect(lobby.packURL == "https://example.com/pack.zip")
        #expect(lobby.packSHA1 == "deadbeef")
        #expect(lobby.address == "127.0.0.1:25565")
        #expect(lobby.maxPlayers == 6)
        #expect(lobby.host == "user-1")
    }

    @Test func decodesJoinRowNickTaken() throws {
        let json = """
        [
          { "result": "nick_taken", "lobby": null }
        ]
        """

        let outcome = try EmberLobbies.decodeJoin(Data(json.utf8))
        #expect(outcome == .nickTaken)
    }

    @Test func decodesCreateRow() throws {
        let json = """
        [
          { "lobby_id": "lobby-42", "code": "ABCD12" }
        ]
        """

        let created = try EmberLobbies.decodeCreate(Data(json.utf8))
        #expect(created.id == "lobby-42")
        #expect(created.code == "ABCD12")
    }

    @Test func decodesVisibleLobbies() throws {
        let json = """
        [
          {
            "lobby_id": "lobby-7",
            "name": "Chill Night",
            "mc_version": "1.21.0",
            "loader": "neoforge",
            "host_user": "user-9",
            "host_tag": "nova#1234",
            "host_name": "Nova",
            "players": 3,
            "max_players": 8,
            "invited": true,
            "ready": false
          }
        ]
        """

        let lobbies = try EmberLobbies.decodeVisible(Data(json.utf8))
        #expect(lobbies.count == 1)

        let lobby = lobbies[0]
        #expect(lobby.lobbyID == "lobby-7")
        #expect(lobby.name == "Chill Night")
        #expect(lobby.mcVersion == "1.21.0")
        #expect(lobby.loader == "neoforge")
        #expect(lobby.hostUser == "user-9")
        #expect(lobby.hostTag == "nova#1234")
        #expect(lobby.hostName == "Nova")
        #expect(lobby.players == 3)
        #expect(lobby.maxPlayers == 8)
        #expect(lobby.invited == true)
        #expect(lobby.ready == false)
    }

    @Test func unknownJoinResultThrows() {
        let json = """
        [
          { "result": "mystery", "lobby": null }
        ]
        """

        #expect(throws: EmberAuthError.self) {
            try EmberLobbies.decodeJoin(Data(json.utf8))
        }
    }

    @Test func decodesTunnelKeyPresent() throws {
        let key = try EmberLobbies.decodeTunnelKey(Data("\"k1\"".utf8))
        #expect(key == "k1")
    }

    @Test func decodesTunnelKeyNull() throws {
        let key = try EmberLobbies.decodeTunnelKey(Data("null".utf8))
        #expect(key == nil)
    }

    @Test func decodesTunnelKeyEmpty() throws {
        let key = try EmberLobbies.decodeTunnelKey(Data("\"\"".utf8))
        #expect(key == nil)
    }

    @Test func decodesSignalsRows() throws {
        let json = """
        [
          { "id": 12, "from_user": "user-1", "payload": "offer-data" },
          { "id": 13, "from_user": "user-2", "payload": "answer-data" }
        ]
        """

        let signals = try EmberLobbies.decodeSignals(Data(json.utf8))
        #expect(signals.count == 2)
        #expect(signals[0].id == 12)
        #expect(signals[0].from == "user-1")
        #expect(signals[0].payload == "offer-data")
        #expect(signals[1].id == 13)
        #expect(signals[1].from == "user-2")
        #expect(signals[1].payload == "answer-data")
    }

    @Test func decodesSignalsEmpty() throws {
        let signals = try EmberLobbies.decodeSignals(Data("[]".utf8))
        #expect(signals.isEmpty)
    }

    @Test func decodesJoinRowRoomStarting() throws {
        let json = """
        [
          {
            "result": "ok",
            "lobby": {
              "id": "lobby-1",
              "name": "Friday Pack",
              "mc_version": "1.20.1",
              "loader": "fabric",
              "pack_url": null,
              "pack_sha1": null,
              "address": null,
              "max_players": 6,
              "host": "user-1",
              "status": "starting",
              "edit_policy": "friends",
              "sync_shaders": true,
              "sync_resourcepacks": false,
              "can_edit": true
            }
          }
        ]
        """

        let outcome = try EmberLobbies.decodeJoin(Data(json.utf8))
        guard case .ok(let lobby) = outcome else {
            Issue.record("expected .ok outcome")
            return
        }
        #expect(lobby.address == nil)
        #expect(lobby.status == "starting")
        #expect(lobby.editPolicy == .friends)
        #expect(lobby.syncShaders == true)
        #expect(lobby.syncResourcePacks == false)
        #expect(lobby.canEdit == true)
    }

    @Test func decodesRosterWithCanEdit() throws {
        let json = """
        [
          { "user_id": "user-1", "nick": "Alice", "state": "joined", "can_edit": true },
          { "user_id": "user-2", "nick": "Bob", "state": "joined" }
        ]
        """

        let roster = try EmberLobbies.decodeRoster(Data(json.utf8))
        #expect(roster.count == 2)
        #expect(roster[0].canEdit == true)
        #expect(roster[1].canEdit == false)
    }

    @Test func decodesItems() throws {
        let json = """
        [
          {
            "id": "item-1",
            "kind": "mod",
            "project_id": "AANobbMI",
            "version_id": "abcd1234",
            "title": "Sodium",
            "added_by": "user-1",
            "added_nick": "Alice"
          }
        ]
        """

        let items = try EmberLobbies.decodeItems(Data(json.utf8))
        #expect(items.count == 1)
        #expect(items[0].id == "item-1")
        #expect(items[0].kind == .mod)
        #expect(items[0].projectID == "AANobbMI")
        #expect(items[0].versionID == "abcd1234")
        #expect(items[0].title == "Sodium")
        #expect(items[0].addedBy == "user-1")
        #expect(items[0].addedNick == "Alice")
    }

    @Test func decodesItemResultOk() throws {
        let result = try EmberLobbies.decodeItemResult(Data("\"ok\"".utf8))
        #expect(result == .ok)
    }

    @Test func decodesItemResultNotFound() throws {
        let result = try EmberLobbies.decodeItemResult(Data("\"not_found\"".utf8))
        #expect(result == .notFound)
    }

    @Test func decodesInfoNull() throws {
        let info = try EmberLobbies.decodeInfo(Data("null".utf8))
        #expect(info == nil)
    }
}
