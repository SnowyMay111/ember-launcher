import Foundation

public struct MrpackEnv: Codable, Sendable, Equatable {
    public var client: String
    public var server: String

    public init(client: String, server: String) {
        self.client = client
        self.server = server
    }
}

public struct MrpackFile: Codable, Sendable, Equatable {
    public var path: String
    public var hashes: [String: String]
    public var env: MrpackEnv?
    public var downloads: [String]
    public var fileSize: Int

    public init(
        path: String,
        hashes: [String: String],
        env: MrpackEnv? = nil,
        downloads: [String],
        fileSize: Int
    ) {
        self.path = path
        self.hashes = hashes
        self.env = env
        self.downloads = downloads
        self.fileSize = fileSize
    }
}

public struct MrpackIndex: Codable, Sendable, Equatable {
    public var formatVersion: Int
    public var game: String
    public var versionId: String
    public var name: String
    public var summary: String?
    public var files: [MrpackFile]
    public var dependencies: [String: String]

    public init(
        formatVersion: Int = 1,
        game: String = "minecraft",
        versionId: String,
        name: String,
        summary: String? = nil,
        files: [MrpackFile] = [],
        dependencies: [String: String] = [:]
    ) {
        self.formatVersion = formatVersion
        self.game = game
        self.versionId = versionId
        self.name = name
        self.summary = summary
        self.files = files
        self.dependencies = dependencies
    }
}

public struct MrpackExportOptions: Sendable {
    public var includeConfig: Bool
    public var includeOptions: Bool
    public var includeResourcePacks: Bool
    public var includeShaders: Bool
    public var versionLabel: String
    public var summary: String?

    public init(
        includeConfig: Bool = true,
        includeOptions: Bool = true,
        includeResourcePacks: Bool = true,
        includeShaders: Bool = true,
        versionLabel: String = "1.0.0",
        summary: String? = nil
    ) {
        self.includeConfig = includeConfig
        self.includeOptions = includeOptions
        self.includeResourcePacks = includeResourcePacks
        self.includeShaders = includeShaders
        self.versionLabel = versionLabel
        self.summary = summary
    }
}

public struct MrpackExportReport: Sendable {
    public let archive: URL
    public let modsLinked: Int
    public let modsBundled: Int
    public let overrideFiles: Int
    public let warnings: [String]

    public init(
        archive: URL,
        modsLinked: Int,
        modsBundled: Int,
        overrideFiles: Int,
        warnings: [String]
    ) {
        self.archive = archive
        self.modsLinked = modsLinked
        self.modsBundled = modsBundled
        self.overrideFiles = overrideFiles
        self.warnings = warnings
    }
}

public enum ModpackError: Error, LocalizedError, Sendable {
    case unsupportedLoader(String)
    case instanceNotFound(String)
    case invalidArchive(String)
    case unsafePath(String)
    case unsupportedFormat(Int)
    case missingDependency(String)
    case blockedDownload(String)
    case archiveTooLarge(Int64)

    public var errorDescription: String? {
        switch self {
        case .unsupportedLoader(let loader):
            return "Unsupported mod loader: \(loader)"
        case .instanceNotFound(let name):
            return "Instance '\(name)' not found"
        case .invalidArchive(let reason):
            return "Invalid modpack archive: \(reason)"
        case .unsafePath(let path):
            return "Unsafe file path in modpack: \(path)"
        case .unsupportedFormat(let version):
            return "Unsupported modpack format version: \(version)"
        case .missingDependency(let dependency):
            return "Missing modpack dependency: \(dependency)"
        case .blockedDownload(let url):
            return "Blocked modpack download: \(url)"
        case .archiveTooLarge(let size):
            return "Modpack archive is too large (\(size) bytes)"
        }
    }
}

public final class ModpackManager: Sendable {
    public let store: InstanceStore
    public let client: ModrinthClient
    public let downloader: Downloader

    public init(
        store: InstanceStore,
        client: ModrinthClient = ModrinthClient(),
        downloader: Downloader = Downloader()
    ) {
        self.store = store
        self.client = client
        self.downloader = downloader
    }

