import Foundation
import Testing
@testable import LauncherCore

struct CurseForgeTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test func mapsModWithLogoAuthorsAndCategories() throws {
        let json = """
        {
          "id": 238222,
          "name": "Just Enough Items (JEI)",
          "slug": "jei",
          "summary": "View Items and Recipes",
          "downloadCount": 345678901,
          "thumbsUpCount": 1200,
          "logo": {
            "thumbnailUrl": "https://media.forgecdn.net/avatars/thumbnails/29/69/64/64/635838945588716414.jpeg",
            "url": "https://media.forgecdn.net/avatars/29/69/635838945588716414.jpeg"
          },
          "authors": [{ "name": "mezz" }, { "name": "helper" }],
          "categories": [
            { "slug": "api-library", "name": "API and Library" },
            { "slug": "utility-qol", "name": "Utility & QoL" }
          ],
          "classId": 6,
          "allowModDistribution": true,
          "links": { "websiteUrl": "https://www.curseforge.com/minecraft/mc-mods/jei" }
        }
        """

        let mod = try decode(CurseForgeMod.self, json)
        let hit = CurseForgeClient.mapMod(mod)
        #expect(hit.projectId == "cf:238222")
        #expect(hit.slug == "jei")
        #expect(hit.title == "Just Enough Items (JEI)")
        #expect(hit.description == "View Items and Recipes")
        #expect(hit.author == "mezz")
        #expect(hit.iconURL?.absoluteString == "https://media.forgecdn.net/avatars/thumbnails/29/69/64/64/635838945588716414.jpeg")
        #expect(hit.downloads == 345678901)
        #expect(hit.categories == ["api-library", "utility-qol"])
        #expect(hit.follows == 1200)

