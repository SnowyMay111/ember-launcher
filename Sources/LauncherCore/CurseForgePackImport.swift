import Foundation

/// manifest.json of a CurseForge modpack .zip.
struct CurseForgePackManifest: Decodable, Sendable {
    struct Minecraft: Decodable, Sendable {
        let version: String
        let modLoaders: [ModLoader]?
    }

    struct ModLoader: Decodable, Sendable {
        let id: String
        let primary: Bool?
    }

    struct File: Decodable, Sendable {
        let projectID: Int
        let fileID: Int
    }

    let manifestType: String
    let name: String?
    let version: String?
    let minecraft: Minecraft
    let files: [File]?
    let overrides: String?
}

private struct CurseForgePackItem: Sendable {
    let projectID: Int
    let file: CurseForgeFile
    let mod: CurseForgeMod?
    let path: String
    let url: URL
    let sha1: String
}

private enum CurseForgeDownloadResult: Sendable {
    case success(CurseForgePackItem)
    case failed(path: String, reason: String)
}

extension ModpackManager {
    /// The manifest when the extracted archive is a CurseForge pack; nil sends it down the .mrpack path.
    static func curseForgeManifest(in directory: URL) throws -> CurseForgePackManifest? {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: directory.appendingPathComponent("modrinth.index.json").path),
              let data = fm.contents(atPath: directory.appendingPathComponent("manifest.json").path) else {
            return nil
        }
        struct Probe: Decodable { let manifestType: String? }
        guard (try? JSONDecoder().decode(Probe.self, from: data))?.manifestType == "minecraftModpack" else {
            return nil
        }
        do {
            return try JSONDecoder().decode(CurseForgePackManifest.self, from: data)
        } catch {
            throw ModpackError.invalidArchive("manifest.json is invalid: \(error.localizedDescription)")
        }
    }

    /// "forge-47.2.0" -> ("forge", "47.2.0"); nil for unknown loaders.
    static func parseCurseForgeLoaderID(_ id: String) -> (loader: String, version: String)? {
        let lower = id.lowercased()
        for loader in ["neoforge", "forge", "fabric", "quilt"] {
            let prefix = loader + "-"
            if lower.hasPrefix(prefix), id.count > prefix.count {
                return (loader, String(id.dropFirst(prefix.count)))
            }
        }
        return nil
    }

    static func curseForgeTarget(
        of manifest: CurseForgePackManifest
    ) throws -> (minecraftVersion: String, loader: String, loaderVersion: String?) {
        let minecraftVersion = manifest.minecraft.version
        guard !minecraftVersion.isEmpty else {
            throw ModpackError.missingDependency("minecraft")
        }
        let loaders = manifest.minecraft.modLoaders ?? []
        guard let entry = loaders.first(where: { $0.primary == true }) ?? loaders.first else {
            return (minecraftVersion, "vanilla", nil)
        }
        guard let parsed = parseCurseForgeLoaderID(entry.id) else {
            throw ModpackError.invalidArchive("Unsupported mod loader: \(entry.id)")
        }
        return (minecraftVersion, parsed.loader, parsed.version)
    }

    /// The report line for a file the author does not allow third-party launchers to download; nil when it can be downloaded.
    static func blockedDownloadWarning(
        name: String,
        downloadURL: String?,
        distributionAllowed: Bool?,
        pageURL: URL?,
        projectID: Int
    ) -> String? {
        guard downloadURL == nil, distributionAllowed == false else { return nil }
        let page = pageURL?.absoluteString ?? "https://www.curseforge.com/projects/\(projectID)"
        return "\(name): download is blocked by the author, get it on CurseForge: \(page)"
    }

    static func curseForgeFolder(classId: Int?) -> String {
        switch classId {
        case CurseForgeClient.classResourcePack: return "resourcepacks"
        case CurseForgeClient.classShader: return "shaderpacks"
        default: return "mods"
        }
    }

    func curseForgeOverridesFolder(_ manifest: CurseForgePackManifest, in tempDir: URL) throws -> String {
        let trimmed = (manifest.overrides ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let folder = trimmed.isEmpty ? "overrides" : trimmed
        guard isSafeRelativePath(folder, relativeTo: tempDir) else {
            throw ModpackError.unsafePath(folder)
        }
        return folder
    }

    func curseForgeSummary(_ manifest: CurseForgePackManifest, in tempDir: URL) throws -> MrpackSummary {
        let (minecraftVersion, loader, loaderVersion) = try Self.curseForgeTarget(of: manifest)
        let folder = try curseForgeOverridesFolder(manifest, in: tempDir)
        return MrpackSummary(
            name: manifest.name ?? "Modpack",
            versionLabel: manifest.version ?? "",
            minecraftVersion: minecraftVersion,
            loader: loader,
            loaderVersion: loaderVersion,
            fileCount: Set((manifest.files ?? []).map(\.fileID)).count,
            overrideFileCount: countOverrideFiles(in: tempDir, folders: [folder]),
            overrideJarCount: countOverrideJars(in: tempDir, folders: [folder]),
            downloadBytes: 0
        )
    }

    func importCurseForgePack(
        _ manifest: CurseForgePackManifest,
        extractedAt tempDir: URL,
        name: String?,
        group: String?,
        memoryMB: Int,
        excludedPaths: Set<String>,
        progress: @escaping @Sendable (String, Double) -> Void
    ) async throws -> MrpackImportReport {
        let (minecraftVersion, loader, loaderVersion) = try Self.curseForgeTarget(of: manifest)
        let overridesFolder = try curseForgeOverridesFolder(manifest, in: tempDir)

        let finalName = store.uniqueName(base: name ?? manifest.name ?? "Modpack", fallback: "Modpack")
        let gameDir = store.gameDirectory(for: finalName)

        let resolved = try await resolveCurseForgeFiles(manifest.files ?? [], gameDir: gameDir, excludedPaths: excludedPaths)
        var failed = resolved.failed
        var warnings = resolved.warnings

        progress("Reading the pack", 1.0)

        // Loaders are installed on the first Play, which fills in the version id.
        let isVanilla = loader == "vanilla"
        try store.create(Instance(
            name: finalName,
            minecraftVersion: minecraftVersion,
            loader: loader,
            loaderVersion: isVanilla ? nil : loaderVersion,
            versionId: isVanilla ? minecraftVersion : "",
            memoryMB: memoryMB,
            group: group
        ))

        do {
            var downloaded: [CurseForgePackItem] = []
            let totalDownloads = resolved.items.count

            if totalDownloads == 0 {
                progress("Downloading mods", 1.0)
            } else {
                progress("Downloading mods", 0.0)
                var completedCount = 0
                let maxConcurrency = 6

                try await withThrowingTaskGroup(of: CurseForgeDownloadResult.self) { tasks in
                    var iterator = resolved.items.makeIterator()
                    var inFlight = 0

                    while inFlight < maxConcurrency, let item = iterator.next() {
                        inFlight += 1
                        tasks.addTask { try await self.downloadCurseForgeItem(item, gameDir: gameDir) }
                    }

                    while let result = try await tasks.next() {
                        inFlight -= 1
                        completedCount += 1
                        progress("Downloading mods", Double(completedCount) / Double(totalDownloads))

                        switch result {
                        case .success(let item):
                            downloaded.append(item)
                        case .failed(let path, let reason):
                            failed.append("\(path): \(reason)")
                        }

                        if let next = iterator.next() {
                            inFlight += 1
                            tasks.addTask { try await self.downloadCurseForgeItem(next, gameDir: gameDir) }
                        }
                    }
                }
                try Task.checkCancellation()
            }

            progress("Copying files", 0.0)
            let (overrideFiles, overrideWarnings) = try copyOverrides(from: tempDir, to: gameDir, folders: [overridesFolder])
            warnings += overrideWarnings
            progress("Copying files", 1.0)

            progress("Finishing", 0.0)

            let records = downloaded.filter { $0.path.hasPrefix("mods/") }.map { item in
                ModRecord(
                    fileName: item.file.fileName,
                    projectId: "cf:\(item.projectID)",
                    versionId: "cf:\(item.projectID):\(item.file.id)",
                    title: item.mod?.name ?? (item.file.fileName as NSString).deletingPathExtension,
                    versionNumber: item.file.displayName,
                    iconURL: item.mod.flatMap { CurseForgeClient.iconURL(of: $0) },
                    isDependency: false,
                    installedFor: nil
                )
            }
            if !records.isEmpty {
                let modManager = ModManager(store: store, client: client, downloader: downloader)
                try modManager.saveRecords(records, instance: finalName)
            }

            progress("Finishing", 1.0)

            return MrpackImportReport(
                instanceName: finalName,
                filesInstalled: downloaded.count,
                failed: failed,
                overrideFiles: overrideFiles,
                warnings: warnings
            )
        } catch {
            try? store.moveToTrash(finalName)
            throw error
        }
    }

    /// Looks up every file and project in batches; optional (`required: false`) entries are installed too.
    private func resolveCurseForgeFiles(
        _ entries: [CurseForgePackManifest.File],
        gameDir: URL,
        excludedPaths: Set<String>
    ) async throws -> (items: [CurseForgePackItem], failed: [String], warnings: [String]) {
        var seen = Set<Int>()
        let unique = entries.filter { seen.insert($0.fileID).inserted }
        guard !unique.isEmpty else { return ([], [], []) }

        let curseForge = client.curseForge
        let fileIDs = unique.map(\.fileID)
        let projectIDs = Array(Set(unique.map(\.projectID)))
        async let filesTask = curseForge.files(ids: fileIDs)
        async let modsTask = curseForge.mods(numericIDs: projectIDs)
        let files = Dictionary(try await filesTask.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let mods = Dictionary(try await modsTask.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var items: [CurseForgePackItem] = []
        var failed: [String] = []
        var warnings: [String] = []
        for entry in unique {
            guard let file = files[entry.fileID] else {
                failed.append("cf:\(entry.projectID):\(entry.fileID): file not found on CurseForge")
                continue
            }
            let mod = mods[entry.projectID]
            let displayName = mod.map { $0.name.isEmpty ? $0.slug : $0.name } ?? file.displayName
            if let warning = Self.blockedDownloadWarning(
                name: displayName,
                downloadURL: file.downloadUrl,
                distributionAllowed: mod?.allowModDistribution,
                pageURL: mod?.websiteURL,
                projectID: entry.projectID
            ) {
                warnings.append(warning)
                continue
            }

            let path = "\(Self.curseForgeFolder(classId: mod?.classId))/\(file.fileName)"
            guard !excludedPaths.contains(path) else { continue }
            guard ModrinthFile.isSafeFilename(file.fileName), isSafeRelativePath(path, relativeTo: gameDir) else {
                failed.append("\(path): unsafe file name")
                continue
            }

            let url = file.downloadUrl.flatMap { URL(string: $0) }
                ?? CurseForgeClient.cdnURL(fileId: file.id, fileName: file.fileName)
            guard let url, url.scheme?.lowercased() == "https",
                  let host = url.host?.lowercased(), host == "forgecdn.net" || host.hasSuffix(".forgecdn.net") else {
                failed.append("\(path): download host not allowed")
                continue
            }
            guard let sha1 = file.hashes.first(where: { $0.algo == 1 })?.value, !sha1.isEmpty else {
                failed.append("\(path): missing hashes")
                continue
            }
            items.append(CurseForgePackItem(projectID: entry.projectID, file: file, mod: mod, path: path, url: url, sha1: sha1))
        }
        return (items, failed, warnings)
    }

    private func downloadCurseForgeItem(
        _ item: CurseForgePackItem,
        gameDir: URL
    ) async throws -> CurseForgeDownloadResult {
        let destURL = gameDir.appendingPathComponent(item.path)
        do {
            try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try await downloader.download(url: item.url, to: destURL, sha1: item.sha1, size: item.file.fileLength)
            return .success(item)
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled {
                throw CancellationError()
            }
            return .failed(path: item.path, reason: error.localizedDescription)
        }
    }
}

extension ModpackManager {
    /// Preview entries for a CurseForge pack: one per mod file, paths as the importer will write them.
    func curseForgePreview(
        _ manifest: CurseForgePackManifest,
        extractedAt tempDir: URL,
        archive: URL,
        workDir: URL
    ) async throws -> ModpackPreview {
        let summary = try curseForgeSummary(manifest, in: tempDir)
        var seen = Set<Int>()
        let unique = (manifest.files ?? []).filter { seen.insert($0.fileID).inserted }
        var entries: [ModpackPreviewEntry] = []
        if !unique.isEmpty {
            let curseForge = client.curseForge
            async let filesTask = curseForge.files(ids: unique.map(\.fileID))
            async let modsTask = curseForge.mods(numericIDs: Array(Set(unique.map(\.projectID))))
            let files = Dictionary(try await filesTask.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let mods = Dictionary(try await modsTask.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for entry in unique {
                guard let file = files[entry.fileID], ModrinthFile.isSafeFilename(file.fileName) else { continue }
                let mod = mods[entry.projectID]
                // Files the author does not allow third-party launchers to download are reported by the importer.
                if file.downloadUrl == nil, mod?.allowModDistribution == false { continue }
                let path = "\(Self.curseForgeFolder(classId: mod?.classId))/\(file.fileName)"
                entries.append(ModpackPreviewEntry(
                    id: path,
                    path: path,
                    fileName: file.fileName,
                    kind: ModpackPreviewKind(path: path),
                    projectId: "cf:\(entry.projectID)",
                    versionId: "cf:\(entry.projectID):\(file.id)",
                    title: mod.map { $0.name.isEmpty ? $0.slug : $0.name } ?? (file.fileName as NSString).deletingPathExtension,
                    summary: mod?.summary,
                    iconURL: mod.flatMap { CurseForgeClient.iconURL(of: $0) },
                    size: Int64(file.fileLength),
                    requiredBy: []
                ))
            }
        }
        entries.sort { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            return lhs.title.lowercased() < rhs.title.lowercased()
        }
        return ModpackPreview(summary: summary, archive: archive, workDir: workDir, entries: entries)
    }
}
