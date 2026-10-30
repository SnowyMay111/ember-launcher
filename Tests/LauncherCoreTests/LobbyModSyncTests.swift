import Foundation
import Testing
@testable import LauncherCore

struct LobbyModSyncTests {
    @Test func testListRoundTripsThroughPackFields() throws {
        let list = LobbyModList(versionIDs: ["AbC123xy", "Zz9Yy8Xx"])
        let fields = try #require(list.packFields)
        #expect(fields.url == "modrinth:AbC123xy,Zz9Yy8Xx")
        #expect(LobbyModList(packURL: fields.url, packSHA1: fields.sha1)?.versionIDs == list.versionIDs)
    }

    @Test func testTamperedOrForeignFieldsAreRejected() throws {
        let fields = try #require(LobbyModList(versionIDs: ["AbC123xy"]).packFields)
        #expect(LobbyModList(packURL: fields.url + ",Evil0000", packSHA1: fields.sha1) == nil)
        #expect(LobbyModList(packURL: "https://example.com/pack.mrpack", packSHA1: fields.sha1) == nil)
        #expect(LobbyModList(packURL: nil, packSHA1: nil) == nil)
        let bad = "modrinth:../../x"
        #expect(LobbyModList(packURL: bad, packSHA1: LobbyModList.sha1(of: Data(bad.utf8))) == nil)
    }

    @Test func testListFromInstalledModsCountsHandAddedOnes() {
        let recorded = InstalledMod(fileName: "a.jar", isEnabled: true, record: ModRecord(
            fileName: "a.jar", projectId: "p", versionId: "VerA1234", title: "A", versionNumber: "1"))
        let manual = InstalledMod(fileName: "b.jar", isEnabled: true)
        let off = InstalledMod(fileName: "c.jar", isEnabled: false, record: ModRecord(
            fileName: "c.jar", projectId: "q", versionId: "VerC1234", title: "C", versionNumber: "1"))
        let list = LobbyModList(mods: [recorded, manual, off])
        #expect(list.versionIDs == ["VerA1234"])
        #expect(list.unsyncedCount == 1)
        #expect(LobbyModList(versionIDs: []).packFields == nil)
    }

    @Test func testUnsafeFileNamesAreRefused() {
        #expect(LobbySyncer.isSafe("sodium-1.0.jar"))
        #expect(!LobbySyncer.isSafe("../evil.jar"))
        #expect(!LobbySyncer.isSafe("dir/evil.jar"))
        #expect(!LobbySyncer.isSafe("evil.sh"))
        #expect(!LobbySyncer.isSafe(".hidden.jar"))
    }
}
