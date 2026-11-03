import Foundation

/// A friend who may join a hosted server: invited automatically on every start.
public struct TrustedPlayer: Codable, Equatable, Identifiable, Sendable {
    public var id: String { userID }

    public var userID: String
    public var tag: String
    public var name: String

    public init(userID: String, tag: String, name: String) {
        self.userID = userID
        self.tag = tag
        self.name = name
    }
}

public struct ServerProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String { instanceName }

    public var instanceName: String
    public var name: String
    public var minecraftVersion: String
    public var loader: String
    public var maxPlayers: Int
    public var lastPlayed: Date?
    public var trusted: [TrustedPlayer]
    /// Copy the world into `backups/` every time the server stops.
    public var autoBackup: Bool

    public init(
        instanceName: String,
        name: String,
        minecraftVersion: String,
        loader: String,
        maxPlayers: Int,
        lastPlayed: Date? = nil,
        trusted: [TrustedPlayer] = [],
        autoBackup: Bool = false
    ) {
        self.instanceName = instanceName
        self.name = name
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.maxPlayers = maxPlayers
        self.lastPlayed = lastPlayed
        self.trusted = trusted
        self.autoBackup = autoBackup
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceName = try container.decode(String.self, forKey: .instanceName)
        name = try container.decode(String.self, forKey: .name)
        minecraftVersion = try container.decode(String.self, forKey: .minecraftVersion)
        loader = try container.decode(String.self, forKey: .loader)
        maxPlayers = try container.decode(Int.self, forKey: .maxPlayers)
        lastPlayed = try container.decodeIfPresent(Date.self, forKey: .lastPlayed)
        trusted = try container.decodeIfPresent([TrustedPlayer].self, forKey: .trusted) ?? []
        autoBackup = try container.decodeIfPresent(Bool.self, forKey: .autoBackup) ?? false
    }
}

public struct WorldBackup: Equatable, Identifiable, Sendable {
    public var id: String { url.lastPathComponent }
    public let url: URL
    public let date: Date
    public let bytes: Int64
}

public struct ServerLibrary: Sendable {
    private let root: URL
    private static let profileFileName = "ember-server.json"
    private static let worldFolderName = "world"
    private static let autoBackupPrefix = "world-auto-"

    public init(root: URL) {
        self.root = root
    }

    public func directory(for instanceName: String) -> URL {
        root.appendingPathComponent(instanceName, isDirectory: true)
    }

    public func list() -> [ServerProfile] {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var profiles: [ServerProfile] = []
        for entry in entries {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: entry.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let profileURL = entry.appendingPathComponent(Self.profileFileName)
            guard let data = try? Data(contentsOf: profileURL) else {
                continue
            }
            guard let profile = try? decoder.decode(ServerProfile.self, from: data) else {
                continue
            }
            profiles.append(profile)
        }

        return profiles.sorted { lhs, rhs in
            switch (lhs.lastPlayed, rhs.lastPlayed) {
            case let (lhsDate?, rhsDate?):
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.name < rhs.name
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.name < rhs.name
            }
        }
    }

    public func profile(for instanceName: String) -> ServerProfile? {
        let url = directory(for: instanceName).appendingPathComponent(Self.profileFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ServerProfile.self, from: data)
    }

    public func save(_ profile: ServerProfile) throws {
        let directory = directory(for: profile.instanceName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]

        let data = try encoder.encode(profile)
        let profileURL = directory.appendingPathComponent(Self.profileFileName)
        try data.write(to: profileURL, options: .atomic)
    }

    public func markPlayed(_ instanceName: String, at date: Date = Date()) throws {
        let profileURL = directory(for: instanceName).appendingPathComponent(Self.profileFileName)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: profileURL)
        var profile = try decoder.decode(ServerProfile.self, from: data)
        profile.lastPlayed = date
        try save(profile)
    }

    /// Changes the name shown in Ember; the folder and the instance link stay as they are.
    public func rename(_ instanceName: String, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var profile = profile(for: instanceName) else { throw CocoaError(.fileNoSuchFile) }
        profile.name = trimmed
        try save(profile)
    }

    public func setAutoBackup(_ instanceName: String, _ isOn: Bool) throws {
        guard var profile = profile(for: instanceName) else { throw CocoaError(.fileNoSuchFile) }
        profile.autoBackup = isOn
        try save(profile)
    }

    /// Takes the server's folder (world, backups, settings) out of the list. It goes to the Trash by default, so it can be put back.
    public func remove(
        _ instanceName: String,
        trash: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) throws {
        try trash(directory(for: instanceName))
    }

    /// Keeps the newest `keep` automatic backups; hand-made ones and `before-restore-*` are never touched.
    public func pruneAutomaticBackups(for instanceName: String, keep: Int) {
        let automatic = listBackups(for: instanceName).filter { $0.url.lastPathComponent.hasPrefix(Self.autoBackupPrefix) }
        for old in automatic.dropFirst(max(keep, 0)) {
            try? FileManager.default.removeItem(at: old.url)
        }
    }

    private func backupsDirectory(for instanceName: String) -> URL {
        directory(for: instanceName).appendingPathComponent("backups", isDirectory: true)
    }

    private func worldDirectory(for instanceName: String) -> URL {
        directory(for: instanceName).appendingPathComponent(Self.worldFolderName, isDirectory: true)
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }

    /// Copies the world into `backups/world-<time>`. The server should have flushed to disk (`save-all`) first.
    @discardableResult
    public func backupWorld(for instanceName: String, at date: Date = Date(), automatic: Bool = false) throws -> URL {
        let source = worldDirectory(for: instanceName)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let backups = backupsDirectory(for: instanceName)
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
        let target = backups.appendingPathComponent((automatic ? Self.autoBackupPrefix : "world-") + Self.stamp(date), isDirectory: true)
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }

    public func listBackups(for instanceName: String) -> [WorldBackup] {
        let fileManager = FileManager.default
        let entries = (try? fileManager.contentsOfDirectory(
            at: backupsDirectory(for: instanceName),
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return entries
            .filter { $0.lastPathComponent.hasPrefix("world-") }
            .map { url in
                let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return WorldBackup(url: url, date: date, bytes: Self.folderSize(url))
            }
            .sorted { $0.date > $1.date }
    }

    /// Puts a backup back as the world. The current world is moved to `backups/before-restore-<time>`, never deleted.
    public func restoreBackup(_ backup: WorldBackup, for instanceName: String, at date: Date = Date()) throws {
        let fileManager = FileManager.default
        let world = worldDirectory(for: instanceName)
        if fileManager.fileExists(atPath: world.path) {
            let parked = backupsDirectory(for: instanceName).appendingPathComponent("before-restore-\(Self.stamp(date))", isDirectory: true)
            try fileManager.createDirectory(at: parked.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: world, to: parked)
        }
        try fileManager.copyItem(at: backup.url, to: world)
    }

    private static func folderSize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    public func worldFolderSize(for instanceName: String) -> Int64 {
        let worldDirectory = directory(for: instanceName).appendingPathComponent(Self.worldFolderName, isDirectory: true)
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: worldDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return 0
        }

        guard let enumerator = fileManager.enumerator(
            at: worldDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for item in enumerator {
            guard let fileURL = item as? URL else { continue }
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if values?.isDirectory == true { continue }
            if let fileSize = values?.fileSize {
                total += Int64(fileSize)
            }
        }

        return total
    }
}