    public func export(
        instance name: String,
        to destination: URL,
        options: MrpackExportOptions = MrpackExportOptions()
    ) async throws -> MrpackExportReport {
        let instance: Instance
        do {
            instance = try store.load(name: name)
        } catch {
            throw ModpackError.instanceNotFound(name)
        }

        let loaderLower = instance.loader.lowercased()
        guard loaderLower == "fabric" || loaderLower == "vanilla" else {
            throw ModpackError.unsupportedLoader(instance.loader)
        }

        var dependencies: [String: String] = [
            "minecraft": instance.minecraftVersion
        ]

        if loaderLower == "fabric" {
            if let loaderVersion = instance.loaderVersion, !loaderVersion.isEmpty {
                dependencies["fabric-loader"] = loaderVersion
            } else if instance.versionId.hasPrefix("fabric-loader-") {
                let remainder = String(instance.versionId.dropFirst("fabric-loader-".count))
                if let lastDash = remainder.lastIndex(of: "-") {
                    dependencies["fabric-loader"] = String(remainder[..<lastDash])
                } else {
                    dependencies["fabric-loader"] = remainder
                }
            } else {
                let versionInstaller = VersionInstaller(paths: store.paths, downloader: downloader)
                let fabricInstaller = FabricInstaller(paths: store.paths, installer: versionInstaller, downloader: downloader)
                do {
                    dependencies["fabric-loader"] = try await fabricInstaller.latestStableLoader(for: instance.minecraftVersion)
                } catch {
                    throw ModpackError.missingDependency("fabric-loader")
                }
            }
        }

        let stagingDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? fm.removeItem(at: stagingDir)
        }

        let overridesDir = stagingDir.appendingPathComponent("overrides", isDirectory: true)
        let overridesModsDir = overridesDir.appendingPathComponent("mods", isDirectory: true)

        var mrpackFiles: [MrpackFile] = []
        var warnings: [String] = []
        var modsBundled = 0

