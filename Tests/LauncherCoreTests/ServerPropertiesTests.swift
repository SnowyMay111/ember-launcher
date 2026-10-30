import Foundation
import Testing
@testable import LauncherCore

struct ServerPropertiesTests {
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func testParseSkipsBlankAndCommentLinesAndSplitsOnFirstEquals() {
        let text = """
        # comment
        server-port=25565

        motd=Hello=World
        """

        let entries = ServerProperties.parse(text)

        #expect(entries.count == 2)
        #expect(entries[0].key == "server-port")
        #expect(entries[0].value == "25565")
        #expect(entries[1].key == "motd")
        #expect(entries[1].value == "Hello=World")
    }

    @Test func testUpdateKeepsCommentsAndUnknownKeysAndReplacesKnownKey() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = """
        # My server
        difficulty=hard
        gamemode=survival
        server-port=25565
        """
        try original.write(to: dir.appendingPathComponent("server.properties"), atomically: true, encoding: .utf8)

        try ServerProperties.update(in: dir, values: ["server-port": "25599"])

        let contents = try String(contentsOf: dir.appendingPathComponent("server.properties"), encoding: .utf8)
        let lines = contents.split(separator: "\n").map(String.init)

        #expect(lines.contains("# My server"))
        #expect(lines.contains("difficulty=hard"))
        #expect(lines.contains("gamemode=survival"))
        #expect(lines.contains("server-port=25599"))
        #expect(!lines.contains("server-port=25565"))
    }

    @Test func testUpdateAppendsMissingKeyAtTheEnd() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = "difficulty=hard\n"
        try original.write(to: dir.appendingPathComponent("server.properties"), atomically: true, encoding: .utf8)

        try ServerProperties.update(in: dir, values: ["max-players": "10"])

        let contents = try String(contentsOf: dir.appendingPathComponent("server.properties"), encoding: .utf8)
        let lines = contents.split(separator: "\n").map(String.init)

        #expect(lines == ["difficulty=hard", "max-players=10"])
    }

    @Test func testWriteServerPropertiesPreservesDifficultyOnSecondCall() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        try LocalServerFiles.writeServerProperties(in: dir, port: 25565, maxPlayers: 4, motd: "First")
        try ServerProperties.update(in: dir, values: ["difficulty": "hard"])

        try LocalServerFiles.writeServerProperties(in: dir, port: 25599, maxPlayers: 8, motd: "Second")

        let properties = ServerProperties.read(in: dir)

        #expect(properties["difficulty"] == "hard")
        #expect(properties["server-port"] == "25599")
        #expect(properties["max-players"] == "8")
        #expect(properties["motd"] == "Second")
    }
}
