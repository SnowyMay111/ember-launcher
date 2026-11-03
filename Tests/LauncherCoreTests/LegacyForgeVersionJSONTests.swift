import Foundation
import Testing
@testable import LauncherCore

struct LegacyForgeVersionJSONTests {
    @Test func forge112UniversalJarWithEmptyURLDecodes() throws {
        let json = """
        {"id":"1.12.2-forge-14.23.5.2860","inheritsFrom":"1.12.2","mainClass":"net.minecraft.launchwrapper.Launch",
         "libraries":[{"name":"net.minecraftforge:forge:1.12.2-14.23.5.2860",
           "downloads":{"artifact":{"path":"net/minecraftforge/forge/1.12.2-14.23.5.2860/forge-1.12.2-14.23.5.2860.jar",
             "url":"","sha1":"029250575d3aa2cf80b56dffb66238a1eeaea2ac","size":4466148}}}]}
        """
        let version = try JSONDecoder().decode(VersionJSON.self, from: Data(json.utf8))
        let artifact = try #require(version.libraries?.first?.resolvedArtifact)
        #expect(artifact.path == "net/minecraftforge/forge/1.12.2-14.23.5.2860/forge-1.12.2-14.23.5.2860.jar")
        #expect(artifact.sha1 == "029250575d3aa2cf80b56dffb66238a1eeaea2ac")
    }
}

struct LegacyVersionMergeTests {
    @Test func resolveKeepsTheMacLWJGLWhenAnotherVersionIsListedFirst() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-merge-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = LauncherPaths(root: root)
        func lib(_ version: String, rules: String) -> String {
            """
            {"name":"org.lwjgl.lwjgl:lwjgl:\(version)","rules":\(rules),
             "downloads":{"artifact":{"path":"org/lwjgl/lwjgl/lwjgl/\(version)/lwjgl-\(version).jar","url":"https://example.com/\(version).jar","sha1":"aa","size":1}}}
            """
        }
        let parent = """
        {"id":"1.12.2","libraries":[
          \(lib("2.9.4-nightly-20150209", rules: #"[{"action":"allow"},{"action":"disallow","os":{"name":"osx"}}]"#)),
          \(lib("2.9.2-nightly-20140822", rules: #"[{"action":"allow","os":{"name":"osx"}}]"#))]}
        """
        let child = #"{"id":"1.12.2-forge-1","inheritsFrom":"1.12.2","mainClass":"x","libraries":[]}"#
        for (id, text) in [("1.12.2", parent), ("1.12.2-forge-1", child)] {
            try FileManager.default.createDirectory(at: paths.versionDir(id), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: paths.versionJSON(id))
        }
        let resolved = try VersionInstaller(paths: paths).resolve(versionId: "1.12.2-forge-1")
        let names = resolved.libraries.filter { RuleEvaluator.isAllowed(rules: $0.rules) }.map(\.name)
        #expect(names == ["org.lwjgl.lwjgl:lwjgl:2.9.2-nightly-20140822"])
    }
}
