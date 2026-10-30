import Foundation

/// Errors thrown by content catalog operations.
public enum ContentError: Error, LocalizedError, Sendable, Equatable {
    case notFound(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let message):
            return message
        case .unsupported(let message):
            return message
        }
    }
}

/// The kind of content available in the Modrinth catalog.
public enum ContentKind: String, Codable, Sendable, CaseIterable {
    case mod
    case modpack
    case shader
    case resourcepack

    /// Modrinth project type parameter string.
    public var projectType: String {
        switch self {
        case .mod: return "mod"
        case .modpack: return "modpack"
        case .shader: return "shader"
        case .resourcepack: return "resourcepack"
        }
    }

    /// Sub-folder name inside the instance directory.
    public var subfolder: String? {
        switch self {
        case .mod: return "mods"
        case .modpack: return nil
        case .shader: return "shaderpacks"
        case .resourcepack: return "resourcepacks"
        }
    }

    public var browseCategories: [String] {
        switch self {
        case .mod:
            return [
                "adventure", "cursed", "decoration", "economy", "equipment", "food",
                "game-mechanics", "library", "magic", "management", "minigame", "mobs",
                "optimization", "social", "storage", "technology", "transportation",
                "utility", "worldgen"
            ]
        case .modpack:
            return [
                "adventure", "challenging", "combat", "kitchen-sink", "lightweight",
                "magic", "multiplayer", "optimization", "quests", "technology"
            ]
        case .shader:
            return [
                "cartoon", "cursed", "fantasy", "realistic", "semi-realistic", "vanilla-like"
            ]
        case .resourcepack:
            return [
                "8x-", "16x", "32x", "48x", "64x", "128x", "256x", "512x+", "audio",
                "blocks", "combat", "core-shaders", "cursed", "decoration", "entities",
                "environment", "equipment", "fonts", "gui", "items", "locale", "modded",
                "models", "realistic", "simplistic", "themed", "tweaks", "utility",
                "vanilla-like"
            ]
        }
    }
}

/// One chip in Browse: a few Modrinth category slugs shown as a single filter (matched with OR).
public struct CategoryGroup: Sendable, Hashable {
    public let id: String
    public let title: String
    public let slugs: [String]
}

extension ContentKind {
    /// What Browse offers as category chips. Mods and modpacks fold Modrinth's long slug list into a few groups.
    public var browseGroups: [CategoryGroup] {
        switch self {
        case .mod:
            return [
                CategoryGroup(id: "optimization", title: "Optimization", slugs: ["optimization"]),
                CategoryGroup(id: "adventure", title: "Adventure", slugs: ["adventure", "mobs", "worldgen", "equipment", "game-mechanics", "minigame", "cursed"]),
                CategoryGroup(id: "magic", title: "Magic", slugs: ["magic"]),
                CategoryGroup(id: "technology", title: "Technology", slugs: ["technology", "transportation", "storage"]),
                CategoryGroup(id: "food", title: "Food & farming", slugs: ["food"]),
                CategoryGroup(id: "decor", title: "Decor & building", slugs: ["decoration"]),
                CategoryGroup(id: "utility", title: "Utility", slugs: ["utility", "management", "social", "economy"]),
                CategoryGroup(id: "library", title: "Libraries", slugs: ["library"]),
            ]
        case .modpack:
            return [
                CategoryGroup(id: "adventure", title: "Adventure", slugs: ["adventure", "quests"]),
                CategoryGroup(id: "magic", title: "Magic", slugs: ["magic"]),
                CategoryGroup(id: "technology", title: "Technology", slugs: ["technology"]),
                CategoryGroup(id: "kitchen-sink", title: "Kitchen sink", slugs: ["kitchen-sink"]),
                CategoryGroup(id: "challenging", title: "Challenging", slugs: ["challenging"]),
                CategoryGroup(id: "multiplayer", title: "Multiplayer", slugs: ["multiplayer"]),
                CategoryGroup(id: "combat", title: "Combat", slugs: ["combat"]),
                CategoryGroup(id: "optimization", title: "Optimization", slugs: ["optimization", "lightweight"]),
            ]
        case .shader, .resourcepack:
            return browseCategories.map { CategoryGroup(id: $0, title: $0, slugs: [$0]) }
        }
    }
}

