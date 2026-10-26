import Foundation

public struct ModRecord: Codable, Sendable, Equatable {
    public var fileName: String
    public var projectId: String
    public var versionId: String
    public var title: String
    public var versionNumber: String
    public var iconURL: URL?
    public var isDependency: Bool
    public var installedFor: String?

    public init(
        fileName: String,
        projectId: String,
        versionId: String,
        title: String,
        versionNumber: String,
        iconURL: URL? = nil,
        isDependency: Bool = false,
        installedFor: String? = nil
    ) {
        self.fileName = fileName
        self.projectId = projectId
        self.versionId = versionId
        self.title = title
        self.versionNumber = versionNumber
        self.iconURL = iconURL
        self.isDependency = isDependency
        self.installedFor = installedFor
    }
}

public struct InstalledMod: Sendable, Equatable, Identifiable {
    public var id: String { fileName }
    public var fileName: String
    public var isEnabled: Bool
    public var record: ModRecord?

    public var displayTitle: String {
        if let title = record?.title, !title.isEmpty {
            return title
        }
        var name = fileName
        if name.hasSuffix(".jar.disabled") {
            name = String(name.dropLast(13))
        } else if name.hasSuffix(".jar") {
            name = String(name.dropLast(4))
        }
        return name
    }

    public init(
        fileName: String,
        isEnabled: Bool,
        record: ModRecord? = nil
    ) {
        self.fileName = fileName
        self.isEnabled = isEnabled
        self.record = record
    }
}

public struct ModInstallResult: Sendable, Equatable {
    public var installed: [ModRecord]
    public var skipped: [String]
    public var warnings: [String]

    public init(
        installed: [ModRecord] = [],
        skipped: [String] = [],
        warnings: [String] = []
    ) {
        self.installed = installed
        self.skipped = skipped
        self.warnings = warnings
    }
}

public struct ModUpdate: Sendable, Equatable {
    public var record: ModRecord
    public var newVersion: ModrinthVersion

    public init(record: ModRecord, newVersion: ModrinthVersion) {
        self.record = record
        self.newVersion = newVersion
    }
}

public struct ModUpgradeCheck: Sendable, Equatable {
    public var record: ModRecord
    public var targetVersion: ModrinthVersion?

    public var isAvailable: Bool {
        targetVersion != nil
    }

    public init(record: ModRecord, targetVersion: ModrinthVersion? = nil) {
        self.record = record
        self.targetVersion = targetVersion
    }
}

public enum ModManagerError: Error, LocalizedError, Sendable, Equatable {
    case unsupportedLoader(String)
    case notFound(String)
    case incompatible(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedLoader(let loader):
            return "Mod installation requires loader 'fabric', but instance uses '\(loader)'"
        case .notFound(let item):
            return "Mod not found: \(item)"
        case .incompatible(let reason):
            return "Incompatible mod: \(reason)"
        }
    }
}

public final class ModManager: Sendable {
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

    public func modsDirectory(for instanceName: String) -> URL {
        store.gameDirectory(for: instanceName).appendingPathComponent("mods", isDirectory: true)
    }

    public func modsJSONURL(for instanceName: String) -> URL {
        store.instanceDirectory(for: instanceName).appendingPathComponent("mods.json")
    }

    func loadRecords(instance name: String) -> [ModRecord] {
        let jsonURL = modsJSONURL(for: name)
        guard FileManager.default.fileExists(atPath: jsonURL.path),
              let data = try? Data(contentsOf: jsonURL),
              let records = try? JSONDecoder().decode([ModRecord].self, from: data) else {
            return []
        }
        return records
    }

    func saveRecords(_ records: [ModRecord], instance name: String) throws {
        let instDir = store.instanceDirectory(for: name)
        let fm = FileManager.default
        if !fm.fileExists(atPath: instDir.path) {
            try fm.createDirectory(at: instDir, withIntermediateDirectories: true, attributes: nil)
        }
        let jsonURL = modsJSONURL(for: name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: jsonURL, options: .atomic)
    }

