import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// The mods of a hosted world, as the exact Modrinth versions the host has installed.
/// Travels in the lobby's `pack_url` / `pack_sha1` fields, so the guest installs the same files.
public struct LobbyModList: Sendable, Equatable {
    static let prefix = "modrinth:"

    public var versionIDs: [String]
    /// Enabled mods the host has that carry no Modrinth record (added by hand), so a guest cannot get them.
    public var unsyncedCount: Int

    public init(versionIDs: [String], unsyncedCount: Int = 0) {
        self.versionIDs = versionIDs
        self.unsyncedCount = unsyncedCount
    }

    public init(mods: [InstalledMod]) {
        var ids = Set<String>()
        var unsynced = 0
        for mod in mods where mod.isEnabled {
            if let id = mod.record?.versionId, !id.isEmpty {
                ids.insert(id)
            } else {
                unsynced += 1
            }
        }
        self.init(versionIDs: ids.sorted(), unsyncedCount: unsynced)
    }

    /// The `pack_url` text and its `pack_sha1`; nil when the list is empty.
    public var packFields: (url: String, sha1: String)? {
        guard !versionIDs.isEmpty else { return nil }
        let text = Self.prefix + versionIDs.joined(separator: ",")
        guard let sha1 = Self.sha1(of: Data(text.utf8)) else { return nil }
        return (text, sha1)
    }

    /// Reads the fields back; nil when they are not a mod list or the hash does not match.
    public init?(packURL: String?, packSHA1: String?) {
        guard let packURL, packURL.hasPrefix(Self.prefix),
              let packSHA1, Self.sha1(of: Data(packURL.utf8)) == packSHA1
        else { return nil }
        let ids = packURL.dropFirst(Self.prefix.count).split(separator: ",").map(String.init)
        let valid = CharacterSet.alphanumerics
        guard !ids.isEmpty, ids.allSatisfy({ !$0.isEmpty && $0.count <= 16 && $0.unicodeScalars.allSatisfy(valid.contains) })
        else { return nil }
        self.init(versionIDs: ids)
    }

    static func sha1(of data: Data) -> String? {
        #if canImport(CryptoKit)
        return Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #else
        return nil
        #endif
    }
}

public struct LobbyModSyncResult: Sendable, Equatable {
    public var installed = 0
    public var alreadyPresent = 0
    /// Versions Modrinth no longer serves.
    public var unavailable = 0
    /// Mods the instance had that the lobby does not use; switched off, not deleted.
    public var switchedOff = 0
}

/// Makes a guest's lobby instance carry exactly the host's mods.
public final class LobbySyncer: Sendable {
    private let manager: ModManager

    public init(manager: ModManager) {
        self.manager = manager
    }

    public func sync(
        _ list: LobbyModList,
        into instance: String,
        switchOffExtras: Bool = true,
        progress: (@Sendable (_ done: Int, _ total: Int) -> Void)? = nil
    ) async throws -> LobbyModSyncResult {
        var result = LobbyModSyncResult()
        let versions = try await manager.client.versions(ids: list.versionIDs)
        result.unavailable = list.versionIDs.count - versions.count

        let projects = (try? await manager.client.projects(ids: Array(Set(versions.map(\.projectId))))) ?? []
        let projectByID = Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let modsDir = manager.modsDirectory(for: instance)
        let fm = FileManager.default
        try fm.createDirectory(at: modsDir, withIntermediateDirectories: true)

        var wanted = Set<String>()
        var records = manager.loadRecords(instance: instance)
        var done = 0
        progress?(0, versions.count)

        for version in versions {
            guard let file = version.primaryFile, Self.isSafe(file.filename) else {
                result.unavailable += 1
                continue
            }
            wanted.insert(file.filename)
            let target = modsDir.appendingPathComponent(file.filename)
            let disabled = modsDir.appendingPathComponent(file.filename + ".disabled")
            if fm.fileExists(atPath: target.path) {
                result.alreadyPresent += 1
            } else if fm.fileExists(atPath: disabled.path) {
                try fm.moveItem(at: disabled, to: target)
                result.alreadyPresent += 1
            } else {
                try await manager.downloader.download(url: file.url, to: target, sha1: file.sha1, size: file.size)
                result.installed += 1
            }
            let project = projectByID[version.projectId]
            records.removeAll { $0.fileName == file.filename }
            records.append(ModRecord(
                fileName: file.filename,
                projectId: version.projectId,
                versionId: version.id,
                title: project?.title ?? version.name,
                versionNumber: version.versionNumber,
                iconURL: project?.iconURL
            ))
            done += 1
            progress?(done, versions.count)
        }
        try manager.saveRecords(records, instance: instance)

        for mod in try manager.list(instance: instance) where switchOffExtras && mod.isEnabled && !wanted.contains(mod.fileName) {
            try manager.setEnabled(instance: instance, fileName: mod.fileName, enabled: false)
            result.switchedOff += 1
        }
        return result
    }

    /// A file name from the network must stay inside the mods folder.
    static func isSafe(_ name: String) -> Bool {
        !name.isEmpty && name.hasSuffix(".jar") && !name.contains("/") && !name.contains("\\") && !name.hasPrefix(".")
    }
}
