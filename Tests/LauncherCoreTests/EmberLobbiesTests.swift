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
}
