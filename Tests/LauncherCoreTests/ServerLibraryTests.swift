import Foundation
import Testing
@testable import LauncherCore

struct ServerLibraryTests {
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func backupAndRestoreKeepsTheOldWorld() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ServerLibrary(root: root)
        let world = library.directory(for: "a").appendingPathComponent("world", isDirectory: true)
        try FileManager.default.createDirectory(at: world, withIntermediateDirectories: true)
        try Data("one".utf8).write(to: world.appendingPathComponent("level.dat"))

        try library.backupWorld(for: "a", at: Date(timeIntervalSince1970: 1_700_000_000))
        try Data("two".utf8).write(to: world.appendingPathComponent("level.dat"))

        let backups = library.listBackups(for: "a")
        #expect(backups.count == 1)
        try library.restoreBackup(backups[0], for: "a", at: Date(timeIntervalSince1970: 1_700_000_100))

        #expect(try String(contentsOf: world.appendingPathComponent("level.dat"), encoding: .utf8) == "one")
        let parked = library.directory(for: "a").appendingPathComponent("backups", isDirectory: true)
        let names = try FileManager.default.contentsOfDirectory(atPath: parked.path)
        #expect(names.contains { $0.hasPrefix("before-restore-") })
    }

    @Test func trustedPlayersRoundTripAndOldProfilesLoad() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ServerLibrary(root: root)
        let friend = TrustedPlayer(userID: "u1", tag: "alex#1234", name: "Alex")
        try library.save(ServerProfile(instanceName: "a", name: "A", minecraftVersion: "1.21.1", loader: "fabric", maxPlayers: 8, trusted: [friend]))
        #expect(library.profile(for: "a")?.trusted == [friend])

        let old = root.appendingPathComponent("b", isDirectory: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        let json = #"{"instanceName":"b","name":"B","minecraftVersion":"1.21.1","loader":"vanilla","maxPlayers":4}"#
        try Data(json.utf8).write(to: old.appendingPathComponent("ember-server.json"))
        #expect(library.profile(for: "b")?.trusted == [])
    }

    @Test func renameAutoBackupAndRemove() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ServerLibrary(root: root)
        try library.save(ServerProfile(instanceName: "a", name: "A", minecraftVersion: "1.21.1", loader: "fabric", maxPlayers: 8))
        try library.rename("a", to: "  Home world ")
        try library.setAutoBackup("a", true)
        #expect(library.profile(for: "a")?.name == "Home world")
        #expect(library.profile(for: "a")?.autoBackup == true)
        #expect(throws: (any Error).self) { try library.rename("a", to: "   ") }

        let world = library.directory(for: "a").appendingPathComponent("world", isDirectory: true)
        try FileManager.default.createDirectory(at: world, withIntermediateDirectories: true)
        for offset in 0..<4 {
            try library.backupWorld(for: "a", at: Date(timeIntervalSince1970: 1_700_000_000 + Double(offset) * 10), automatic: true)
        }
        try library.backupWorld(for: "a", at: Date(timeIntervalSince1970: 1_600_000_000))
        library.pruneAutomaticBackups(for: "a", keep: 2)
        let names = library.listBackups(for: "a").map { $0.url.lastPathComponent }
        #expect(names.filter { $0.hasPrefix("world-auto-") }.count == 2)
        #expect(names.contains { !$0.hasPrefix("world-auto-") })

        var trashed: URL?
        try library.remove("a") { trashed = $0 }
        #expect(trashed == library.directory(for: "a"))
    }

    @Test func testSaveAndListRoundTrip() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ServerLibrary(root: root)
        let profile = ServerProfile(
            instanceName: "my-server",
            name: "My Server",
            minecraftVersion: "1.21.1",
            loader: "fabric",
            maxPlayers: 8,
            lastPlayed: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try library.save(profile)
        let listed = library.list()

        #expect(listed.count == 1)
        #expect(listed[0] == profile)
    }

    @Test func testListOrdersByLastPlayedDescendingThenName() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ServerLibrary(root: root)

        let older = ServerProfile(
            instanceName: "older",
            name: "Older",
            minecraftVersion: "1.21.1",
            loader: "vanilla",
            maxPlayers: 4,
            lastPlayed: Date(timeIntervalSince1970: 1_000)
        )
        let newer = ServerProfile(
            instanceName: "newer",
            name: "Newer",
            minecraftVersion: "1.21.1",
            loader: "vanilla",
            maxPlayers: 4,
            lastPlayed: Date(timeIntervalSince1970: 2_000)
        )
        let neverPlayed = ServerProfile(
            instanceName: "never-played",
            name: "Never Played",
            minecraftVersion: "1.21.1",
            loader: "vanilla",
            maxPlayers: 4,
            lastPlayed: nil
        )

        try library.save(older)
        try library.save(newer)
        try library.save(neverPlayed)

        let listed = library.list()

        #expect(listed.map(\.instanceName) == ["newer", "older", "never-played"])
    }

    @Test func testListSkipsFolderWithoutJSON() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ServerLibrary(root: root)
        let profile = ServerProfile(
            instanceName: "has-json",
            name: "Has JSON",
            minecraftVersion: "1.21.1",
            loader: "vanilla",
            maxPlayers: 4,
            lastPlayed: nil
        )
        try library.save(profile)

        let emptyDirectory = root.appendingPathComponent("no-json", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)

        let listed = library.list()

        #expect(listed.count == 1)
        #expect(listed[0].instanceName == "has-json")
    }

    @Test func testMarkPlayedUpdatesDate() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ServerLibrary(root: root)
        let profile = ServerProfile(
            instanceName: "my-server",
            name: "My Server",
            minecraftVersion: "1.21.1",
            loader: "vanilla",
            maxPlayers: 4,
            lastPlayed: nil
        )
        try library.save(profile)

        let newDate = Date(timeIntervalSince1970: 1_800_000_000)
        try library.markPlayed("my-server", at: newDate)

        let listed = library.list()
        #expect(listed.count == 1)
        #expect(listed[0].lastPlayed == newDate)
    }

    @Test func testWorldFolderSizeCountsFiles() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ServerLibrary(root: root)
        let worldDirectory = library.directory(for: "my-server").appendingPathComponent("world", isDirectory: true)
        try FileManager.default.createDirectory(at: worldDirectory, withIntermediateDirectories: true)

        let levelData = Data(repeating: 0x42, count: 1234)
        try levelData.write(to: worldDirectory.appendingPathComponent("level.dat"))

        let size = library.worldFolderSize(for: "my-server")

        #expect(size == 1234)
    }

    @Test func testWorldFolderSizeIsZeroWhenMissing() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let library = ServerLibrary(root: root)
        let size = library.worldFolderSize(for: "no-such-server")

        #expect(size == 0)
    }
}