    public func list(instance name: String) throws -> [InstalledMod] {
        let modsDir = modsDirectory(for: name)
        let fm = FileManager.default
        guard fm.fileExists(atPath: modsDir.path) else {
            return []
        }
        let entries = try fm.contentsOfDirectory(
            at: modsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let records = loadRecords(instance: name)
        var recordByFileName: [String: ModRecord] = [:]
        for record in records {
            recordByFileName[record.fileName] = record
        }

        var installed: [InstalledMod] = []
        for entry in entries {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue {
                continue
            }
            let filename = entry.lastPathComponent
            let isEnabled: Bool
            let enabledFileName: String
            if filename.hasSuffix(".jar.disabled") {
                isEnabled = false
                enabledFileName = String(filename.dropLast(".disabled".count))
            } else if filename.hasSuffix(".jar") {
                isEnabled = true
                enabledFileName = filename
            } else {
                continue
            }
            let rec = recordByFileName[enabledFileName]
            installed.append(InstalledMod(fileName: enabledFileName, isEnabled: isEnabled, record: rec))
        }
        return installed.sorted {
            $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
    }

    public func setEnabled(instance name: String, fileName: String, enabled: Bool) throws {
        let modsDir = modsDirectory(for: name)
        let fm = FileManager.default
        let enabledURL = modsDir.appendingPathComponent(fileName)
        let disabledURL = modsDir.appendingPathComponent("\(fileName).disabled")
        let enabledExists = fm.fileExists(atPath: enabledURL.path)
        let disabledExists = fm.fileExists(atPath: disabledURL.path)

        guard enabledExists || disabledExists else {
            throw ModManagerError.notFound(fileName)
        }

        if enabled {
            if enabledExists { return }
            if disabledExists {
                guard !fm.fileExists(atPath: enabledURL.path) else { return }
                try fm.moveItem(at: disabledURL, to: enabledURL)
            }
        } else {
            if disabledExists { return }
            if enabledExists {
                guard !fm.fileExists(atPath: disabledURL.path) else { return }
                try fm.moveItem(at: enabledURL, to: disabledURL)
            }
        }
    }

    public func remove(instance name: String, fileName: String) throws {
        let modsDir = modsDirectory(for: name)
        let fm = FileManager.default
        let enabledURL = modsDir.appendingPathComponent(fileName)
        let disabledURL = modsDir.appendingPathComponent("\(fileName).disabled")
        let enabledExists = fm.fileExists(atPath: enabledURL.path)
        let disabledExists = fm.fileExists(atPath: disabledURL.path)

        var records = loadRecords(instance: name)
        let hadRecord = records.contains(where: { $0.fileName == fileName })
        guard enabledExists || disabledExists || hadRecord else {
            throw ModManagerError.notFound(fileName)
        }

        #if os(macOS)
        if enabledExists {
            try fm.trashItem(at: enabledURL, resultingItemURL: nil)
        } else if disabledExists {
            try fm.trashItem(at: disabledURL, resultingItemURL: nil)
        }
        #else
        throw InstanceStoreError.trashUnsupported
        #endif

        if hadRecord {
            records.removeAll(where: { $0.fileName == fileName })
            try saveRecords(records, instance: name)
        }
    }

    public func install(project idOrSlug: String, into name: String) async throws -> ModInstallResult {
        let instance = try store.load(name: name)
        guard instance.loader.lowercased() == "fabric" else {
            throw ModManagerError.unsupportedLoader(instance.loader)
        }

        guard let version = try await client.bestVersion(project: idOrSlug, gameVersion: instance.minecraftVersion, loader: "fabric") else {
            throw ModrinthError.noCompatibleVersion(project: idOrSlug, gameVersion: instance.minecraftVersion, loader: "fabric")
        }

        let project = try await client.project(idOrSlug: version.projectId)
        var currentRecords = loadRecords(instance: name)
        if let existing = currentRecords.first(where: { $0.projectId == project.id }) {
            return ModInstallResult(
                installed: [],
                skipped: ["\(existing.title) is already installed"],
                warnings: []
            )
        }

        guard let primaryFile = version.primaryFile else {
            throw ModManagerError.notFound("No file found for version \(version.name)")
        }

        let modsDir = modsDirectory(for: name)
        try FileManager.default.createDirectory(at: modsDir, withIntermediateDirectories: true, attributes: nil)

        let targetURL = modsDir.appendingPathComponent(primaryFile.filename)
        try await downloader.download(url: primaryFile.url, to: targetURL, sha1: primaryFile.sha1, size: primaryFile.size)

        let mainRecord = ModRecord(
            fileName: primaryFile.filename,
            projectId: project.id,
            versionId: version.id,
            title: project.title,
            versionNumber: version.versionNumber,
            iconURL: project.iconURL,
            isDependency: false,
            installedFor: nil
        )
        currentRecords.append(mainRecord)
        try saveRecords(currentRecords, instance: name)

        var installedRecords: [ModRecord] = [mainRecord]
        var skippedTexts: [String] = []
        var optionalProjectIds: [String] = []
        var visitedProjectIds: Set<String> = [project.id]

        func processDependencies(for ver: ModrinthVersion) async throws {
            for dep in ver.dependencies {
                guard let depProjectId = dep.projectId, !depProjectId.isEmpty else {
                    continue
                }

                switch dep.type {
                case .incompatible:
                    let recs = loadRecords(instance: name)
                    if let inc = recs.first(where: { $0.projectId == depProjectId }) {
                        throw ModManagerError.incompatible("Installed mod '\(inc.title)' is incompatible")
                    }
                case .optional:
                    if !optionalProjectIds.contains(depProjectId) {
                        optionalProjectIds.append(depProjectId)
                    }
                case .required:
                    if visitedProjectIds.contains(depProjectId) {
                        continue
                    }
                    visitedProjectIds.insert(depProjectId)

                    let recs = loadRecords(instance: name)
                    if let existing = recs.first(where: { $0.projectId == depProjectId }) {
                        skippedTexts.append("\(existing.title) is already installed")
                        continue
                    }

                    let depVersion: ModrinthVersion
                    if let vid = dep.versionId, !vid.isEmpty {
                        depVersion = try await client.version(id: vid)
                    } else {
                        guard let best = try await client.bestVersion(project: depProjectId, gameVersion: instance.minecraftVersion, loader: "fabric") else {
                            throw ModrinthError.noCompatibleVersion(project: depProjectId, gameVersion: instance.minecraftVersion, loader: "fabric")
                        }
                        depVersion = best
                    }

                    let depProject = try await client.project(idOrSlug: depVersion.projectId)
                    guard let depFile = depVersion.primaryFile else {
                        throw ModManagerError.notFound("No file found for version \(depVersion.name)")
                    }

                    let depDest = modsDir.appendingPathComponent(depFile.filename)
                    try await downloader.download(url: depFile.url, to: depDest, sha1: depFile.sha1, size: depFile.size)

                    let depRecord = ModRecord(
                        fileName: depFile.filename,
                        projectId: depProject.id,
                        versionId: depVersion.id,
                        title: depProject.title,
                        versionNumber: depVersion.versionNumber,
                        iconURL: depProject.iconURL,
                        isDependency: true,
                        installedFor: project.title
                    )
                    var updatedRecords = loadRecords(instance: name)
                    updatedRecords.append(depRecord)
                    try saveRecords(updatedRecords, instance: name)
                    installedRecords.append(depRecord)

                    try await processDependencies(for: depVersion)
                case .embedded, .unknown:
                    break
                }
            }
        }

        try await processDependencies(for: version)

        var warnings: [String] = []
        if !optionalProjectIds.isEmpty {
            if let optProjects = try? await client.projects(ids: optionalProjectIds) {
                for opt in optProjects {
                    warnings.append("Optional: \(opt.title)")
                }
            }
        }

        return ModInstallResult(
            installed: installedRecords,
            skipped: skippedTexts,
            warnings: warnings
        )
    }

    public func updates(instance name: String) async throws -> [ModUpdate] {
        let instance = try store.load(name: name)
        let records = loadRecords(instance: name)
        let modsDir = modsDirectory(for: name)
        let fm = FileManager.default

        var updates: [ModUpdate] = []
        for record in records {
            let enabledURL = modsDir.appendingPathComponent(record.fileName)
            let disabledURL = modsDir.appendingPathComponent("\(record.fileName).disabled")
            guard fm.fileExists(atPath: enabledURL.path) || fm.fileExists(atPath: disabledURL.path) else {
                continue
            }

            do {
                if let best = try await client.bestVersion(project: record.projectId, gameVersion: instance.minecraftVersion, loader: instance.loader) {
                    if best.id != record.versionId {
                        updates.append(ModUpdate(record: record, newVersion: best))
                    }
                }
            } catch {
            }
        }
        return updates
    }

    public func apply(update: ModUpdate, instance name: String) async throws {
        let record = update.record
        let newVersion = update.newVersion
        guard let newFile = newVersion.primaryFile else {
            throw ModManagerError.notFound("No file found for version \(newVersion.name)")
        }

        let modsDir = modsDirectory(for: name)
        let fm = FileManager.default
        let enabledURL = modsDir.appendingPathComponent(record.fileName)
        let disabledURL = modsDir.appendingPathComponent("\(record.fileName).disabled")
        let wasDisabled = fm.fileExists(atPath: disabledURL.path)
        let oldFileURL = wasDisabled ? disabledURL : enabledURL

        let targetURL = wasDisabled
            ? modsDir.appendingPathComponent("\(newFile.filename).disabled")
            : modsDir.appendingPathComponent(newFile.filename)

        let tempURL = modsDir.appendingPathComponent("\(newFile.filename).download.\(UUID().uuidString)")
        try await downloader.download(url: newFile.url, to: tempURL, sha1: newFile.sha1, size: newFile.size)

        #if os(macOS)
        if fm.fileExists(atPath: oldFileURL.path) {
            try fm.trashItem(at: oldFileURL, resultingItemURL: nil)
        }
        #else
        throw InstanceStoreError.trashUnsupported
        #endif

        if fm.fileExists(atPath: targetURL.path) {
            try fm.removeItem(at: targetURL)
        }
        try fm.moveItem(at: tempURL, to: targetURL)

        var records = loadRecords(instance: name)
        let newRecord = ModRecord(
            fileName: newFile.filename,
            projectId: record.projectId,
            versionId: newVersion.id,
            title: record.title,
            versionNumber: newVersion.versionNumber,
            iconURL: record.iconURL,
            isDependency: record.isDependency,
            installedFor: record.installedFor
        )
        if let idx = records.firstIndex(where: { $0.fileName == record.fileName || $0.projectId == record.projectId }) {
            records[idx] = newRecord
        } else {
            records.append(newRecord)
        }
        try saveRecords(records, instance: name)
    }

    public func checkUpgrade(instance name: String, to gameVersion: String) async throws -> [ModUpgradeCheck] {
        let instance = try store.load(name: name)
        let records = loadRecords(instance: name)

        var results: [ModUpgradeCheck] = []
        for record in records {
            do {
                let best = try await client.bestVersion(project: record.projectId, gameVersion: gameVersion, loader: instance.loader)
                results.append(ModUpgradeCheck(record: record, targetVersion: best))
            } catch {
                results.append(ModUpgradeCheck(record: record, targetVersion: nil))
            }
        }
        return results
    }
}