extension ContentKind {
    /// Hand-picked full modpacks shown above the search in Browse (Modrinth slugs). Order is the display order.
    public static let bigBuildSlugs: [String] = [
        "prominence-2-fabric",
        "better-mc-fabric-bmc2",
        "better-mc-forge-bmc4",
        "medieval-mc-forge-mmc4",
        "medieval-mc-fabric-mmc2",
        "cabricality",
        "valhelsia-infinite",
        "technical-electrical",
        "techmagic",
        "dungeon-train-pack-a-lore-rich-roguelite-adventure",
        "the-pixelmon-modpack",
        "cobbleverse",
        "of-scales-and-claws",
        "rpg-adventure-vita-smp",
    ]
}

/// Metadata record persisted in content.json for installed shaders and resourcepacks.
public struct ContentRecord: Codable, Sendable, Equatable {
    public var fileName: String
    public var projectId: String
    public var versionId: String
    public var title: String
    public var versionNumber: String
    public var kind: ContentKind
    public var iconURL: URL?
    public var dateInstalled: Date?

    public init(
        fileName: String,
        projectId: String,
        versionId: String,
        title: String,
        versionNumber: String,
        kind: ContentKind,
        iconURL: URL? = nil,
        dateInstalled: Date? = Date()
    ) {
        self.fileName = fileName
        self.projectId = projectId
        self.versionId = versionId
        self.title = title
        self.versionNumber = versionNumber
        self.kind = kind
        self.iconURL = iconURL
        self.dateInstalled = dateInstalled
    }
}

/// Result of installing content into an instance.
public enum ContentInstallResult: Sendable, Equatable {
    case installed(title: String, fileName: String)
    case mod(ModInstallResult)
    case skipped(String)
    case needsShaderLoader
    case unsupported(String)
}

/// Information reported after creating an instance from a modpack.
public struct ModpackCreationReport: Sendable {
    public var instanceName: String
    public var minecraftVersion: String
    public var loader: String
    public var loaderVersion: String?
    public var filesInstalled: Int
    public var warnings: [String]

    public init(
        instanceName: String,
        minecraftVersion: String,
        loader: String,
        loaderVersion: String? = nil,
        filesInstalled: Int = 0,
        warnings: [String] = []
    ) {
        self.instanceName = instanceName
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.loaderVersion = loaderVersion
        self.filesInstalled = filesInstalled
        self.warnings = warnings
    }
}

/// Compatibility check result before downloading or installing content.
public enum ContentCompatibility: Sendable, Equatable {
    case ready
    case needsOther(String)
    case noRelease
}

/// Handles installation and management of catalog content across instances.
public final class ContentInstaller: Sendable {
    public let store: InstanceStore
    public let client: ModrinthClient
    public let downloader: Downloader
    public let modManager: ModManager
    public let modpackManager: ModpackManager

    public init(
        store: InstanceStore,
        client: ModrinthClient = ModrinthClient(),
        downloader: Downloader = Downloader()
    ) {
        self.store = store
        self.client = client
        self.downloader = downloader
        self.modManager = ModManager(store: store, client: client, downloader: downloader)
        self.modpackManager = ModpackManager(store: store, client: client, downloader: downloader)
    }

    /// URL of the content.json file for an instance.
    public func contentJSONURL(for instanceName: String) -> URL {
        store.instanceDirectory(for: instanceName).appendingPathComponent("content.json")
    }

    /// Loads content records from content.json for an instance.
    public func loadContentRecords(instance name: String) -> [ContentRecord] {
        let url = contentJSONURL(for: name)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([ContentRecord].self, from: data) else {
            return []
        }
        return records
    }

    /// Saves content records to content.json for an instance.
    public func saveContentRecords(_ records: [ContentRecord], instance name: String) throws {
        let instDir = store.instanceDirectory(for: name)
        let fm = FileManager.default
        if !fm.fileExists(atPath: instDir.path) {
            try fm.createDirectory(at: instDir, withIntermediateDirectories: true, attributes: nil)
        }
        let url = contentJSONURL(for: name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: url, options: .atomic)
    }