        let project = CurseForgeClient.mapProject(mod)
        #expect(project.id == "cf:238222")
        #expect(project.projectType == "mod")
        #expect(mod.websiteURL?.absoluteString == "https://www.curseforge.com/minecraft/mc-mods/jei")
    }

    @Test func mapsClassIdToProjectType() {
        #expect(CurseForgeClient.projectType(classId: 6) == "mod")
        #expect(CurseForgeClient.projectType(classId: 4471) == "modpack")
        #expect(CurseForgeClient.projectType(classId: 12) == "resourcepack")
        #expect(CurseForgeClient.projectType(classId: 6552) == "shader")
        #expect(CurseForgeClient.projectType(classId: nil) == "mod")
    }

    @Test func fileWithNullDownloadURLUsesCDNOnlyWhenAllowed() throws {
        let json = """
        {
          "id": 4587214,
          "modId": 238222,
          "displayName": "jei-1.20.1-forge-15.2.0.27",
          "fileName": "jei-1.20.1-forge-15.2.0.27.jar",
          "releaseType": 1,
          "fileDate": "2023-08-01T12:00:00.000Z",
          "fileLength": 1234567,
          "downloadUrl": null,
          "gameVersions": ["1.20.1", "Forge"],
          "hashes": [
            { "value": "d41d8cd98f00b204e9800998ecf8427e", "algo": 2 },
            { "value": "da39a3ee5e6b4b0d3255bfef95601890afd80709", "algo": 1 }
          ],
          "dependencies": []
        }
        """

        let file = try decode(CurseForgeFile.self, json)
        let allowed = CurseForgeClient.mapFile(file, modId: 238222, distributionAllowed: true)
        #expect(allowed.id == "cf:238222:4587214")
        #expect(allowed.projectId == "cf:238222")
        #expect(allowed.versionType == "release")
        #expect(allowed.datePublished == "2023-08-01T12:00:00.000Z")
        #expect(allowed.files.count == 1)
        let primary = try #require(allowed.primaryFile)
        #expect(primary.url.absoluteString == "https://edge.forgecdn.net/files/4587/214/jei-1.20.1-forge-15.2.0.27.jar")
        #expect(primary.filename == "jei-1.20.1-forge-15.2.0.27.jar")
        #expect(primary.size == 1234567)
        #expect(primary.sha1 == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
        #expect(primary.primary)

        let blocked = CurseForgeClient.mapFile(file, modId: 238222, distributionAllowed: false)
        #expect(blocked.files.isEmpty)
    }

    @Test func fileWithURLMapsEveryRelationType() throws {
        let json = """
        {
          "id": 5000001,
          "modId": 306612,
          "displayName": "Fabric API 0.92.0",
          "fileName": "fabric-api-0.92.0+1.20.1.jar",
          "releaseType": 2,
          "fileDate": "2024-01-10T08:30:00.000Z",
          "fileLength": 2048,
          "downloadUrl": "https://edge.forgecdn.net/files/5000/1/fabric-api-0.92.0+1.20.1.jar",
          "gameVersions": ["1.20.1"],
          "hashes": [{ "value": "abc123", "algo": 1 }],
          "dependencies": [
            { "modId": 11, "relationType": 1 },
            { "modId": 22, "relationType": 2 },
            { "modId": 33, "relationType": 3 },
            { "modId": 44, "relationType": 4 },
            { "modId": 55, "relationType": 5 },
            { "modId": 66, "relationType": 6 }
          ]
        }
        """

        let file = try decode(CurseForgeFile.self, json)
        let version = CurseForgeClient.mapFile(file, modId: 306612, distributionAllowed: false)
        #expect(version.versionType == "beta")
        #expect(version.files.first?.url.absoluteString == "https://edge.forgecdn.net/files/5000/1/fabric-api-0.92.0+1.20.1.jar")
        #expect(version.files.first?.sha1 == "abc123")
        #expect(version.dependencies == [
            ModrinthDependency(projectId: "cf:11", type: .embedded),
            ModrinthDependency(projectId: "cf:22", type: .optional),
            ModrinthDependency(projectId: "cf:33", type: .required),
            ModrinthDependency(projectId: "cf:55", type: .incompatible),
            ModrinthDependency(projectId: "cf:66", type: .embedded)
        ])
    }

    @Test func splitsLoaderNamesFromGameVersions() throws {
        let json = """
        {
          "id": 6000123,
          "modId": 1,
          "displayName": "Sodium 0.5.3",
          "fileName": "sodium-0.5.3.jar",
          "releaseType": 3,
          "fileDate": "2024-02-01T00:00:00.000Z",
          "fileLength": 100,
          "downloadUrl": "https://example.com/sodium-0.5.3.jar",
          "gameVersions": ["1.20.1", "Fabric", "Quilt", "Client", "1.20", "NeoForge", "Server", "fabric"],
          "hashes": [],
          "dependencies": []
        }
        """

        let version = CurseForgeClient.mapFile(try decode(CurseForgeFile.self, json), modId: 1, distributionAllowed: true)
        #expect(version.gameVersions == ["1.20.1", "1.20"])
        #expect(version.loaders == ["fabric", "quilt", "neoforge"])
        #expect(version.versionType == "alpha")
        #expect(version.files.first?.sha1 == nil)
    }

    @Test func skipsUnsafeFileNames() throws {
        let json = """
        {
          "id": 7000000,
          "modId": 2,
          "displayName": "Evil",
          "fileName": "../evil.jar",
          "releaseType": 1,
          "fileDate": "2024-03-01T00:00:00.000Z",
          "fileLength": 1,
          "downloadUrl": "https://example.com/evil.jar",
          "gameVersions": ["1.20.1"],
          "hashes": [],
          "dependencies": []
        }
        """

        let version = CurseForgeClient.mapFile(try decode(CurseForgeFile.self, json), modId: 2, distributionAllowed: true)
        #expect(version.files.isEmpty)
    }

    @Test func parsesIDs() {
        #expect(CurseForgeClient.isCurseForgeID("cf:238222"))
        #expect(!CurseForgeClient.isCurseForgeID("AANobbMI"))
        #expect(CurseForgeClient.numericID("cf:123") == 123)
        #expect(CurseForgeClient.numericID("123") == 123)
        #expect(CurseForgeClient.numericID("cf:abc") == nil)
        #expect(CurseForgeClient.numericID("AANobbMI") == nil)
        #expect(CurseForgeClient.numericID("cf:1:2") == nil)

        let parsed = CurseForgeClient.parseVersionID("cf:238222:4587214")
        #expect(parsed?.modId == 238222)
        #expect(parsed?.fileId == 4587214)
        #expect(CurseForgeClient.parseVersionID("cf:238222") == nil)
        #expect(CurseForgeClient.parseVersionID("238222:4587214") == nil)
    }

    @Test func mapsLoaderTypes() {
        #expect(CurseForgeClient.modLoaderType("Forge") == 1)
        #expect(CurseForgeClient.modLoaderType("fabric") == 4)
        #expect(CurseForgeClient.modLoaderType("QUILT") == 5)
        #expect(CurseForgeClient.modLoaderType("neoforge") == 6)
        #expect(CurseForgeClient.modLoaderType("vanilla") == nil)
        #expect(CurseForgeClient.modLoaderType(nil) == nil)
        #expect(CurseForgeClient.loaderName(1) == "forge")
        #expect(CurseForgeClient.loaderName(4) == "fabric")
        #expect(CurseForgeClient.loaderName(5) == "quilt")
        #expect(CurseForgeClient.loaderName(6) == "neoforge")
        #expect(CurseForgeClient.loaderName(0) == nil)
    }

    @Test func firstSearchPageOmitsIndex() {
        let first = CurseForgeClient.searchQuery(
            query: "SevTech: Ages", classId: 4471, gameVersion: nil, loader: nil, sortField: 1, limit: 10, offset: 0
        )
        #expect(!first.contains { $0.name == "index" })
        #expect(first.contains { $0.name == "searchFilter" && $0.value == "SevTech: Ages" })
        let next = CurseForgeClient.searchQuery(
            query: "SevTech: Ages", classId: 4471, gameVersion: nil, loader: nil, sortField: 1, limit: 10, offset: 10
        )
        #expect(next.contains { $0.name == "index" && $0.value == "10" })
    }
}
