import Foundation

public struct MrpackSummary: Sendable, Equatable {
    public var name: String
    public var versionLabel: String
    public var summary: String?
    public var minecraftVersion: String
    public var loader: String
    public var loaderVersion: String?
    public var fileCount: Int
    public var overrideFileCount: Int
    public var downloadBytes: Int64

    public init(
        name: String,
        versionLabel: String,
        summary: String? = nil,
        minecraftVersion: String,
        loader: String,
        loaderVersion: String? = nil,
        fileCount: Int,
        overrideFileCount: Int,
        downloadBytes: Int64
    ) {
        self.name = name
        self.versionLabel = versionLabel
        self.summary = summary
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.loaderVersion = loaderVersion
        self.fileCount = fileCount
        self.overrideFileCount = overrideFileCount
        self.downloadBytes = downloadBytes
    }
}

public struct MrpackImportReport: Sendable {
    public var instanceName: String
    public var filesInstalled: Int
    public var failed: [String]
    public var overrideFiles: Int
    public var warnings: [String]

    public init(
        instanceName: String,
        filesInstalled: Int,
        failed: [String] = [],
        overrideFiles: Int = 0,
        warnings: [String] = []
    ) {
        self.instanceName = instanceName
        self.filesInstalled = filesInstalled
        self.failed = failed
        self.overrideFiles = overrideFiles
        self.warnings = warnings
    }
}

private let allowedDownloadHosts: Set<String> = [
    "cdn.modrinth.com",
    "github.com",
    "raw.githubusercontent.com",
    "gitlab.com"
]

private enum DownloadFileResult: Sendable {
    case success(file: MrpackFile, usedURL: URL)
    case failed(path: String, reason: String)
}

private struct ModRecordCandidate {
    let fileName: String
    let projectId: String
    let versionId: String
    let fallbackTitle: String
    let versionNumber: String
}

extension ModpackManager {
    public func inspect(_ archive: URL) throws -> MrpackSummary {
        try validateArchiveBeforeExtract(archive)

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? fm.removeItem(at: tempDir)
        }

        try ZipArchive.extract(archive, to: tempDir)
        try validateNoSymbolicLinks(in: tempDir)

        let (index, minecraftVersion, loader, loaderVersion) = try parseAndValidateIndex(in: tempDir)

        let clientFiles = index.files.filter { $0.env?.client != "unsupported" }
        for file in clientFiles {
            guard isSafeRelativePath(file.path, relativeTo: tempDir) else {
                throw ModpackError.unsafePath(file.path)
            }
        }

        let downloadBytes = clientFiles.reduce(Int64(0)) { $0 + Int64($1.fileSize) }
        let overrideFileCount = countOverrideFiles(in: tempDir)

