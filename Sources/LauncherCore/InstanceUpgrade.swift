import Foundation

public struct SnapshotInfo: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var reason: String
    public var createdAt: Date
    public var gameVersion: String?
    public var sizeBytes: Int64

    public init(
        id: String,
        reason: String,
        createdAt: Date,
        gameVersion: String? = nil,
        sizeBytes: Int64 = 0
    ) {
        self.id = id
        self.reason = reason
        self.createdAt = createdAt
        self.gameVersion = gameVersion
        self.sizeBytes = sizeBytes
    }
}

public typealias UpgradeProgress = @Sendable (String) -> Void

public struct UpgradeReport: Sendable {
    public let snapshot: SnapshotInfo
    public let updated: [String]
    public let disabled: [String]
    public let failed: [String]
    public let newVersionId: String

    public init(
        snapshot: SnapshotInfo,
        updated: [String],
        disabled: [String],
        failed: [String],
        newVersionId: String
    ) {
        self.snapshot = snapshot
        self.updated = updated
        self.disabled = disabled
        self.failed = failed
        self.newVersionId = newVersionId
    }
}

public enum InstanceUpgradeError: Error, LocalizedError, Sendable {
    case unsupportedLoader(String)
    case sameVersion
    case snapshotNotFound(String)
    case noFabricForVersion(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedLoader(let loader):
            return "Only 'fabric' instances can change version (found '\(loader)')"
        case .sameVersion:
            return "Instance is already on this version"
        case .snapshotNotFound(let id):
            return "Snapshot '\(id)' not found"
        case .noFabricForVersion(let version):
            return "No Fabric loader available for Minecraft version '\(version)'"
        }
    }
}

public final class InstanceUpgrader: Sendable {
    public let store: InstanceStore
    public let launcher: GameLauncher
    public let mods: ModManager

    public init(store: InstanceStore, launcher: GameLauncher, mods: ModManager) {
        self.store = store
        self.launcher = launcher
        self.mods = mods
    }

    private func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    private func computeDirectorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
               values.isDirectory != true,
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    public func createSnapshot(instance name: String, reason: String) throws -> SnapshotInfo {
        let fm = FileManager.default
        let instDir = store.instanceDirectory(for: name)
        guard fm.fileExists(atPath: instDir.path) else {
            throw InstanceStoreError.instanceNotFound(name)
        }

        let backupsDir = instDir.appendingPathComponent("backups", isDirectory: true)
        try fm.createDirectory(at: backupsDir, withIntermediateDirectories: true, attributes: nil)

        let now = Date()
        let timestamp = makeDateFormatter().string(from: now)
        let folderName = "\(timestamp)-\(reason)"
        let snapshotDir = backupsDir.appendingPathComponent(folderName, isDirectory: true)
        try fm.createDirectory(at: snapshotDir, withIntermediateDirectories: true, attributes: nil)

        let gameDir = store.gameDirectory(for: name)
        let savesSrc = gameDir.appendingPathComponent("saves", isDirectory: true)
        let modsSrc = gameDir.appendingPathComponent("mods", isDirectory: true)
        let modsJSONSrc = instDir.appendingPathComponent("mods.json")
        let instanceJSONSrc = store.instanceJSON(for: name)

        if fm.fileExists(atPath: savesSrc.path) {
            try fm.copyItem(at: savesSrc, to: snapshotDir.appendingPathComponent("saves", isDirectory: true))
        }
        if fm.fileExists(atPath: modsSrc.path) {
            try fm.copyItem(at: modsSrc, to: snapshotDir.appendingPathComponent("mods", isDirectory: true))
        }
        if fm.fileExists(atPath: modsJSONSrc.path) {
            try fm.copyItem(at: modsJSONSrc, to: snapshotDir.appendingPathComponent("mods.json"))
        }
        if fm.fileExists(atPath: instanceJSONSrc.path) {
            try fm.copyItem(at: instanceJSONSrc, to: snapshotDir.appendingPathComponent("instance.json"))
        }

        var gameVersion: String? = nil
        let snapInstanceJSON = snapshotDir.appendingPathComponent("instance.json")
        if let data = try? Data(contentsOf: snapInstanceJSON),
           let inst = try? JSONDecoder().decode(Instance.self, from: data) {
            gameVersion = inst.minecraftVersion
        }

        let size = computeDirectorySize(at: snapshotDir)
        return SnapshotInfo(
            id: folderName,
            reason: reason,
            createdAt: now,
            gameVersion: gameVersion,
            sizeBytes: size
        )
    }

