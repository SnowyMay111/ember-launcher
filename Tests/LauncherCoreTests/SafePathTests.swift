import Foundation
import Testing
@testable import LauncherCore

struct SafePathTests {
    private func makeManager() -> ModpackManager {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = LauncherPaths(root: tempURL)
        let store = InstanceStore(paths: paths)
        return ModpackManager(store: store)
    }

    @Test func rejectsParentDirectoryEscape() {
        let manager = makeManager()
        let base = URL(fileURLWithPath: "/tmp/base")
        #expect(!manager.isSafeRelativePath("../x", relativeTo: base))
    }

    @Test func rejectsAbsolutePath() {
        let manager = makeManager()
        let base = URL(fileURLWithPath: "/tmp/base")
        #expect(!manager.isSafeRelativePath("/x", relativeTo: base))
    }

    @Test func rejectsHomeExpansion() {
        let manager = makeManager()
        let base = URL(fileURLWithPath: "/tmp/base")
        #expect(!manager.isSafeRelativePath("~", relativeTo: base))
    }

    @Test func rejectsMixedTraversal() {
        let manager = makeManager()
        let base = URL(fileURLWithPath: "/tmp/base")
        #expect(!manager.isSafeRelativePath("a/../../b", relativeTo: base))
    }

    @Test func rejectsBackslash() {
        let manager = makeManager()
        let base = URL(fileURLWithPath: "/tmp/base")
        #expect(!manager.isSafeRelativePath("a\\b", relativeTo: base))
    }

    @Test func rejectsNulCharacter() {
        let manager = makeManager()
        let base = URL(fileURLWithPath: "/tmp/base")
        #expect(!manager.isSafeRelativePath("a\0b", relativeTo: base))
    }

    @Test func rejectsEmptyPath() {
        let manager = makeManager()
        let base = URL(fileURLWithPath: "/tmp/base")
        #expect(!manager.isSafeRelativePath("", relativeTo: base))
    }

    @Test func acceptsSimpleModPath() {
        let manager = makeManager()
        let base = URL(fileURLWithPath: "/tmp/base")
        #expect(manager.isSafeRelativePath("mods/a.jar", relativeTo: base))
    }

    @Test func acceptsNestedConfigPath() {
        let manager = makeManager()
        let base = URL(fileURLWithPath: "/tmp/base")
        #expect(manager.isSafeRelativePath("config/x/y.toml", relativeTo: base))
    }
}