        return MrpackSummary(
            name: index.name,
            versionLabel: index.versionId,
            summary: index.summary,
            minecraftVersion: minecraftVersion,
            loader: loader,
            loaderVersion: loaderVersion,
            fileCount: clientFiles.count,
            overrideFileCount: overrideFileCount,
            downloadBytes: downloadBytes
        )
    }

    public func importPack(
        from archive: URL,
        name: String? = nil,
        group: String? = nil,
        memoryMB: Int = 4096,
        excludedPaths: Set<String> = [],
        progress: @escaping @Sendable (String, Double) -> Void = { _, _ in }
    ) async throws -> MrpackImportReport {
        progress("Reading the pack", 0.0)

        try validateArchiveBeforeExtract(archive)

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? fm.removeItem(at: tempDir)
        }

        try ZipArchive.extract(archive, to: tempDir)
        try validateNoSymbolicLinks(in: tempDir)

        let (index, minecraftVersion, loader, loaderVersion) = try parseAndValidateIndex(in: tempDir)

        let clientFiles = index.files.filter { $0.env?.client != "unsupported" && !excludedPaths.contains($0.path) }

        let finalName = store.uniqueName(base: name ?? index.name, fallback: "Modpack")
        let gameDir = store.gameDirectory(for: finalName)

        for file in clientFiles {
            guard isSafeRelativePath(file.path, relativeTo: gameDir) else {
                throw ModpackError.unsafePath(file.path)
            }
        }

        progress("Reading the pack", 1.0)

        let instance: Instance
        if loader != "vanilla" {
            // Fabric, Quilt, Forge and NeoForge are installed on the first Play, which fills in the version id.
            instance = Instance(
                name: finalName,
                minecraftVersion: minecraftVersion,
                loader: loader,
                loaderVersion: loaderVersion,
                versionId: "",
                memoryMB: memoryMB,
                group: group
            )
        } else {
            instance = Instance(
                name: finalName,
                minecraftVersion: minecraftVersion,
                loader: "vanilla",
                loaderVersion: nil,
                versionId: minecraftVersion,
                memoryMB: memoryMB,
                group: group
            )
        }

        try store.create(instance)

        do {
            var failed: [String] = []
            var successfulDownloads: [(file: MrpackFile, usedURL: URL)] = []
            let totalDownloads = clientFiles.count

            if totalDownloads == 0 {
                progress("Downloading mods", 1.0)
            } else {
                progress("Downloading mods", 0.0)
                var completedCount = 0
                let maxConcurrency = 6

                try await withThrowingTaskGroup(of: DownloadFileResult.self) { group in
                    var iterator = clientFiles.makeIterator()
                    var inFlight = 0

                    while inFlight < maxConcurrency, let file = iterator.next() {
                        inFlight += 1
                        group.addTask {
                            await self.downloadFile(file, gameDir: gameDir)
                        }
                    }

                    while let result = try await group.next() {
                        inFlight -= 1
                        completedCount += 1
                        progress("Downloading mods", Double(completedCount) / Double(totalDownloads))

                        switch result {
                        case .success(let file, let usedURL):
                            successfulDownloads.append((file, usedURL))
                        case .failed(let path, let reason):
                            failed.append("\(path): \(reason)")
                        }

                        if let nextFile = iterator.next() {
                            inFlight += 1
                            group.addTask {
                                await self.downloadFile(nextFile, gameDir: gameDir)
                            }
                        }
                    }
                }
            }

            progress("Copying files", 0.0)
            let (overrideFiles, overrideWarnings) = try copyOverrides(from: tempDir, to: gameDir)
            var warnings = overrideWarnings
            progress("Copying files", 1.0)

            progress("Finishing", 0.0)

            var candidates: [ModRecordCandidate] = []
            for (file, usedURL) in successfulDownloads {
                guard file.path.hasPrefix("mods/") else { continue }
                guard let scheme = usedURL.scheme?.lowercased(), scheme == "https",
                      let host = usedURL.host?.lowercased(), host == "cdn.modrinth.com" else {
                    continue
                }

                let pathComponents = usedURL.pathComponents
                guard pathComponents.count == 6,
                      pathComponents[1] == "data",
                      pathComponents[3] == "versions" else {
                    continue
                }

                let projectId = pathComponents[2]
                let versionId = pathComponents[4]
                let fileName = URL(fileURLWithPath: file.path).lastPathComponent

                let versionNumber: String
                let fallbackTitle: String
                if fileName.hasSuffix(".jar") {
                    let base = String(fileName.dropLast(4))
                    versionNumber = base
                    fallbackTitle = base
                } else {
                    versionNumber = fileName
                    fallbackTitle = (fileName as NSString).deletingPathExtension
                }

                candidates.append(
                    ModRecordCandidate(
                        fileName: fileName,
                        projectId: projectId,
                        versionId: versionId,
                        fallbackTitle: fallbackTitle,
                        versionNumber: versionNumber
                    )
                )
            }

            if !candidates.isEmpty {
                let uniqueProjectIds = Array(Set(candidates.map { $0.projectId }))
                var projectMap: [String: ModrinthProject] = [:]
                do {
                    let projects = try await client.projects(ids: uniqueProjectIds)
                    for project in projects {
                        projectMap[project.id] = project
                    }
                } catch {
                    warnings.append("Could not fetch project metadata: \(error.localizedDescription)")
                }

                var records: [ModRecord] = []
                for candidate in candidates {
                    let project = projectMap[candidate.projectId]
                    let title = project?.title ?? candidate.fallbackTitle
                    let iconURL = project?.iconURL
                    let record = ModRecord(
                        fileName: candidate.fileName,
                        projectId: candidate.projectId,
                        versionId: candidate.versionId,
                        title: title,
                        versionNumber: candidate.versionNumber,
                        iconURL: iconURL,
                        isDependency: false,
                        installedFor: nil
                    )
                    records.append(record)
                }

                if !records.isEmpty {
                    let modManager = ModManager(store: store, client: client, downloader: downloader)
                    try modManager.saveRecords(records, instance: finalName)
                }
            }

            progress("Finishing", 1.0)

            return MrpackImportReport(
                instanceName: finalName,
                filesInstalled: successfulDownloads.count,
                failed: failed,
                overrideFiles: overrideFiles,
                warnings: warnings
            )
        } catch {
            try? store.moveToTrash(finalName)
            throw error
        }
    }

    private func downloadFile(
        _ file: MrpackFile,
        gameDir: URL
    ) async -> DownloadFileResult {
        guard let downloadURL = selectDownloadURL(from: file.downloads) else {
            return .failed(path: file.path, reason: "download host not allowed")
        }

        // The .mrpack spec requires both hashes; a file without them cannot be verified, so nothing is downloaded.
        guard let expectedSha1 = file.hashes["sha1"], !expectedSha1.isEmpty,
              let expectedSha512 = file.hashes["sha512"], !expectedSha512.isEmpty else {
            return .failed(path: file.path, reason: "missing hashes")
        }

        let destURL = gameDir.appendingPathComponent(file.path)
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try await downloader.download(
                url: downloadURL,
                to: destURL,
                sha1: expectedSha1,
                size: file.fileSize
            )

            do {
                let actualSha512 = try sha512Hex(of: destURL)
                if actualSha512.caseInsensitiveCompare(expectedSha512) != .orderedSame {
                    try? fm.removeItem(at: destURL)
                    return .failed(path: file.path, reason: "sha512 mismatch")
                }
            } catch {
                try? fm.removeItem(at: destURL)
                return .failed(path: file.path, reason: "sha512 mismatch")
            }
            return .success(file: file, usedURL: downloadURL)
        } catch {
            return .failed(path: file.path, reason: error.localizedDescription)
        }
    }

    private func selectDownloadURL(from downloads: [String]) -> URL? {
        for downloadString in downloads {
            guard let url = URL(string: downloadString),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https",
                  let host = url.host?.lowercased(),
                  allowedDownloadHosts.contains(host) else {
                continue
            }
            return url
        }
        return nil
    }

    func validateArchiveBeforeExtract(_ archive: URL) throws {
        let entries = try ZipArchive.entries(of: archive)
        for entry in entries {
            if entry.isEmpty
                || entry.hasPrefix("/")
                || entry.hasPrefix("~")
                || entry.contains("\\")
                || entry.contains("\0")
                || entry.components(separatedBy: "/").contains("..") {
                throw ModpackError.unsafePath(entry)
            }
        }

        if try ZipArchive.hasSymlinks(archive) {
            throw ModpackError.invalidArchive("symbolic links are not allowed")
        }

        guard entries.contains("modrinth.index.json") else {
            throw ModpackError.invalidArchive("modrinth.index.json is missing")
        }

        let uncompressedSize = try ZipArchive.uncompressedSize(of: archive)
        let maxArchiveSize: Int64 = 4 * 1024 * 1024 * 1024
        if uncompressedSize > maxArchiveSize {
            throw ModpackError.archiveTooLarge(uncompressedSize)
        }
    }

    func validateNoSymbolicLinks(in directory: URL) throws {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: []
        ) else {
            throw ModpackError.invalidArchive("Failed to enumerate extracted archive")
        }

        for case let itemURL as URL in enumerator {
            let values = try? itemURL.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values?.isSymbolicLink == true {
                throw ModpackError.invalidArchive("symbolic links are not allowed")
            }
            if (try? fm.destinationOfSymbolicLink(atPath: itemURL.path)) != nil {
                throw ModpackError.invalidArchive("symbolic links are not allowed")
            }
        }
    }

    func parseAndValidateIndex(
        in directory: URL
    ) throws -> (index: MrpackIndex, minecraftVersion: String, loader: String, loaderVersion: String?) {
        let indexURL = directory.appendingPathComponent("modrinth.index.json")
        let fm = FileManager.default
        guard fm.fileExists(atPath: indexURL.path) else {
            throw ModpackError.invalidArchive("modrinth.index.json is missing")
        }

        let index: MrpackIndex
        do {
            let data = try Data(contentsOf: indexURL)
            index = try JSONDecoder().decode(MrpackIndex.self, from: data)
        } catch {
            throw ModpackError.invalidArchive("modrinth.index.json is invalid: \(error.localizedDescription)")
        }

        guard index.formatVersion == 1 else {
            throw ModpackError.unsupportedFormat(index.formatVersion)
        }

        guard index.game == "minecraft" else {
            throw ModpackError.invalidArchive("Unsupported game: \(index.game)")
        }

        guard let minecraftVersion = index.dependencies["minecraft"], !minecraftVersion.isEmpty else {
            throw ModpackError.missingDependency("minecraft")
        }

        let loader: String
        let loaderVersion: String?
        if let fabricVersion = index.dependencies["fabric-loader"] {
            loader = "fabric"
            loaderVersion = fabricVersion
        } else if let quiltVersion = index.dependencies["quilt-loader"] {
            loader = "quilt"
            loaderVersion = quiltVersion
        } else if let forgeVersion = index.dependencies["forge"] {
            loader = "forge"
            loaderVersion = forgeVersion
        } else if let neoForgeVersion = index.dependencies["neoforge"] {
            loader = "neoforge"
            loaderVersion = neoForgeVersion
        } else {
            loader = "vanilla"
            loaderVersion = nil
        }

        return (index, minecraftVersion, loader, loaderVersion)
    }

    func isSafeRelativePath(_ path: String, relativeTo baseDir: URL) -> Bool {
        if path.isEmpty
            || path.hasPrefix("/")
            || path.hasPrefix("~")
            || path.contains("\\")
            || path.contains("\0") {
            return false
        }

        let components = path.components(separatedBy: "/")
        if components.contains("..") {
            return false
        }

        let baseStandardized = baseDir.standardizedFileURL.path
        let prefix = baseStandardized.hasSuffix("/") ? baseStandardized : baseStandardized + "/"
        let destStandardized = baseDir.appendingPathComponent(path).standardizedFileURL.path

        return destStandardized.hasPrefix(prefix)
    }

    /// Copies `overrides/` and then `client-overrides/` into the game directory (sync: directory enumeration is not allowed in async code).
    func copyOverrides(from tempDir: URL, to gameDir: URL) throws -> (count: Int, warnings: [String]) {
        let fm = FileManager.default
        var overrideFiles = 0
        var warnings: [String] = []
        for folderName in ["overrides", "client-overrides"] {
            let sourceFolder = tempDir.appendingPathComponent(folderName, isDirectory: true)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: sourceFolder.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            guard let enumerator = fm.enumerator(
                at: sourceFolder,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsPackageDescendants]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
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

                // The temp dir may sit behind a symlink (/var -> /private/var), so compare resolved paths.
                let fullPath = fileURL.resolvingSymlinksInPath().path
                let basePath = sourceFolder.resolvingSymlinksInPath().path
                guard fullPath.hasPrefix(basePath) else { continue }
                let rel = fullPath.dropFirst(basePath.count)
                let cleanRel = rel.hasPrefix("/") ? String(rel.dropFirst()) : String(rel)
                guard !cleanRel.isEmpty else { continue }

                guard isSafeRelativePath(cleanRel, relativeTo: gameDir) else {
                    warnings.append("Skipped unsafe override file: \(cleanRel)")
                    continue
                }

                let destURL = gameDir.appendingPathComponent(cleanRel)
                try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                try fm.copyItem(at: fileURL, to: destURL)
                overrideFiles += 1
            }
        }
        return (overrideFiles, warnings)
    }

    private func countOverrideFiles(in directory: URL) -> Int {
        let fm = FileManager.default
        var count = 0
        for folder in ["overrides", "client-overrides"] {
            let folderURL = directory.appendingPathComponent(folder, isDirectory: true)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: folderURL.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            guard let enumerator = fm.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsPackageDescendants]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
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
                count += 1
            }
        }
        return count
    }
}