    public func listSnapshots(instance name: String) throws -> [SnapshotInfo] {
        let fm = FileManager.default
        let backupsDir = store.instanceDirectory(for: name).appendingPathComponent("backups", isDirectory: true)
        guard fm.fileExists(atPath: backupsDir.path) else {
            return []
        }

        let entries = try fm.contentsOfDirectory(
            at: backupsDir,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )

        var snapshots: [SnapshotInfo] = []
        let formatter = makeDateFormatter()

        for entry in entries {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            let folderName = entry.lastPathComponent
            var reason = "unknown"
            var createdAt = Date()

            if folderName.count > 16 && folderName[folderName.index(folderName.startIndex, offsetBy: 15)] == "-" {
                let dateStr = String(folderName.prefix(15))
                reason = String(folderName.dropFirst(16))
                if let d = formatter.date(from: dateStr) {
                    createdAt = d
                } else if let attrs = try? fm.attributesOfItem(atPath: entry.path),
                          let cd = attrs[.creationDate] as? Date {
                    createdAt = cd
                }
            } else if let attrs = try? fm.attributesOfItem(atPath: entry.path),
                      let cd = attrs[.creationDate] as? Date {
                createdAt = cd
                reason = folderName
            }

            var gameVersion: String? = nil
            let snapInstanceJSON = entry.appendingPathComponent("instance.json")
            if let data = try? Data(contentsOf: snapInstanceJSON),
               let inst = try? JSONDecoder().decode(Instance.self, from: data) {
                gameVersion = inst.minecraftVersion
            }

            let size = computeDirectorySize(at: entry)
            snapshots.append(SnapshotInfo(
                id: folderName,
                reason: reason,
                createdAt: createdAt,
                gameVersion: gameVersion,
                sizeBytes: size
            ))
        }

        return snapshots.sorted { $0.createdAt > $1.createdAt }
    }

    public func restore(instance name: String, snapshot id: String) throws {
        let fm = FileManager.default
        let instDir = store.instanceDirectory(for: name)
        let backupsDir = instDir.appendingPathComponent("backups", isDirectory: true)
        let snapshotDir = backupsDir.appendingPathComponent(id, isDirectory: true)

        guard fm.fileExists(atPath: snapshotDir.path) else {
            throw InstanceUpgradeError.snapshotNotFound(id)
        }

        _ = try createSnapshot(instance: name, reason: "before-restore")

        let gameDir = store.gameDirectory(for: name)
        let currentSaves = gameDir.appendingPathComponent("saves", isDirectory: true)
        let currentMods = gameDir.appendingPathComponent("mods", isDirectory: true)

        #if os(macOS)
        if fm.fileExists(atPath: currentSaves.path) {
            try fm.trashItem(at: currentSaves, resultingItemURL: nil)
        }
        if fm.fileExists(atPath: currentMods.path) {
            try fm.trashItem(at: currentMods, resultingItemURL: nil)
        }
        #else
        throw InstanceStoreError.trashUnsupported
        #endif

        try fm.createDirectory(at: gameDir, withIntermediateDirectories: true, attributes: nil)

        let snapSaves = snapshotDir.appendingPathComponent("saves", isDirectory: true)
        let snapMods = snapshotDir.appendingPathComponent("mods", isDirectory: true)
        let snapModsJSON = snapshotDir.appendingPathComponent("mods.json")
        let snapInstanceJSON = snapshotDir.appendingPathComponent("instance.json")

        if fm.fileExists(atPath: snapSaves.path) {
            try fm.copyItem(at: snapSaves, to: currentSaves)
        }
        if fm.fileExists(atPath: snapMods.path) {
            try fm.copyItem(at: snapMods, to: currentMods)
        }

        let currentModsJSON = instDir.appendingPathComponent("mods.json")
        if fm.fileExists(atPath: snapModsJSON.path) {
            if fm.fileExists(atPath: currentModsJSON.path) {
                try fm.removeItem(at: currentModsJSON)
            }
            try fm.copyItem(at: snapModsJSON, to: currentModsJSON)
        }

        let currentInstanceJSON = store.instanceJSON(for: name)
        if fm.fileExists(atPath: snapInstanceJSON.path) {
            if fm.fileExists(atPath: currentInstanceJSON.path) {
                try fm.removeItem(at: currentInstanceJSON)
            }
            try fm.copyItem(at: snapInstanceJSON, to: currentInstanceJSON)
        }
    }

