import Foundation
import Testing
@testable import LauncherCore

struct AuditFixTests {
    @Test func modListShowsOneRowForJarAndDisabledTwin() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = ModManager(store: InstanceStore(paths: LauncherPaths(root: dir)))
        let modsDir = manager.modsDirectory(for: "x")
        try FileManager.default.createDirectory(at: modsDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: modsDir.appendingPathComponent("a.jar").path, contents: Data())
        FileManager.default.createFile(atPath: modsDir.appendingPathComponent("a.jar.disabled").path, contents: Data())
        FileManager.default.createFile(atPath: modsDir.appendingPathComponent("b.jar.disabled").path, contents: Data())

        let mods = try manager.list(instance: "x")
        #expect(mods.count == 2)
        #expect(mods.first { $0.fileName == "a.jar" }?.isEnabled == true)
        #expect(mods.first { $0.fileName == "b.jar" }?.isEnabled == false)
    }

    @Test func modListKeepsEnabledWhateverTheOrder() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = ModManager(store: InstanceStore(paths: LauncherPaths(root: dir)))
        let modsDir = manager.modsDirectory(for: "x")
        try FileManager.default.createDirectory(at: modsDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: modsDir.appendingPathComponent("a.jar.disabled").path, contents: Data())
        FileManager.default.createFile(atPath: modsDir.appendingPathComponent("a.jar").path, contents: Data())

        let mods = try manager.list(instance: "x")
        #expect(mods.map(\.fileName) == ["a.jar"])
        #expect(mods[0].isEnabled)
    }

    @Test func outOfMemoryCapsSmoothnessScore() {
        let stats = FreezeStats(outOfMemoryCount: 1)
        let instance = Instance(name: "x", minecraftVersion: "1.21", versionId: "1.21")
        let report = SessionHealthReport.make(stats: stats, instance: instance, playtime: 600, architecture: .arm64Native, voxyIssue: false, javaMajor: 21)
        #expect(report.isConclusive)
        #expect(report.smoothnessScore <= 40)
    }

    @Test func allocationStallsLowerSmoothnessScore() {
        let stats = FreezeStats(allocationStallCount: 9)
        let instance = Instance(name: "x", minecraftVersion: "1.21", versionId: "1.21")
        let report = SessionHealthReport.make(stats: stats, instance: instance, playtime: 600, architecture: .arm64Native, voxyIssue: false, javaMajor: 21)
        #expect(report.smoothnessScore < 100)

        let control = SessionHealthReport.make(stats: FreezeStats(), instance: instance, playtime: 600, architecture: .arm64Native, voxyIssue: false, javaMajor: 21)
        #expect(control.smoothnessScore == 100)
    }
}
