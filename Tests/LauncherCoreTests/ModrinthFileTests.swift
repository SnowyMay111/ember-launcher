import Testing
import Foundation
@testable import LauncherCore

struct ModrinthFileTests {
    private func decode(_ filename: String) throws -> ModrinthFile {
        let json = """
        {"url":"https://cdn.modrinth.com/a.jar","filename":"\(filename)","size":1,"hashes":{"sha1":"x"},"primary":true}
        """
        return try JSONDecoder().decode(ModrinthFile.self, from: Data(json.utf8))
    }

    @Test func acceptsPlainName() throws {
        #expect(try decode("sodium-1.0.jar").filename == "sodium-1.0.jar")
    }

    @Test func rejectsUnsafeNames() {
        for name in ["../x.jar", "a/b.jar", "..", ".", "a\\\\b.jar"] {
            #expect(throws: DecodingError.self) { try decode(name) }
        }
    }
}