    /// Resolves destination directory for a given content kind.
    public func contentDirectory(for kind: ContentKind, in instanceName: String) -> URL {
        let folder = kind.subfolder ?? ""
        return store.gameDirectory(for: instanceName).appendingPathComponent(folder, isDirectory: true)
    }

    /// Installs content into the specified instance.
    public func install(
        project idOrSlug: String,
        kind: ContentKind,
        into instanceName: String
    ) async throws -> ContentInstallResult {
        let instance = try store.load(name: instanceName)

        switch kind {
        case .mod:
            let modResult = try await modManager.install(project: idOrSlug, into: instanceName)
            return .mod(modResult)

        case .shader:
            guard instance.loader.lowercased() == "fabric" else {
                return .unsupported("Shaders require the Fabric loader with Iris, but instance uses '\(instance.loader)'")
            }

            let installedMods = (try? modManager.list(instance: instanceName)) ?? []
            let hasIris = installedMods.contains { mod in
                if mod.record?.projectId.lowercased() == "iris" || mod.record?.projectId == "YL57xq9U" {
                    return true
                }
                let lower = mod.fileName.lowercased()
                return lower.hasPrefix("iris-") || lower.hasPrefix("iris_") || lower.contains("iris")
            }
            guard hasIris else {
                return .needsShaderLoader
            }

            let versions = try await client.versions(project: idOrSlug, gameVersion: instance.minecraftVersion)
            let shaderLoaders = Set(["iris", "optifine", "canvas", "vanilla"])
            let matchingVersions = versions.filter { ver in
                ver.loaders.isEmpty || ver.loaders.contains(where: { shaderLoaders.contains($0.lowercased()) })
            }
            guard let version = matchingVersions.first(where: { $0.versionType.lowercased() == "release" }) ?? matchingVersions.first else {
                throw ModrinthError.noCompatibleVersion(project: idOrSlug, gameVersion: instance.minecraftVersion, loader: "iris")
            }

            let result = try await installDirectFile(project: idOrSlug, version: version, kind: .shader, into: instanceName)
            if case .installed(_, let fileName) = result {
                try? PackActivation.enableShaderPack(fileName: fileName, gameDirectory: store.gameDirectory(for: instanceName))
            }
            return result

        case .resourcepack:
            let versions = try await client.versions(project: idOrSlug, gameVersion: instance.minecraftVersion)
            guard let version = versions.first(where: { $0.versionType.lowercased() == "release" }) ?? versions.first else {
                throw ModrinthError.noCompatibleVersion(project: idOrSlug, gameVersion: instance.minecraftVersion, loader: "any")
            }

            let result = try await installDirectFile(project: idOrSlug, version: version, kind: .resourcepack, into: instanceName)
            if case .installed(_, let fileName) = result {
                try? PackActivation.enableResourcePack(fileName: fileName, gameDirectory: store.gameDirectory(for: instanceName))
            }
            return result

        case .modpack:
            return .unsupported("Modpacks create new instances; use createInstance(fromModpack:)")
        }
    }

    /// Installs Iris to provide shader support on a Fabric instance.
    @discardableResult
    public func ensureShaderSupport(into instanceName: String) async throws -> ModInstallResult {
        let instance = try store.load(name: instanceName)
        guard instance.loader.lowercased() == "fabric" else {
            throw ContentError.unsupported("Shader support requires loader 'fabric', but instance uses '\(instance.loader)'")
        }
        return try await modManager.install(project: "iris", into: instanceName)
    }

    /// Loaders a modpack can ask for that the launcher can install.
    public static let packLoaders = ["fabric", "quilt", "forge", "neoforge"]

    /// Versions the launcher can run; with `loader` set, only those built for that loader.
    static func runnablePackVersions(_ versions: [ModrinthVersion], loader: String? = nil) -> [ModrinthVersion] {
        let wanted = loader.map { [$0.lowercased()] } ?? packLoaders
        return versions.filter { version in
            version.loaders.isEmpty || version.loaders.contains { wanted.contains($0.lowercased()) }
        }
    }

