import Foundation

public typealias VersionManifestEntry = ManifestVersion

public enum VersionInstallerError: Error, LocalizedError, Sendable {
    case versionNotFound(String)
    case missingInheritedVersion(String)
    case missingAssetIndex
    case missingClientDownload

    public var errorDescription: String? {
        switch self {
        case .versionNotFound(let id):
            return "Version '\(id)' not found in manifest"
        case .missingInheritedVersion(let id):
            return "Inherited version '\(id)' is not installed"
        case .missingAssetIndex:
            return "Version is missing asset index"
        case .missingClientDownload:
            return "Version is missing client download"
        }
    }
}

public struct ResolvedVersion: Codable, Sendable {
    public let id: String
    public let clientJarID: String
    public let mainClass: String?
    public let arguments: VersionArguments?
    public let assetIndex: AssetIndexReference?
    public let assets: String?
    public let downloads: VersionDownloads?
    public let libraries: [Library]
    public let javaVersion: JavaVersionReference?

    public init(
        id: String,
        clientJarID: String,
        mainClass: String? = nil,
        arguments: VersionArguments? = nil,
        assetIndex: AssetIndexReference? = nil,
        assets: String? = nil,
        downloads: VersionDownloads? = nil,
        libraries: [Library] = [],
        javaVersion: JavaVersionReference? = nil
    ) {
        self.id = id
        self.clientJarID = clientJarID
        self.mainClass = mainClass
        self.arguments = arguments
        self.assetIndex = assetIndex
        self.assets = assets
        self.downloads = downloads
        self.libraries = libraries
        self.javaVersion = javaVersion
    }
}

private struct AssetIndexData: Decodable {
    struct AssetObject: Decodable {
        let hash: String
        let size: Int
    }
    let objects: [String: AssetObject]
}

public final class VersionInstaller: Sendable {
    public let paths: LauncherPaths
    public let downloader: Downloader

    public init(paths: LauncherPaths, downloader: Downloader = Downloader()) {
        self.paths = paths
        self.downloader = downloader
    }

    public func fetchManifest() async throws -> VersionManifest {
        let manifestURL = URL(string: "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")!
        return try await downloader.fetchJSON(VersionManifest.self, from: manifestURL)
    }

    public func listVersions() async throws -> [VersionManifestEntry] {
        let manifest = try await fetchManifest()
        return manifest.versions
    }

    public func install(
        versionId: String,
        progress: @escaping @Sendable (String, DownloadProgress) -> Void
    ) async throws -> VersionJSON {
        try paths.ensureDirectories()

        let versions = try await listVersions()
        guard let entry = versions.first(where: { $0.id == versionId }) else {
            throw VersionInstallerError.versionNotFound(versionId)
        }

        let jsonDest = paths.versionJSON(versionId)
        try await downloader.download(url: entry.url, to: jsonDest, sha1: entry.sha1, size: nil)

        let versionJSON = try installFromLocalJSON(versionId)

        // 1. Download libraries allowed by RuleEvaluator
        if let libraries = versionJSON.libraries {
            var libraryItems: [DownloadItem] = []
            for lib in libraries {
                guard RuleEvaluator.isAllowed(rules: lib.rules) else { continue }
                guard let artifact = lib.resolvedArtifact else { continue }
                let dest = paths.libraries.appendingPathComponent(artifact.path)
                libraryItems.append(DownloadItem(
                    url: artifact.url,
                    dest: dest,
                    sha1: artifact.sha1,
                    size: artifact.size
                ))
            }
            try await downloader.downloadAll(libraryItems) { prog in
                progress("libraries", prog)
            }
        }

        // 2. Download asset index and all indexed asset objects
        if let assetIndexRef = versionJSON.assetIndex {
            let indexDest = paths.assetsIndexes.appendingPathComponent("\(assetIndexRef.id).json")
            try await downloader.download(
                url: assetIndexRef.url,
                to: indexDest,
                sha1: assetIndexRef.sha1,
                size: assetIndexRef.size
            )

            let indexData = try Data(contentsOf: indexDest)
            let assetIndex = try JSONDecoder().decode(AssetIndexData.self, from: indexData)

            var assetItems: [DownloadItem] = []
            for (_, object) in assetIndex.objects {
                let hash = object.hash
                let first2 = String(hash.prefix(2))
                guard let objectURL = URL(string: "https://resources.download.minecraft.net/\(first2)/\(hash)") else {
                    continue
                }
                let objectDest = paths.assetsObjects
                    .appendingPathComponent(first2, isDirectory: true)
                    .appendingPathComponent(hash)
                assetItems.append(DownloadItem(
                    url: objectURL,
                    dest: objectDest,
                    sha1: hash,
                    size: object.size
                ))
            }

            try await downloader.downloadAll(assetItems) { prog in
                progress("assets", prog)
            }
        }

        // 3. Download client JAR
        if let client = versionJSON.downloads?.client {
            let jarDest = paths.versionJAR(versionId)
            let clientItem = DownloadItem(
                url: client.url,
                dest: jarDest,
                sha1: client.sha1,
                size: client.size
            )
            try await downloader.downloadAll([clientItem]) { prog in
                progress("client", prog)
            }
        }

        return versionJSON
    }

