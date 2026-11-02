import Foundation
import Testing
@testable import LauncherCore

@Suite struct CurseForgePackTests {
    private static let manifest = """
    {"minecraft":{"version":"1.20.1","modLoaders":[{"id":"forge-47.2.0","primary":true}]},"manifestType":"minecraftModpack","name":"Test Pack","version":"1.0","author":"me","files":[{"projectID":238222,"fileID":4521234,"required":true},{"projectID":238223,"fileID":4521235,"required":false}],"overrides":"overrides"}
    """

    /// Zips `files` with /usr/bin/zip and extracts the archive the way the importer does; returns the extracted folder.
    private func makeExtractedPack(_ files: [String: String]) throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("cfpack-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("src", isDirectory: true)
        for (path, content) in files {
            let url = source.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: url)
        }
        let archive = root.appendingPathComponent("pack.zip")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = source
        zip.arguments = ["-q", "-r", archive.path] + Set(files.keys.map { String($0.split(separator: "/")[0]) }).sorted()
        try zip.run()
        zip.waitUntilExit()
        #expect(zip.terminationStatus == 0)

        #expect(try ZipArchive.entries(of: archive).contains("manifest.json"))
        let out = root.appendingPathComponent("out", isDirectory: true)
        try fm.createDirectory(at: out, withIntermediateDirectories: true)
        try ZipArchive.extract(archive, to: out, maxBytes: 1 << 20)
        return out
    }

    @Test func detectsAndParsesCurseForgePack() throws {
        let dir = try makeExtractedPack(["manifest.json": Self.manifest, "overrides/config/a.txt": "x"])
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }

        let manifest = try #require(try ModpackManager.curseForgeManifest(in: dir))
        #expect(manifest.name == "Test Pack")
        #expect(manifest.version == "1.0")
        #expect(manifest.overrides == "overrides")
        #expect(manifest.files?.map(\.fileID) == [4521234, 4521235])

        let target = try ModpackManager.curseForgeTarget(of: manifest)
        #expect(target.minecraftVersion == "1.20.1")
        #expect(target.loader == "forge")
        #expect(target.loaderVersion == "47.2.0")
    }

    @Test func modrinthIndexKeepsMrpackPath() throws {
        let dir = try makeExtractedPack(["manifest.json": Self.manifest, "modrinth.index.json": "{}"])
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        #expect(try ModpackManager.curseForgeManifest(in: dir) == nil)
    }

    @Test func otherManifestTypeIsIgnored() throws {
        let dir = try makeExtractedPack(["manifest.json": #"{"manifestType":"somethingElse"}"#])
        defer { try? FileManager.default.removeItem(at: dir.deletingLastPathComponent()) }
        #expect(try ModpackManager.curseForgeManifest(in: dir) == nil)
    }

    @Test func parsesLoaderIDs() {
        let forge = ModpackManager.parseCurseForgeLoaderID("forge-47.2.0")
        #expect(forge?.loader == "forge")
        #expect(forge?.version == "47.2.0")
        let neoForge = ModpackManager.parseCurseForgeLoaderID("neoforge-21.1.5")
        #expect(neoForge?.loader == "neoforge")
        #expect(neoForge?.version == "21.1.5")
        let fabric = ModpackManager.parseCurseForgeLoaderID("fabric-0.16.9")
        #expect(fabric?.loader == "fabric")
        #expect(fabric?.version == "0.16.9")
        #expect(ModpackManager.parseCurseForgeLoaderID("liteloader-1.0") == nil)
        #expect(ModpackManager.parseCurseForgeLoaderID("forge-") == nil)
    }

    @Test func blockedFileWarning() {
        let page = URL(string: "https://www.curseforge.com/minecraft/mc-mods/jei")
        #expect(
            ModpackManager.blockedDownloadWarning(name: "JEI", downloadURL: nil, distributionAllowed: false, pageURL: page, projectID: 238222)
                == "JEI: download is blocked by the author, get it on CurseForge: https://www.curseforge.com/minecraft/mc-mods/jei"
        )
        #expect(
            ModpackManager.blockedDownloadWarning(name: "JEI", downloadURL: nil, distributionAllowed: false, pageURL: nil, projectID: 238222)
                == "JEI: download is blocked by the author, get it on CurseForge: https://www.curseforge.com/projects/238222"
        )
        #expect(ModpackManager.blockedDownloadWarning(name: "JEI", downloadURL: "https://edge.forgecdn.net/files/1/2/a.jar", distributionAllowed: false, pageURL: page, projectID: 1) == nil)
        #expect(ModpackManager.blockedDownloadWarning(name: "JEI", downloadURL: nil, distributionAllowed: nil, pageURL: page, projectID: 1) == nil)
        #expect(ModpackManager.blockedDownloadWarning(name: "JEI", downloadURL: nil, distributionAllowed: true, pageURL: page, projectID: 1) == nil)
    }
}
