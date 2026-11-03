import Foundation
import Testing
@testable import LauncherCore

struct ModUpdateAllTests {
    private func update(_ title: String) -> ModUpdate {
        let record = ModRecord(fileName: "\(title).jar", projectId: "p\(title)", versionId: "old", title: title, versionNumber: "1")
        // No files in the new version → apply throws before any download, so no network or disk is touched.
        let version = ModrinthVersion(id: "new", projectId: "p\(title)", name: "2", versionNumber: "2", versionType: "release",
                                      datePublished: "2026-01-01T00:00:00Z", gameVersions: ["1.21"], loaders: ["fabric"], files: [])
        return ModUpdate(record: record, newVersion: version)
    }

    @Test func testFailuresDoNotStopTheBatchAndAreReported() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ember-upd-\(UUID().uuidString)")
        let manager = ModManager(store: InstanceStore(paths: LauncherPaths(root: dir)))
        let steps = Counter()
        let report = await manager.applyAll([update("A"), update("B")], instance: "x") { done, total in
            steps.add("\(done)/\(total)")
        }
        #expect(report.updated.isEmpty)
        #expect(report.failed.map(\.title) == ["A", "B"])
        #expect(steps.values == ["0/2", "1/2", "2/2"])
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []
    func add(_ s: String) { lock.lock(); items.append(s); lock.unlock() }
    var values: [String] { lock.lock(); defer { lock.unlock() }; return items }
}