    public func installLibraries(
        of version: ResolvedVersion,
        progress: @escaping @Sendable (DownloadProgress) -> Void = { _ in }
    ) async throws {
        try paths.ensureDirectories()
        var libraryItems: [DownloadItem] = []
        for lib in version.libraries {
            guard RuleEvaluator.isAllowed(rules: lib.rules) else { continue }
            guard let artifact = lib.resolvedArtifact else { continue }
            let dest = paths.libraries.appendingPathComponent(artifact.path)
            libraryItems.append(DownloadItem(
                url: artifact.url,
                dest: dest,
                sha1: artifact.sha1,
                size: artifact.size
            ))
        }
        try await downloader.downloadAll(libraryItems, progress: progress)
    }

    public func installFromLocalJSON(_ id: String) throws -> VersionJSON {
        let fileURL = paths.versionJSON(id)
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(VersionJSON.self, from: data)
    }

    public func resolve(versionId: String) throws -> ResolvedVersion {
        let child = try installFromLocalJSON(versionId)

        guard let parentId = child.inheritsFrom else {
            return ResolvedVersion(
                id: child.id,
                clientJarID: child.id,
                mainClass: child.mainClass,
                arguments: child.arguments,
                assetIndex: child.assetIndex,
                assets: child.assets,
                downloads: child.downloads,
                libraries: child.libraries ?? [],
                javaVersion: child.javaVersion
            )
        }

        let parent = try installFromLocalJSON(parentId)

        let parentLibs = parent.libraries ?? []
        let childLibs = child.libraries ?? []

        let parentGAs = Set(parentLibs.map { Self.groupArtifact(for: $0) })
        let childGAs = Set(childLibs.map { Self.groupArtifact(for: $0) })
        let duplicateGAs = parentGAs.intersection(childGAs)

        var mergedLibs: [Library] = []
        var seenGAs = Set<String>()

        // Child takes precedence and comes first for duplicates of same group:artifact
        for lib in childLibs {
            let ga = Self.groupArtifact(for: lib)
            if duplicateGAs.contains(ga) {
                if seenGAs.insert(ga).inserted {
                    mergedLibs.append(lib)
                }
            }
        }

        for lib in parentLibs {
            let ga = Self.groupArtifact(for: lib)
            if !duplicateGAs.contains(ga) {
                if seenGAs.insert(ga).inserted {
                    mergedLibs.append(lib)
                }
            }
        }

        for lib in childLibs {
            let ga = Self.groupArtifact(for: lib)
            if !duplicateGAs.contains(ga) {
                if seenGAs.insert(ga).inserted {
                    mergedLibs.append(lib)
                }
            }
        }

        let parentGame = parent.arguments?.game ?? []
        let childGame = child.arguments?.game ?? []
        let mergedGame = parentGame + childGame

        let parentJvm = parent.arguments?.jvm ?? []
        let childJvm = child.arguments?.jvm ?? []
        let mergedJvm = parentJvm + childJvm

        let mergedArguments: VersionArguments?
        if parent.arguments == nil && child.arguments == nil {
            mergedArguments = nil
        } else {
            mergedArguments = VersionArguments(
                game: mergedGame.isEmpty ? nil : mergedGame,
                jvm: mergedJvm.isEmpty ? nil : mergedJvm
            )
        }

        return ResolvedVersion(
            id: child.id,
            clientJarID: parent.id,
            mainClass: child.mainClass ?? parent.mainClass,
            arguments: mergedArguments,
            assetIndex: child.assetIndex ?? parent.assetIndex,
            assets: child.assets ?? parent.assets,
            downloads: child.downloads ?? parent.downloads,
            libraries: mergedLibs,
            javaVersion: child.javaVersion ?? parent.javaVersion
        )
    }

    private static func groupArtifact(for library: Library) -> String {
        var coords = library.name
        if let atIndex = coords.firstIndex(of: "@") {
            coords = String(coords[..<atIndex])
        }
        let parts = coords.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count > 3 {
            // The classifier is part of the identity: LWJGL ships natives-macos and natives-macos-arm64 next to the main jar.
            return "\(parts[0]):\(parts[1]):\(parts[3])"
        }
        if parts.count >= 2 {
            return "\(parts[0]):\(parts[1])"
        }
        return library.name
    }
}
