import Foundation
import Testing
@testable import LauncherCore

struct LobbyContentSyncTests {
    @Test func testDraftsIncludeEnabledModsWithRecords() {
        let recorded = InstalledMod(fileName: "a.jar", isEnabled: true, record: ModRecord(
            fileName: "a.jar", projectId: "pA", versionId: "VerA1234", title: "A", versionNumber: "1"))
        let (drafts, unsynced) = LobbyContentDrafts.make(mods: [recorded], content: [])
        #expect(drafts == [LobbyContentDraft(kind: .mod, projectID: "pA", versionID: "VerA1234", title: "A")])
        #expect(unsynced == 0)
    }

    @Test func testDraftsCountEnabledModsWithoutRecordsAsUnsynced() {
        let manual = InstalledMod(fileName: "b.jar", isEnabled: true)
        let (drafts, unsynced) = LobbyContentDrafts.make(mods: [manual], content: [])
        #expect(drafts.isEmpty)
        #expect(unsynced == 1)
    }

    @Test func testDraftsIgnoreDisabledMods() {
        let off = InstalledMod(fileName: "c.jar", isEnabled: false, record: ModRecord(
            fileName: "c.jar", projectId: "pC", versionId: "VerC1234", title: "C", versionNumber: "1"))
        let (drafts, unsynced) = LobbyContentDrafts.make(mods: [off], content: [])
        #expect(drafts.isEmpty)
        #expect(unsynced == 0)
    }

    @Test func testDraftsMapShaderAndResourcePackRecords() {
        let shader = ContentRecord(
            fileName: "shader.zip", projectId: "pS", versionId: "VerS1234", title: "Shader",
            versionNumber: "1", kind: .shader)
        let pack = ContentRecord(
            fileName: "pack.zip", projectId: "pR", versionId: "VerR1234", title: "Pack",
            versionNumber: "1", kind: .resourcepack)
        let (drafts, unsynced) = LobbyContentDrafts.make(mods: [], content: [shader, pack])
        #expect(drafts == [
            LobbyContentDraft(kind: .shader, projectID: "pS", versionID: "VerS1234", title: "Shader"),
            LobbyContentDraft(kind: .resourcepack, projectID: "pR", versionID: "VerR1234", title: "Pack"),
        ])
        #expect(unsynced == 0)
    }

    @Test func testDraftsDeduplicateByVersionID() {
        let recorded = InstalledMod(fileName: "a.jar", isEnabled: true, record: ModRecord(
            fileName: "a.jar", projectId: "pA", versionId: "VerDup1234", title: "A", versionNumber: "1"))
        let shader = ContentRecord(
            fileName: "shader.zip", projectId: "pS", versionId: "VerDup1234", title: "Shader",
            versionNumber: "1", kind: .shader)
        let (drafts, unsynced) = LobbyContentDrafts.make(mods: [recorded], content: [shader])
        #expect(drafts.count == 1)
        #expect(drafts.first?.versionID == "VerDup1234")
        #expect(unsynced == 0)
    }

    @Test func testUnsafePackNamesAreRefused() {
        #expect(LobbyContentSyncer.isSafePackName("ComplementaryShaders.zip"))
        #expect(!LobbyContentSyncer.isSafePackName("../evil.zip"))
        #expect(!LobbyContentSyncer.isSafePackName("dir/evil.zip"))
        #expect(!LobbyContentSyncer.isSafePackName("evil.jar"))
        #expect(!LobbyContentSyncer.isSafePackName(".hidden.zip"))
        #expect(!LobbyContentSyncer.isSafePackName(""))
    }
}
