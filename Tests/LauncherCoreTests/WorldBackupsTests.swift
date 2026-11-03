import Foundation
import Testing
@testable import LauncherCore

struct WorldBackupsTests {
    private func make() throws -> (WorldBackups, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = InstanceStore(paths: LauncherPaths(root: root))
        let saves = store.gameDirectory(for: "i").appendingPathComponent("saves", isDirectory: true)
        let world = saves.appendingPathComponent("My World", isDirectory: true)
        try FileManager.default.createDirectory(at: world, withIntermediateDirectories: true)
        try Data("lvl".utf8).write(to: world.appendingPathComponent("level.dat"))
        try FileManager.default.createDirectory(at: saves.appendingPathComponent("not-a-world"), withIntermediateDirectories: true)
        return (WorldBackups(store: store, instance: "i"), world)
    }

    @Test func listsOnlyFoldersWithLevelDat() throws {
        let (backups, _) = try make()
        #expect(backups.worlds().map(\.folderName) == ["My World"])
    }

    @Test func manualBackupAndRestoreParkTheCurrentWorld() throws {
        let (backups, world) = try make()
        try backups.backUp("My World")
        try Data("changed".utf8).write(to: world.appendingPathComponent("level.dat"))
        let copy = try #require(backups.backups(of: "My World").first)
        try backups.restore(copy, as: "My World")
        #expect(try String(contentsOf: world.appendingPathComponent("level.dat"), encoding: .utf8) == "lvl")
        let parked = world.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("world-backups/My World")
        let names = try FileManager.default.contentsOfDirectory(atPath: parked.path)
        #expect(names.contains { $0.hasPrefix("before-restore-") })
    }

    @Test func automaticPassSkipsUnchangedAndPrunesOnlyAutomatic() throws {
        let (backups, world) = try make()
        let now = Date()
        try backups.backUp("My World", at: now.addingTimeInterval(-100))
        // World changed after the manual copy → first automatic pass copies it.
        #expect(backups.backUpChangedWorlds(keep: 1, at: now.addingTimeInterval(10)) == ["My World"])
        // Nothing changed since → no second copy.
        #expect(backups.backUpChangedWorlds(keep: 1, at: now.addingTimeInterval(20)).isEmpty)
        // A fresh change gives a second automatic copy; keep 1 drops the older automatic one, never the manual one.
        let level = world.appendingPathComponent("level.dat")
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(30)], ofItemAtPath: level.path)
        #expect(backups.backUpChangedWorlds(keep: 1, at: now.addingTimeInterval(40)) == ["My World"])
        let all = backups.backups(of: "My World")
        #expect(all.filter(\.isAutomatic).count == 1)
        #expect(all.filter { !$0.isAutomatic }.count == 1)
    }

    @Test func refusesNamesWithPaths() throws {
        let (backups, _) = try make()
        #expect(throws: (any Error).self) { try backups.backUp("../x") }
    }
}
