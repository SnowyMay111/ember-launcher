import Foundation
import Testing
@testable import LauncherCore

struct InstanceNameTests {
    private func makeStore() -> InstanceStore {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = LauncherPaths(root: tempURL)
        return InstanceStore(paths: paths)
    }

    @Test func rejectsParentDirectoryName() {
        #expect(!InstanceStore.isValidName(".."))
    }

    @Test func rejectsParentDirectoryTraversal() {
        #expect(!InstanceStore.isValidName("../x"))
    }

    @Test func rejectsSlash() {
        #expect(!InstanceStore.isValidName("a/b"))
    }

    @Test func rejectsHiddenDotPrefix() {
        #expect(!InstanceStore.isValidName(".hidden"))
    }

    @Test func rejectsEmptyName() {
        #expect(!InstanceStore.isValidName(""))
    }

    @Test func rejectsWhitespaceOnlyName() {
        #expect(!InstanceStore.isValidName("  "))
    }

    @Test func rejectsBackslash() {
        #expect(!InstanceStore.isValidName("a\\b"))
    }

    @Test func acceptsCyrillicName() {
        #expect(InstanceStore.isValidName("Мой мир"))
    }

    @Test func acceptsNameWithSpacesAndDots() {
        #expect(InstanceStore.isValidName("Fabric 1.21.1"))
    }

    @Test func createThrowsInvalidNameForTraversal() {
        let store = makeStore()
        do {
            _ = try store.create(name: "../x", minecraftVersion: "1.21.1")
            Issue.record("Expected InstanceStoreError.invalidName to be thrown")
        } catch InstanceStoreError.invalidName {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