        func bundleJar(from sourceURL: URL, fileName: String) throws {
            try fm.createDirectory(at: overridesModsDir, withIntermediateDirectories: true, attributes: nil)
            let destURL = overridesModsDir.appendingPathComponent(fileName)
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: sourceURL, to: destURL)
            modsBundled += 1
        }

        let modManager = ModManager(store: store, client: client, downloader: downloader)
        let installedMods = try modManager.list(instance: name)
        let modsDir = modManager.modsDirectory(for: name)

        for mod in installedMods {
            let diskFileName = mod.isEnabled ? mod.fileName : "\(mod.fileName).disabled"
            let localJarURL = modsDir.appendingPathComponent(diskFileName)

            guard fm.fileExists(atPath: localJarURL.path) else {
                continue
            }

            guard let record = mod.record else {
                try bundleJar(from: localJarURL, fileName: diskFileName)
                continue
            }

            let version: ModrinthVersion
            do {
                version = try await client.version(id: record.versionId)
            } catch {
                warnings.append("Could not fetch Modrinth metadata for '\(diskFileName)': \(error.localizedDescription); bundled into overrides")
                try bundleJar(from: localJarURL, fileName: diskFileName)
                continue
            }

            let baseFileName = diskFileName.hasSuffix(".disabled")
                ? String(diskFileName.dropLast(".disabled".count))
                : diskFileName

            guard let matchedFile = version.files.first(where: { $0.filename == baseFileName }) else {
                warnings.append("File '\(baseFileName)' not found in Modrinth version for '\(diskFileName)'; bundled into overrides")
                try bundleJar(from: localJarURL, fileName: diskFileName)
                continue
            }

            let localSha1: String
            let localSha512: String
            let localSize: Int
            do {
                localSha1 = try sha1Hex(of: localJarURL)
                localSha512 = try sha512Hex(of: localJarURL)
                let attrs = try fm.attributesOfItem(atPath: localJarURL.path)
                localSize = (attrs[.size] as? NSNumber)?.intValue ?? 0
            } catch {
                warnings.append("Could not read local file '\(diskFileName)': \(error.localizedDescription); bundled into overrides")
                try bundleJar(from: localJarURL, fileName: diskFileName)
                continue
            }

            let sha1Matches = matchedFile.sha1 == nil || (matchedFile.sha1?.lowercased() == localSha1.lowercased())
            let urlIsModrinthCDN = matchedFile.url.scheme?.lowercased() == "https" && matchedFile.url.host?.lowercased() == "cdn.modrinth.com"

            if !sha1Matches || !urlIsModrinthCDN {
                if !sha1Matches {
                    warnings.append("Local jar '\(diskFileName)' checksum differs from Modrinth; bundled into overrides")
                } else {
                    warnings.append("Mod '\(diskFileName)' download URL is not on cdn.modrinth.com; bundled into overrides")
                }
                try bundleJar(from: localJarURL, fileName: diskFileName)
                continue
            }

            let mrpackFile = MrpackFile(
                path: "mods/\(diskFileName)",
                hashes: [
                    "sha1": localSha1,
                    "sha512": localSha512
                ],
                env: nil,
                downloads: [matchedFile.url.absoluteString],
                fileSize: localSize
            )
            mrpackFiles.append(mrpackFile)
        }

        var overrideFiles = 0
        let gameDir = store.gameDirectory(for: name)

        func copyOverrideFile(from fileURL: URL, relativePath: String) throws {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else { return }
            let attrs = try fm.attributesOfItem(atPath: fileURL.path)
            if attrs[.type] as? FileAttributeType == .typeSymbolicLink {
                return
            }
            if fileURL.lastPathComponent == ".DS_Store" {
                return
            }
            let destURL = overridesDir.appendingPathComponent(relativePath)
            try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: fileURL, to: destURL)
            overrideFiles += 1
        }

        func copyOverrideDirectory(named folderName: String) throws {
            let folderURL = gameDir.appendingPathComponent(folderName, isDirectory: true)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else { return }

            guard let enumerator = fm.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsPackageDescendants]
            ) else { return }

            while let fileURL = enumerator.nextObject() as? URL {
                if fileURL.lastPathComponent == ".DS_Store" {
                    continue
                }
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if values?.isSymbolicLink == true {
                    continue
                }
                guard values?.isRegularFile == true else {
                    continue
                }

                let fullPath = fileURL.path
                guard fullPath.hasPrefix(gameDir.path) else { continue }
                let rel = fullPath.dropFirst(gameDir.path.count)
                let cleanRel = rel.hasPrefix("/") ? String(rel.dropFirst()) : String(rel)

                let destURL = overridesDir.appendingPathComponent(cleanRel)
                try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                try fm.copyItem(at: fileURL, to: destURL)
                overrideFiles += 1
            }
        }

        if options.includeConfig {
            try copyOverrideDirectory(named: "config")
        }
        if options.includeOptions {
            try copyOverrideFile(from: gameDir.appendingPathComponent("options.txt"), relativePath: "options.txt")
        }
        if options.includeResourcePacks {
            try copyOverrideDirectory(named: "resourcepacks")
        }
        if options.includeShaders {
            try copyOverrideDirectory(named: "shaderpacks")
            try copyOverrideDirectory(named: "shaders")
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let sortedFiles = mrpackFiles.sorted { $0.path < $1.path }
        let index = MrpackIndex(
            formatVersion: 1,
            game: "minecraft",
            versionId: options.versionLabel,
            name: instance.name,
            summary: options.summary,
            files: sortedFiles,
            dependencies: dependencies
        )
        let indexData = try encoder.encode(index)
        try indexData.write(to: stagingDir.appendingPathComponent("modrinth.index.json"))

        var zipEntries = ["modrinth.index.json"]
        if fm.fileExists(atPath: overridesDir.path) {
            zipEntries.append("overrides")
        }

        let destDir = destination.deletingLastPathComponent()
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
        let partialURL = destDir.appendingPathComponent(".\(destination.lastPathComponent).partial")
        if fm.fileExists(atPath: partialURL.path) {
            try? fm.removeItem(at: partialURL)
        }

        do {
            try ZipArchive.create(partialURL, from: stagingDir, entries: zipEntries)
            if fm.fileExists(atPath: destination.path) {
                _ = try fm.replaceItemAt(destination, withItemAt: partialURL, backupItemName: nil, options: [])
            } else {
                try fm.moveItem(at: partialURL, to: destination)
            }
        } catch {
            try? fm.removeItem(at: partialURL)
            throw error
        }

        return MrpackExportReport(
            archive: destination,
            modsLinked: mrpackFiles.count,
            modsBundled: modsBundled,
            overrideFiles: overrideFiles,
            warnings: warnings
        )
    }
}