    /// Creates a new instance from a Modrinth .mrpack modpack.
    public func createInstance(
        fromModpack projectIdOrSlug: String,
        version: ModrinthVersion? = nil,
        name: String? = nil,
        gameVersion: String? = nil,
        loader: String? = nil
    ) async throws -> ModpackCreationReport {
        let chosenVersion: ModrinthVersion
        if let version = version {
            chosenVersion = version
        } else {
            let versions = Self.runnablePackVersions(try await client.versions(project: projectIdOrSlug, gameVersion: gameVersion), loader: loader)
            guard !versions.isEmpty else {
                throw ContentError.notFound("No version of modpack '\(projectIdOrSlug)' for \(gameVersion ?? "any Minecraft version") that this launcher can run")
            }
            chosenVersion = versions.first(where: { $0.versionType.lowercased() == "release" }) ?? versions[0]
        }

        guard let primaryFile = chosenVersion.primaryFile else {
            throw ContentError.notFound("No file found in version '\(chosenVersion.name)'")
        }

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? fm.removeItem(at: tempDir)
        }

        let tempArchive = tempDir.appendingPathComponent(primaryFile.filename)
        try await downloader.download(
            url: primaryFile.url,
            to: tempArchive,
            sha1: primaryFile.sha1,
            size: primaryFile.size
        )

        let summary = try modpackManager.inspect(tempArchive)
        let importReport = try await modpackManager.importPack(
            from: tempArchive,
            name: name
        )

