import Foundation

public struct ServerProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String { instanceName }

    public var instanceName: String
    public var name: String
    public var minecraftVersion: String
    public var loader: String
    public var maxPlayers: Int
    public var lastPlayed: Date?

    public init(
        instanceName: String,
        name: String,
        minecraftVersion: String,
        loader: String,
        maxPlayers: Int,
        lastPlayed: Date? = nil
    ) {
        self.instanceName = instanceName
        self.name = name
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.maxPlayers = maxPlayers
        self.lastPlayed = lastPlayed
    }
}

public struct ServerLibrary: Sendable {
    private let root: URL
    private static let profileFileName = "ember-server.json"
    private static let worldFolderName = "world"

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
