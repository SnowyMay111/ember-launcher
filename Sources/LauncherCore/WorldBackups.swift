import Foundation

/// A singleplayer world: a folder in the instance's `saves/` with a `level.dat`.
public struct SingleplayerWorld: Equatable, Identifiable, Sendable {
    public var id: String { folderName }
    public let folderName: String
    public let url: URL
    /// Last time anything in the world changed (newest file in the folder).
    public let lastChanged: Date
    public let bytes: Int64
}

/// One copy of a world made by Ember.
public struct SingleplayerBackup: Equatable, Identifiable, Sendable {
    public var id: String { url.lastPathComponent }
    public let url: URL
    public let date: Date
    public let bytes: Int64
    public let isAutomatic: Bool
}

/// Copies of singleplayer worlds live next to the instance, outside `minecraft/`, in `world-backups/<world>/<time>`.
/// Nothing here deletes a world: restoring parks the current one in `before-restore-*`, and only old *automatic* copies are pruned.
public struct WorldBackups: Sendable {
    public static let autoPrefix = "auto-"
    public static let manualPrefix = "manual-"
    public static let parkedPrefix = "before-restore-"

    private let savesDirectory: URL
    private let backupsRoot: URL

    public init(store: InstanceStore, instance name: String) {
        savesDirectory = store.gameDirectory(for: name).appendingPathComponent("saves", isDirectory: true)
        backupsRoot = store.instanceDirectory(for: name).appendingPathComponent("world-backups", isDirectory: true)
    }

    public func worlds() -> [SingleplayerWorld] {
        let entries = (try? FileManager.default.contentsOfDirectory(at: savesDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return entries
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("level.dat").path) }
            .map { url in
                let (size, changed) = Self.scan(url)
                return SingleplayerWorld(folderName: url.lastPathComponent, url: url, lastChanged: changed, bytes: size)
            }
            .sorted { $0.lastChanged > $1.lastChanged }
    }

    public func backups(of world: String) -> [SingleplayerBackup] {
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: backupsRoot.appendingPathComponent(world, isDirectory: true), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return entries
            .filter { $0.lastPathComponent.hasPrefix(Self.autoPrefix) || $0.lastPathComponent.hasPrefix(Self.manualPrefix) }
            .map { url in
                let (size, _) = Self.scan(url)
                // The time is in the folder name: a copied folder can keep the creation date of the original.
                let date = Self.parseStamp(url.lastPathComponent) ?? (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return SingleplayerBackup(url: url, date: date, bytes: size, isAutomatic: url.lastPathComponent.hasPrefix(Self.autoPrefix))
            }
            .sorted { $0.date > $1.date }
    }

    @discardableResult
    public func backUp(_ world: String, automatic: Bool = false, at date: Date = Date()) throws -> URL {
        let source = try worldURL(world)
        let folder = backupsRoot.appendingPathComponent(world, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent((automatic ? Self.autoPrefix : Self.manualPrefix) + Self.stamp(date), isDirectory: true)
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }

    /// Automatic pass after playing: copies every world changed since its newest backup, then keeps the newest `keep` automatic copies per world.
    @discardableResult
    public func backUpChangedWorlds(keep: Int, at date: Date = Date()) -> [String] {
        var done: [String] = []
        for world in worlds() {
            let newest = backups(of: world.folderName).first?.date ?? .distantPast
            guard world.lastChanged > newest else { continue }
            if (try? backUp(world.folderName, automatic: true, at: date)) != nil {
                done.append(world.folderName)
                prune(world.folderName, keep: keep)
            }
        }
        return done
    }

    /// Keeps the newest `keep` automatic copies; hand-made and `before-restore-*` copies are never touched.
    public func prune(_ world: String, keep: Int) {
        let automatic = backups(of: world).filter(\.isAutomatic)
        for old in automatic.dropFirst(max(keep, 0)) {
            try? FileManager.default.removeItem(at: old.url)
        }
    }

    /// Puts a copy back as the world. The current world is moved to `world-backups/<world>/before-restore-<time>`, never deleted.
    public func restore(_ backup: SingleplayerBackup, as world: String, at date: Date = Date()) throws {
        let fm = FileManager.default
        let current = savesDirectory.appendingPathComponent(world, isDirectory: true)
        if fm.fileExists(atPath: current.path) {
            let folder = backupsRoot.appendingPathComponent(world, isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try fm.moveItem(at: current, to: folder.appendingPathComponent(Self.parkedPrefix + Self.stamp(date), isDirectory: true))
        }
        try fm.copyItem(at: backup.url, to: current)
    }

    private func worldURL(_ name: String) throws -> URL {
        // A world name is one folder name; anything with a path in it is refused.
        guard !name.isEmpty, name == (name as NSString).lastPathComponent, name != "..", name != "." else { throw CocoaError(.fileReadInvalidFileName) }
        let url = savesDirectory.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        return url
    }

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }

    private static func stamp(_ date: Date) -> String {
        formatter().string(from: date)
    }

    private static func parseStamp(_ folderName: String) -> Date? {
        guard let dash = folderName.firstIndex(of: "-") else { return nil }
        return formatter().date(from: String(folderName[folderName.index(after: dash)...]))
    }

    private static func scan(_ url: URL) -> (bytes: Int64, newest: Date) {
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else { return (0, .distantPast) }
        var total: Int64 = 0
        var newest = Date.distantPast
        for case let file as URL in enumerator {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            if values?.isDirectory == true { continue }
            total += Int64(values?.fileSize ?? 0)
            if let modified = values?.contentModificationDate, modified > newest { newest = modified }
        }
        return (total, newest)
    }
}
