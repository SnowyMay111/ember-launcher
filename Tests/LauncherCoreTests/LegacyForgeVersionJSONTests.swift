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
        // On Apple Silicon LegacyMacArm swaps in the arm64 LWJGL 2.9.4; elsewhere the macOS-only 2.9.2 must survive the merge.
        let jars = names.filter { $0.hasPrefix("org.lwjgl.lwjgl:lwjgl:") }
        #if arch(arm64)
        #expect(jars == ["org.lwjgl.lwjgl:lwjgl:2.9.4-nightly-20150209"])
        #else
        #expect(jars == ["org.lwjgl.lwjgl:lwjgl:2.9.2-nightly-20140822"])
        #endif
    }
}

struct LegacyMacArmTests {
    private func lib(_ name: String) -> Library { Library(name: name) }

    @Test func appleSiliconSwapsLWJGL2ForTheArm64Build() {
        let libs = [lib("a:first:1"), lib("org.lwjgl.lwjgl:lwjgl:2.9.2-nightly-20140822"), lib("org.lwjgl.lwjgl:lwjgl_util:2.9.2-nightly-20140822"),
                    lib("org.lwjgl.lwjgl:lwjgl-platform:2.9.2-nightly-20140822"), lib("net.java.dev.jna:jna:4.4.0"), Library(name: "ca.weblite:java-objc-bridge:1.0.0", natives: ["osx": "natives-osx"]), lib("ca.weblite:java-objc-bridge:1.0.0"), lib("b:last:1")]
        let patched = LegacyMacArm.patched(libs, hostIsArm64: true)
        #expect(patched.map(\.name).first == "a:first:1")
        #expect(patched.map(\.name).last == "b:last:1")
        #expect(patched.contains { $0.name == "org.lwjgl.lwjgl:lwjgl:2.9.4-nightly-20150209" })
        #expect(!patched.contains { $0.name.contains("2.9.2") })
        #expect(patched.map(\.name).contains("net.java.dev.jna:jna:5.8.0"))
        #expect(!patched.contains { $0.name == "net.java.dev.jna:jna:4.4.0" })
        #expect(patched.map(\.name).contains("ca.weblite:java-objc-bridge:1.1.0-mmachina.1"))
        #expect(patched.filter { $0.name.hasPrefix("ca.weblite:java-objc-bridge") }.count == 1)
        #expect(LegacyMacArm.isPatched(patched))
        let natives = patched.first { $0.name.contains("mmachina") }
        #expect(natives?.nativeClassifier == "natives-osx")
        #expect(natives?.resolvedArtifact?.url.host == "github.com")
    }

    @Test func intelAndModernVersionsAreLeftAlone() {
        let legacy = [lib("org.lwjgl.lwjgl:lwjgl:2.9.2-nightly-20140822")]
        #expect(LegacyMacArm.patched(legacy, hostIsArm64: false).map(\.name) == legacy.map(\.name))
        let modern = [lib("org.lwjgl:lwjgl:3.3.3")]
        #expect(LegacyMacArm.patched(modern, hostIsArm64: true).map(\.name) == modern.map(\.name))
        #expect(!LegacyMacArm.isPatched(modern))
    }
}
