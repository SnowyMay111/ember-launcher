import Foundation

public struct Instance: Codable, Sendable, Equatable {
    public var name: String
    public var minecraftVersion: String
    public var loader: String
    public var loaderVersion: String?
    public var versionId: String
    public var memoryMB: Int
    public var extraJVMArgs: [String]
    public var group: String?
    public var lastPlayed: Date?
    public var playtimeSeconds: Int

    public init(
        name: String,
        minecraftVersion: String,
        loader: String = "vanilla",
        loaderVersion: String? = nil,
        versionId: String,
        memoryMB: Int = 4096,
        extraJVMArgs: [String] = [],
        group: String? = nil,
        lastPlayed: Date? = nil,
        playtimeSeconds: Int = 0
    ) {
        self.name = name
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.loaderVersion = loaderVersion
        self.versionId = versionId
        self.memoryMB = memoryMB
        self.extraJVMArgs = extraJVMArgs
        self.group = group
        self.lastPlayed = lastPlayed
        self.playtimeSeconds = playtimeSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case minecraftVersion
        case loader
        case loaderVersion
        case versionId
        case memoryMB
        case extraJVMArgs
        case group
        case lastPlayed
        case playtimeSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        minecraftVersion = try container.decode(String.self, forKey: .minecraftVersion)
        loader = try container.decodeIfPresent(String.self, forKey: .loader) ?? "vanilla"
        loaderVersion = try container.decodeIfPresent(String.self, forKey: .loaderVersion)
        versionId = try container.decode(String.self, forKey: .versionId)
        memoryMB = try container.decodeIfPresent(Int.self, forKey: .memoryMB) ?? 4096
        extraJVMArgs = try container.decodeIfPresent([String].self, forKey: .extraJVMArgs) ?? []
        group = try container.decodeIfPresent(String.self, forKey: .group)
        lastPlayed = try container.decodeIfPresent(Date.self, forKey: .lastPlayed)
        playtimeSeconds = try container.decodeIfPresent(Int.self, forKey: .playtimeSeconds) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(minecraftVersion, forKey: .minecraftVersion)
        try container.encode(loader, forKey: .loader)
        try container.encodeIfPresent(loaderVersion, forKey: .loaderVersion)
        try container.encode(versionId, forKey: .versionId)
        try container.encode(memoryMB, forKey: .memoryMB)
        try container.encode(extraJVMArgs, forKey: .extraJVMArgs)
        try container.encodeIfPresent(group, forKey: .group)
        try container.encodeIfPresent(lastPlayed, forKey: .lastPlayed)
        try container.encode(playtimeSeconds, forKey: .playtimeSeconds)
    }
}

public enum InstanceStoreError: Error, LocalizedError, Sendable {
    case instanceNotFound(String)
    case invalidName
    case nameTaken(String)
    case trashUnsupported

    public var errorDescription: String? {
        switch self {
        case .instanceNotFound(let name):
            return "Instance '\(name)' not found"
        case .invalidName:
            return "Instance name is invalid"
        case .nameTaken(let name):
            return "An instance named '\(name)' already exists"
        case .trashUnsupported:
            return "Moving to trash is not supported on this platform"
        }
    }
}

public final class InstanceStore: Sendable {
    public let paths: LauncherPaths

    public init(paths: LauncherPaths) {
        self.paths = paths
    }

    public func instanceDirectory(for name: String) -> URL {
        paths.instances.appendingPathComponent(name, isDirectory: true)
    }

    public func gameDirectory(for name: String) -> URL {
        instanceDirectory(for: name).appendingPathComponent("minecraft", isDirectory: true)
    }

    public func instanceJSON(for name: String) -> URL {
        instanceDirectory(for: name).appendingPathComponent("instance.json")
    }

    @discardableResult
    public func create(
        name: String,
        minecraftVersion: String,
        loader: String = "vanilla",
        loaderVersion: String? = nil,
        versionId: String? = nil,
        memoryMB: Int = 4096,
        extraJVMArgs: [String] = [],
        group: String? = nil
    ) throws -> Instance {
        let vid = versionId ?? minecraftVersion
        let instance = Instance(
            name: name,
            minecraftVersion: minecraftVersion,
            loader: loader,
            loaderVersion: loaderVersion,
            versionId: vid,
            memoryMB: memoryMB,
            extraJVMArgs: extraJVMArgs,
            group: group
        )
        try create(instance)
        return instance
    }

    public func create(_ instance: Instance) throws {
        let instDir = instanceDirectory(for: instance.name)
        let gameDir = gameDirectory(for: instance.name)
        let fm = FileManager.default
        try fm.createDirectory(at: instDir, withIntermediateDirectories: true, attributes: nil)
        try fm.createDirectory(at: gameDir, withIntermediateDirectories: true, attributes: nil)
        try save(instance)
    }

    public func save(_ instance: Instance) throws {
        let instDir = instanceDirectory(for: instance.name)
        let gameDir = gameDirectory(for: instance.name)
        let fm = FileManager.default
        try fm.createDirectory(at: instDir, withIntermediateDirectories: true, attributes: nil)
        try fm.createDirectory(at: gameDir, withIntermediateDirectories: true, attributes: nil)

        let jsonURL = instanceJSON(for: instance.name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(instance)
        try data.write(to: jsonURL, options: .atomic)
    }

    public func load(name: String) throws -> Instance {
        let jsonURL = instanceJSON(for: name)
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw InstanceStoreError.instanceNotFound(name)
        }
        let data = try Data(contentsOf: jsonURL)
        return try JSONDecoder().decode(Instance.self, from: data)
    }

    public func list() throws -> [Instance] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: paths.instances.path) else {
            return []
        }
        let entries = try fm.contentsOfDirectory(
            at: paths.instances,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var instances: [Instance] = []
        for entry in entries {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue {
                let jsonURL = entry.appendingPathComponent("instance.json")
                if fm.fileExists(atPath: jsonURL.path) {
                    if let data = try? Data(contentsOf: jsonURL),
                       let instance = try? JSONDecoder().decode(Instance.self, from: data) {
                        instances.append(instance)
                    }
                }
            }
        }
        return instances.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
