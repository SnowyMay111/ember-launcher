import Foundation
import Testing
@testable import LauncherCore

private struct WhitelistEntryForTest: Codable {
    let uuid: String
    let name: String
}

struct LocalServerFilesTests {
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func testWriteEula() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        try LocalServerFiles.writeEula(in: dir)
        let contents = try String(contentsOf: dir.appendingPathComponent("eula.txt"), encoding: .utf8)

        #expect(contents.contains("eula=true"))
    }

    @Test func testWriteServerProperties() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        try LocalServerFiles.writeServerProperties(in: dir, port: 25599, maxPlayers: 6, motd: "Hello\nworld")
        let contents = try String(contentsOf: dir.appendingPathComponent("server.properties"), encoding: .utf8)
        let lines = Set(contents.split(separator: "\n").map(String.init))

        #expect(lines.contains("server-ip=127.0.0.1"))
        #expect(lines.contains("server-port=25599"))
        #expect(lines.contains("online-mode=false"))
        #expect(lines.contains("white-list=true"))
        #expect(lines.contains("enforce-whitelist=true"))
        #expect(lines.contains("max-players=6"))
        #expect(lines.contains("motd=Hello world"))
        #expect(lines.contains("spawn-protection=0"))
        #expect(lines.contains("enable-query=false"))
        #expect(lines.contains("enable-rcon=false"))
        #expect(lines.contains("view-distance=10"))
        #expect(lines.contains("sync-chunk-writes=false"))
    }

    @Test func testWhitelistJSONIncludesValidNamesWithOfflineUUIDs() throws {
        let data = LocalServerFiles.whitelistJSON(names: ["Alice", "Bob"])
        let entries = try JSONDecoder().decode([WhitelistEntryForTest].self, from: data)

        let alice = try OfflineAccount(name: "Alice")
        let bob = try OfflineAccount(name: "Bob")

        #expect(entries.count == 2)
        #expect(entries.contains { $0.name == "Alice" && $0.uuid == alice.uuid })
        #expect(entries.contains { $0.name == "Bob" && $0.uuid == bob.uuid })
    }

    @Test func testWhitelistJSONSkipsInvalidNameAndDeduplicatesCaseInsensitively() throws {
        let data = LocalServerFiles.whitelistJSON(names: ["Steve", "steve", "ab"])
        let entries = try JSONDecoder().decode([WhitelistEntryForTest].self, from: data)

        #expect(entries.count == 1)
        #expect(entries[0].name == "Steve")
    }

    @Test func testWriteWhitelistWritesFile() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        try LocalServerFiles.writeWhitelist(in: dir, names: ["Alice"])
        let data = try Data(contentsOf: dir.appendingPathComponent("whitelist.json"))
        let entries = try JSONDecoder().decode([WhitelistEntryForTest].self, from: data)

        #expect(entries.count == 1)
        #expect(entries[0].name == "Alice")
    }

    @Test func testLinkModsCreatesSymlink() throws {
        let serverDirectory = try makeTempDirectory()
        let modsDirectory = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: serverDirectory)
            try? FileManager.default.removeItem(at: modsDirectory)
        }

        try LocalServerFiles.linkMods(serverDirectory: serverDirectory, to: modsDirectory)

        let modsLink = serverDirectory.appendingPathComponent("mods")
        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: modsLink.path)

        #expect(destination == modsDirectory.path)
    }

    @Test func testLinkModsReplacesExistingSymlink() throws {
        let serverDirectory = try makeTempDirectory()
        let oldTarget = try makeTempDirectory()
        let newTarget = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: serverDirectory)
            try? FileManager.default.removeItem(at: oldTarget)
            try? FileManager.default.removeItem(at: newTarget)
        }

        let modsLink = serverDirectory.appendingPathComponent("mods")
        try FileManager.default.createSymbolicLink(at: modsLink, withDestinationURL: oldTarget)

        try LocalServerFiles.linkMods(serverDirectory: serverDirectory, to: newTarget)

        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: modsLink.path)
        #expect(destination == newTarget.path)
    }

    @Test func testLinkModsRefusesRealDirectory() throws {
        let serverDirectory = try makeTempDirectory()
        let modsDirectory = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: serverDirectory)
            try? FileManager.default.removeItem(at: modsDirectory)
        }

        let modsLink = serverDirectory.appendingPathComponent("mods")
        try FileManager.default.createDirectory(at: modsLink, withIntermediateDirectories: true)
        let markerFile = modsLink.appendingPathComponent("marker.txt")
        try Data("keep".utf8).write(to: markerFile)

        #expect(throws: LocalServerFilesError.self) {
            try LocalServerFiles.linkMods(serverDirectory: serverDirectory, to: modsDirectory)
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: modsLink.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
        #expect(FileManager.default.fileExists(atPath: markerFile.path))
    }
}