        return ModpackCreationReport(
            instanceName: importReport.instanceName,
            minecraftVersion: summary.minecraftVersion,
            loader: summary.loader,
            loaderVersion: summary.loaderVersion,
            filesInstalled: importReport.filesInstalled,
            warnings: importReport.warnings
        )
    }

    /// Downloads a modpack and lists its files so the user can pick which to install.
    /// Finish with `createInstance(fromPreview:excludedPaths:)` or `discardPreview(_:)`.
    public func previewModpack(_ projectIdOrSlug: String, gameVersion: String? = nil, loader: String? = nil) async throws -> ModpackPreview {
        let versions = Self.runnablePackVersions(try await client.versions(project: projectIdOrSlug, gameVersion: gameVersion), loader: loader)
        guard !versions.isEmpty else {
            throw ContentError.notFound("No version of modpack '\(projectIdOrSlug)' for \(gameVersion ?? "any Minecraft version") that this launcher can run")
        }
        let chosenVersion = versions.first(where: { $0.versionType.lowercased() == "release" }) ?? versions[0]
        guard let primaryFile = chosenVersion.primaryFile else {
            throw ContentError.notFound("No file found in version '\(chosenVersion.name)'")
        }

        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("ember-pack-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true, attributes: nil)
        do {
            let archive = workDir.appendingPathComponent(primaryFile.filename)
            try await downloader.download(url: primaryFile.url, to: archive, sha1: primaryFile.sha1, size: primaryFile.size)
            return try await modpackManager.preview(archive: archive, workDir: workDir)
        } catch {
            try? FileManager.default.removeItem(at: workDir)
            throw error
        }
    }

    /// Creates the instance from a previewed pack, leaving out the files at `excludedPaths`.
    public func createInstance(
        fromPreview preview: ModpackPreview,
        excludedPaths: Set<String>,
        name: String? = nil
    ) async throws -> ModpackCreationReport {
        defer { try? FileManager.default.removeItem(at: preview.workDir) }
        let importReport = try await modpackManager.importPack(from: preview.archive, name: name, excludedPaths: excludedPaths)
        return ModpackCreationReport(
            instanceName: importReport.instanceName,
            minecraftVersion: preview.summary.minecraftVersion,
            loader: preview.summary.loader,
            loaderVersion: preview.summary.loaderVersion,
            filesInstalled: importReport.filesInstalled,
            warnings: importReport.warnings
        )
    }

    /// Drops the downloaded pack of a preview that was not installed.
    public func discardPreview(_ preview: ModpackPreview) {
        try? FileManager.default.removeItem(at: preview.workDir)
    }

    /// Checks compatibility of a catalog project before downloading.
    public func compatibility(
        project idOrSlug: String,
        kind: ContentKind,
        instance instanceName: String,
        modpackGameVersion: String? = nil,
        modpackLoader: String? = nil
    ) async throws -> ContentCompatibility {
        let instance = try store.load(name: instanceName)
        switch kind {
        case .mod:
            let modCompat = await modManager.compatibility(project: idOrSlug, instance: instanceName)
            switch modCompat {
            case .ready:
                return .ready
            case .needs(let count):
                return .needsOther("\(count) dependencies required")
            case .conflict(let with):
                return .needsOther("Conflicts with \(with)")
            case .unavailable, .unknown:
                return .noRelease
            }

        case .shader:
            guard instance.loader.lowercased() == "fabric" else {
                return .needsOther("Requires Fabric loader with Iris")
            }
            let installedMods = (try? modManager.list(instance: instanceName)) ?? []
            let hasIris = installedMods.contains { mod in
                if mod.record?.projectId.lowercased() == "iris" || mod.record?.projectId == "YL57xq9U" {
                    return true
                }
                let lower = mod.fileName.lowercased()
                return lower.hasPrefix("iris-") || lower.hasPrefix("iris_") || lower.contains("iris")
            }
            if !hasIris {
                return .needsOther("needsShaderLoader")
            }
            let versions = try await client.versions(project: idOrSlug, gameVersion: instance.minecraftVersion)
            let shaderLoaders = Set(["iris", "optifine", "canvas", "vanilla"])
            let matching = versions.filter { ver in
                ver.loaders.isEmpty || ver.loaders.contains(where: { shaderLoaders.contains($0.lowercased()) })
            }
            return matching.isEmpty ? .noRelease : .ready

        case .resourcepack:
            let versions = try await client.versions(project: idOrSlug, gameVersion: instance.minecraftVersion)
            return versions.isEmpty ? .noRelease : .ready

        case .modpack:
            let versions = Self.runnablePackVersions(try await client.versions(project: idOrSlug, gameVersion: modpackGameVersion), loader: modpackLoader)
            return versions.isEmpty ? .noRelease : .ready
        }
    }

    private func installDirectFile(
        project idOrSlug: String,
        version: ModrinthVersion,
        kind: ContentKind,
        into instanceName: String
    ) async throws -> ContentInstallResult {
        guard let primaryFile = version.primaryFile else {
            throw ContentError.notFound("No file found for version \(version.name)")
        }

        let folder = kind.subfolder ?? ""
        let gameTargetDir = store.gameDirectory(for: instanceName).appendingPathComponent(folder, isDirectory: true)
        let instTargetDir = store.instanceDirectory(for: instanceName).appendingPathComponent(folder, isDirectory: true)

        let fm = FileManager.default
        try fm.createDirectory(at: gameTargetDir, withIntermediateDirectories: true, attributes: nil)
        try? fm.createDirectory(at: instTargetDir, withIntermediateDirectories: true, attributes: nil)

        let targetURL = gameTargetDir.appendingPathComponent(primaryFile.filename)
        let instTargetURL = instTargetDir.appendingPathComponent(primaryFile.filename)

        if fm.fileExists(atPath: targetURL.path) || fm.fileExists(atPath: instTargetURL.path) {
            return .skipped("\(primaryFile.filename) is already present")
        }

        try await downloader.download(
            url: primaryFile.url,
            to: targetURL,
            sha1: primaryFile.sha1,
            size: primaryFile.size
        )

        if gameTargetDir.path != instTargetDir.path && !fm.fileExists(atPath: instTargetURL.path) {
            try? fm.createSymbolicLink(at: instTargetURL, withDestinationURL: targetURL)
        }

        let project = try await client.project(idOrSlug: version.projectId)
        var records = loadContentRecords(instance: instanceName)
        let record = ContentRecord(
            fileName: primaryFile.filename,
            projectId: project.id,
            versionId: version.id,
            title: project.title,
            versionNumber: version.versionNumber,
            kind: kind,
            iconURL: project.iconURL
        )
        records.removeAll(where: { $0.fileName == primaryFile.filename || $0.projectId == project.id })
        records.append(record)
        try saveContentRecords(records, instance: instanceName)

        return .installed(title: project.title, fileName: primaryFile.filename)
    }
}
