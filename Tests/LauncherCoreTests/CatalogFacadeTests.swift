import Foundation
import Testing
@testable import LauncherCore

struct CatalogFacadeTests {
    private func withCatalogDefault(_ value: String?, _ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: CatalogSource.defaultsKey)
        defer {
            if let saved {
                defaults.set(saved, forKey: CatalogSource.defaultsKey)
            } else {
                defaults.removeObject(forKey: CatalogSource.defaultsKey)
            }
        }
        if let value {
            defaults.set(value, forKey: CatalogSource.defaultsKey)
        } else {
            defaults.removeObject(forKey: CatalogSource.defaultsKey)
        }
        try body()
    }

    private func hit(_ id: String, _ slug: String, _ title: String) -> ModrinthHit {
        ModrinthHit(projectId: id, slug: slug, title: title, description: "", author: "", downloads: 0)
    }

    private func page(_ prefix: String, _ count: Int, total: Int) -> ModrinthSearchResult {
        ModrinthSearchResult(hits: (0..<count).map { hit("\(prefix)\($0)", "\(prefix)-\($0)", "\(prefix) \($0)") }, totalHits: total)
    }

    @Test func currentDefaultsToBoth() {
        withCatalogDefault(nil) { #expect(CatalogSource.current == .both) }
        withCatalogDefault("not-a-source") { #expect(CatalogSource.current == .both) }
    }

    @Test func currentReadsRawValue() {
        for source in CatalogSource.allCases {
            withCatalogDefault(source.rawValue) { #expect(CatalogSource.current == source) }
        }
    }

    @Test func mergeInterleavesAndDropsDuplicates() {
        let modrinth = ModrinthSearchResult(hits: [hit("AA", "sodium", "Sodium"), hit("BB", "lithium", "Lithium")], totalHits: 10)
        let curse = ModrinthSearchResult(hits: [
            hit("cf:1", "jei", "Just Enough Items"),
            hit("cf:2", "sodium", "Sodium (CF)"),
            hit("cf:3", "lithium-cf", "LITHIUM")
        ], totalHits: 5)

        let merged = ModrinthClient.mergeSearchResults(modrinth: modrinth, curseforge: curse)

        #expect(merged.hits.map(\.projectId) == ["AA", "cf:1", "BB"])
        #expect(merged.totalHits == 15)
    }

    @Test func mergeKeepsTailOfLongerSide() {
        let modrinth = ModrinthSearchResult(hits: [hit("AA", "a", "A")], totalHits: 1)
        let curse = ModrinthSearchResult(hits: [hit("cf:1", "b", "B"), hit("cf:2", "c", "C")], totalHits: 2)

        let merged = ModrinthClient.mergeSearchResults(modrinth: modrinth, curseforge: curse)

        #expect(merged.hits.map(\.projectId) == ["AA", "cf:1", "cf:2"])
        #expect(ModrinthClient.mergeSearchResults(modrinth: curse, curseforge: modrinth).hits.count == 3)
    }

    @Test func cursorRoundtrip() {
        #expect(ModrinthClient.packCursor(modrinth: 0, curseforge: 0) == 0)
        #expect(ModrinthClient.unpackCursor(0) == (0, 0))
        let pairs = [(0, 0), (10, 0), (0, 10), (37, 41), (999_999, 999_999)]
        for (modrinth, curse) in pairs {
            let unpacked = ModrinthClient.unpackCursor(ModrinthClient.packCursor(modrinth: modrinth, curseforge: curse))
            #expect(unpacked.modrinth == modrinth)
            #expect(unpacked.curseforge == curse)
        }
    }

    @Test func bothPageAdvancesBothOffsets() {
        let first = ModrinthClient.assembleBothPage(
            modrinth: page("m", 10, total: 100), curseforge: page("c", 10, total: 50), limit: 20,
            modrinthOffset: 0, curseforgeOffset: 0, modrinthTotal: 100, curseforgeTotal: 50
        )
        #expect(first.hits.count == 20)
        #expect(first.totalHits == 150)
        #expect(first.nextOffset == ModrinthClient.packCursor(modrinth: 10, curseforge: 10))
        #expect(first.hasMore == true)

        let second = ModrinthClient.assembleBothPage(
            modrinth: page("n", 10, total: 100), curseforge: page("d", 10, total: 50), limit: 20,
            modrinthOffset: 10, curseforgeOffset: 10, modrinthTotal: 100, curseforgeTotal: 50
        )
        #expect(second.nextOffset == ModrinthClient.packCursor(modrinth: 20, curseforge: 20))
    }

    @Test func bothPageFollowsRemainingSide() {
        // Modrinth ran out; CurseForge got its quota plus a follow-up.
        let modrinthDone = ModrinthClient.assembleBothPage(
            modrinth: page("m", 5, total: 25), curseforge: page("c", 15, total: 50), limit: 20,
            modrinthOffset: 20, curseforgeOffset: 10, modrinthTotal: 25, curseforgeTotal: 50
        )
        #expect(modrinthDone.hits.count == 20)
        #expect(modrinthDone.nextOffset == ModrinthClient.packCursor(modrinth: 25, curseforge: 25))
        #expect(modrinthDone.hasMore == true)

        let curseDone = ModrinthClient.assembleBothPage(
            modrinth: page("m", 15, total: 100), curseforge: page("c", 5, total: 15), limit: 20,
            modrinthOffset: 10, curseforgeOffset: 10, modrinthTotal: 100, curseforgeTotal: 15
        )
        #expect(curseDone.nextOffset == ModrinthClient.packCursor(modrinth: 25, curseforge: 15))
        #expect(curseDone.hasMore == true)
    }

    @Test func bothPageEndsWhenBothExhausted() {
        let result = ModrinthClient.assembleBothPage(
            modrinth: page("m", 3, total: 23), curseforge: page("c", 4, total: 14), limit: 20,
            modrinthOffset: 20, curseforgeOffset: 10, modrinthTotal: 23, curseforgeTotal: 14
        )
        #expect(result.hits.count == 7)
        #expect(result.nextOffset == ModrinthClient.packCursor(modrinth: 23, curseforge: 14))
        #expect(result.hasMore == false)

        let empty = ModrinthClient.assembleBothPage(
            modrinth: page("m", 0, total: 23), curseforge: page("c", 0, total: 14), limit: 20,
            modrinthOffset: 5, curseforgeOffset: 5, modrinthTotal: 23, curseforgeTotal: 14
        )
        #expect(empty.hasMore == false)
    }

    @Test func bothPageWithFailedSide() {
        let result = ModrinthClient.assembleBothPage(
            modrinth: nil, curseforge: page("c", 10, total: 50), limit: 20,
            modrinthOffset: 30, curseforgeOffset: 20, modrinthTotal: 0, curseforgeTotal: 50
        )
        #expect(result.hits.count == 10)
        #expect(result.totalHits == 50)
        #expect(result.nextOffset == ModrinthClient.packCursor(modrinth: 30, curseforge: 30))
        #expect(result.hasMore == true)
    }

    @Test func bothPageDropsDuplicatesButAdvancesRawCounts() {
        let modrinth = ModrinthSearchResult(hits: [hit("AA", "sodium", "Sodium"), hit("BB", "lithium", "Lithium")], totalHits: 10)
        let curse = ModrinthSearchResult(hits: [hit("cf:1", "sodium", "Sodium"), hit("cf:2", "jei", "JEI")], totalHits: 10)

        let result = ModrinthClient.assembleBothPage(
            modrinth: modrinth, curseforge: curse, limit: 4,
            modrinthOffset: 0, curseforgeOffset: 0, modrinthTotal: 10, curseforgeTotal: 10
        )

        #expect(result.hits.map(\.projectId) == ["AA", "BB", "cf:2"])
        #expect(result.nextOffset == ModrinthClient.packCursor(modrinth: 2, curseforge: 2))
        #expect(result.hasMore == true)
    }

    @Test func sortFieldMapping() {
        #expect(ModrinthClient.curseForgeSortField(sortBy: "relevance", query: "sodium") == 1)
        #expect(ModrinthClient.curseForgeSortField(sortBy: "relevance", query: "") == 2)
        #expect(ModrinthClient.curseForgeSortField(sortBy: "downloads", query: "x") == 6)
        #expect(ModrinthClient.curseForgeSortField(sortBy: "follows", query: "x") == 2)
        #expect(ModrinthClient.curseForgeSortField(sortBy: "newest", query: "x") == 11)
        #expect(ModrinthClient.curseForgeSortField(sortBy: "updated", query: "x") == 3)
        #expect(ModrinthClient.curseForgeSortField(sortBy: nil, query: "") == 6)
        #expect(ModrinthClient.curseForgeSortField(sortBy: nil, query: "x") == 1)
    }

    @Test func classIdMapping() {
        #expect(CurseForgeClient.classId(projectType: "mod") == 6)
        #expect(CurseForgeClient.classId(projectType: "modpack") == 4471)
        #expect(CurseForgeClient.classId(projectType: "resourcepack") == 12)
        #expect(CurseForgeClient.classId(projectType: "shader") == 6552)
        #expect(CurseForgeClient.classId(projectType: "datapack") == nil)
        #expect(CurseForgeClient.classId(projectType: "") == nil)
    }

    @Test func distributionBlockedDescription() {
        let error = CurseForgeError.distributionBlocked(project: "OptiFine", url: URL(string: "https://www.curseforge.com/minecraft/mc-mods/optifine"))
        #expect(error.errorDescription == "The author of 'OptiFine' does not allow downloads outside CurseForge. Open it on CurseForge: https://www.curseforge.com/minecraft/mc-mods/optifine")
    }
}
