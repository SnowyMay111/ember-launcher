import Foundation

/// Minecraft up to 1.16 uses LWJGL 2, which crashes the Intel Java on current macOS (`setView` inside `Display.create`).
/// On Apple Silicon Ember therefore swaps LWJGL 2 for the arm64 build of MinecraftMachina (the one ManyMC and Prism use) and runs those versions on Azul's Java 8 for arm64.
enum LegacyMacArm {
    private static let marker = "mmachina"
    private static let mojangLibraries = "https://libraries.minecraft.net/"
    private static let nativesVersion = "2.9.4-nightly-20150209-mmachina.2"

    static var hostIsArm64: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    /// True for a library list that went through `patched`, so Java for arm64 has to be used with it.
    static func isPatched(_ libraries: [Library]) -> Bool {
        libraries.contains { $0.name.contains(marker) }
    }

    private static func isLWJGL2(_ library: Library) -> Bool {
        ["org.lwjgl.lwjgl:lwjgl:", "org.lwjgl.lwjgl:lwjgl_util:", "org.lwjgl.lwjgl:lwjgl-platform:"].contains { library.name.hasPrefix($0) }
    }

    static func patched(_ libraries: [Library], hostIsArm64: Bool = LegacyMacArm.hostIsArm64) -> [Library] {
        guard hostIsArm64, let first = libraries.firstIndex(where: isLWJGL2) else { return libraries }
        var result = libraries.filter { !isLWJGL2($0) }
        let insertAt = min(libraries[..<first].filter { !isLWJGL2($0) }.count, result.count)
        result.insert(contentsOf: replacements, at: insertAt)
        // JNA 4.x has no arm64 library (Minecraft 1.12 died in `Native.<clinit>` with a dlopen error); 5.8.0 has one.
        return result.map { $0.name.hasPrefix("net.java.dev.jna:jna:") ? jna : $0 }
    }

    private static let jna = Library(
        name: "net.java.dev.jna:jna:5.8.0",
        downloads: LibraryDownloads(artifact: DownloadArtifact(
            path: "net/java/dev/jna/jna/5.8.0/jna-5.8.0.jar",
            sha1: "3551d8d827e54858214107541d3aff9c615cb615", size: 1729586,
            url: URL(string: "https://repo1.maven.org/maven2/net/java/dev/jna/jna/5.8.0/jna-5.8.0.jar")!
        ))
    )

    private static var replacements: [Library] {
        let base = "org/lwjgl/lwjgl"
        let jar = Library(
            name: "org.lwjgl.lwjgl:lwjgl:2.9.4-nightly-20150209",
            downloads: LibraryDownloads(artifact: DownloadArtifact(
                path: "\(base)/lwjgl/2.9.4-nightly-20150209/lwjgl-2.9.4-nightly-20150209.jar",
                sha1: "697517568c68e78ae0b4544145af031c81082dfe", size: 1047168,
                url: URL(string: "\(mojangLibraries)\(base)/lwjgl/2.9.4-nightly-20150209/lwjgl-2.9.4-nightly-20150209.jar")!
            ))
        )
        let util = Library(
            name: "org.lwjgl.lwjgl:lwjgl_util:2.9.4-nightly-20150209",
            downloads: LibraryDownloads(artifact: DownloadArtifact(
                path: "\(base)/lwjgl_util/2.9.4-nightly-20150209/lwjgl_util-2.9.4-nightly-20150209.jar",
                sha1: "d51a7c040a721d13efdfbd34f8b257b2df882ad0", size: 173887,
                url: URL(string: "\(mojangLibraries)\(base)/lwjgl_util/2.9.4-nightly-20150209/lwjgl_util-2.9.4-nightly-20150209.jar")!
            ))
        )
        let natives = Library(
            name: "org.lwjgl.lwjgl:lwjgl-platform:\(nativesVersion)",
            downloads: LibraryDownloads(classifiers: ["natives-osx": DownloadArtifact(
                path: "\(base)/lwjgl-platform/\(nativesVersion)/lwjgl-platform-\(nativesVersion)-natives-osx.jar",
                sha1: "eff546c0b319d6ffc7a835652124c18089c67f36", size: 488316,
                url: URL(string: "https://github.com/MinecraftMachina/lwjgl/releases/download/2.9.4-20150209-mmachina.2/lwjgl-platform-2.9.4-nightly-20150209-natives-osx.jar")!
            )]),
            natives: ["osx": "natives-osx"],
            extract: LibraryExtract(exclude: ["META-INF/"])
        )
        return [jar, util, natives]
    }
}