    public func upgrade(
        instance name: String,
        to gameVersion: String,
        progress: UpgradeProgress = { _ in }
    ) async throws -> UpgradeReport {
        let instance = try store.load(name: name)
        guard instance.loader.lowercased() == "fabric" else {
            throw InstanceUpgradeError.unsupportedLoader(instance.loader)
        }
        guard instance.minecraftVersion != gameVersion else {
            throw InstanceUpgradeError.sameVersion
        }

        progress("Backing up worlds and mods")
        let snapshot = try createSnapshot(instance: name, reason: "before-\(gameVersion)")

        progress("Installing Minecraft \(gameVersion) and Fabric")
        var installCopy = instance
        installCopy.minecraftVersion = gameVersion
        installCopy.versionId = ""
        installCopy.loaderVersion = nil

        let updatedInstalled: Instance
        do {
            updatedInstalled = try await launcher.ensureInstalled(installCopy, force: true)
        } catch {
            throw InstanceUpgradeError.noFabricForVersion(gameVersion)
        }

        var newInstance = instance
        newInstance.minecraftVersion = gameVersion
        newInstance.versionId = updatedInstalled.versionId
        newInstance.loaderVersion = updatedInstalled.loaderVersion
        try store.save(newInstance)

        let fm = FileManager.default
        let modsDir = store.gameDirectory(for: name).appendingPathComponent("mods", isDirectory: true)
        let modsJSONURL = store.instanceDirectory(for: name).appendingPathComponent("mods.json")
        try fm.createDirectory(at: modsDir, withIntermediateDirectories: true, attributes: nil)

        var records: [ModRecord] = []
        if fm.fileExists(atPath: modsJSONURL.path),
           let data = try? Data(contentsOf: modsJSONURL),
           let decoded = try? JSONDecoder().decode([ModRecord].self, from: data) {
            records = decoded
        }

        var updatedTitles: [String] = []
        var disabledTitles: [String] = []
        var failedTitles: [String] = []

        for i in 0..<records.count {
            let record = records[i]
            do {
                let best = try await mods.client.bestVersion(
                    project: record.projectId,
                    gameVersion: gameVersion,
                    loader: "fabric"
                )
                if let best = best, let primaryFile = best.primaryFile {
                    progress("Updating \(record.title)")
                    let enabledURL = modsDir.appendingPathComponent(record.fileName)
                    let disabledURL = modsDir.appendingPathComponent("\(record.fileName).disabled")
                    let wasDisabled = fm.fileExists(atPath: disabledURL.path)
                    let oldFileURL = wasDisabled ? disabledURL : enabledURL

                    let targetFileName = wasDisabled ? "\(primaryFile.filename).disabled" : primaryFile.filename
                    let targetURL = modsDir.appendingPathComponent(targetFileName)

                    try await mods.downloader.download(
                        url: primaryFile.url,
                        to: targetURL,
                        sha1: primaryFile.sha1,
                        size: primaryFile.size
                    )

                    #if os(macOS)
                    if fm.fileExists(atPath: oldFileURL.path) && oldFileURL != targetURL {
                        try fm.trashItem(at: oldFileURL, resultingItemURL: nil)
                    }
                    #endif

                    var newRecord = record
                    newRecord.fileName = primaryFile.filename
                    newRecord.versionId = best.id
                    newRecord.versionNumber = best.versionNumber
                    records[i] = newRecord
                    updatedTitles.append(record.title)
                } else {
                    progress("No \(gameVersion) version of \(record.title): disabled")
                    let enabledURL = modsDir.appendingPathComponent(record.fileName)
                    let disabledURL = modsDir.appendingPathComponent("\(record.fileName).disabled")
                    if fm.fileExists(atPath: enabledURL.path) {
                        if fm.fileExists(atPath: disabledURL.path) {
                            try? fm.removeItem(at: disabledURL)
                        }
                        try fm.moveItem(at: enabledURL, to: disabledURL)
                    }
                    disabledTitles.append(record.title)
                }
            } catch {
                failedTitles.append(record.title)
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: modsJSONURL, options: .atomic)

        return UpgradeReport(
            snapshot: snapshot,
            updated: updatedTitles,
            disabled: disabledTitles,
            failed: failedTitles,
            newVersionId: newInstance.versionId
        )
    }
}
