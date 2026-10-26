import Foundation

// MARK: - Version Manifest V2

public struct VersionManifest: Codable, Sendable {
    public let latest: LatestVersions
    public let versions: [ManifestVersion]

    public init(latest: LatestVersions, versions: [ManifestVersion]) {
        self.latest = latest
        self.versions = versions
    }
}

public struct LatestVersions: Codable, Sendable {
    public let release: String
    public let snapshot: String

    public init(release: String, snapshot: String) {
        self.release = release
        self.snapshot = snapshot
    }
}

public struct ManifestVersion: Codable, Sendable {
    public let id: String
    public let type: String
    public let url: URL
    public let sha1: String
    public let releaseTime: String?

    public init(id: String, type: String, url: URL, sha1: String, releaseTime: String? = nil) {
        self.id = id
        self.type = type
        self.url = url
        self.sha1 = sha1
        self.releaseTime = releaseTime
    }
}

// MARK: - Version Package Details

public struct VersionJSON: Codable, Sendable {
    public let id: String
    public let inheritsFrom: String?
    public let type: String?
    public let mainClass: String?
    public let minecraftArguments: String?
    public let arguments: VersionArguments?
    public let assetIndex: AssetIndexReference?
    public let assets: String?
    public let downloads: VersionDownloads?
    public let libraries: [Library]?
    public let javaVersion: JavaVersionReference?
    public let releaseTime: String?
    public let time: String?

    public init(
        id: String,
        inheritsFrom: String? = nil,
        type: String? = nil,
        mainClass: String? = nil,
        minecraftArguments: String? = nil,
        arguments: VersionArguments? = nil,
        assetIndex: AssetIndexReference? = nil,
        assets: String? = nil,
        downloads: VersionDownloads? = nil,
        libraries: [Library]? = nil,
        javaVersion: JavaVersionReference? = nil,
        releaseTime: String? = nil,
        time: String? = nil
    ) {
        self.id = id
        self.inheritsFrom = inheritsFrom
        self.type = type
        self.mainClass = mainClass
        self.minecraftArguments = minecraftArguments
        self.arguments = arguments
        self.assetIndex = assetIndex
        self.assets = assets
        self.downloads = downloads
        self.libraries = libraries
        self.javaVersion = javaVersion
        self.releaseTime = releaseTime
        self.time = time
    }
}

public struct VersionArguments: Codable, Sendable {
    public let game: [ArgumentEntry]?
    public let jvm: [ArgumentEntry]?

    public init(game: [ArgumentEntry]? = nil, jvm: [ArgumentEntry]? = nil) {
        self.game = game
        self.jvm = jvm
    }
}

public enum ArgumentValue: Codable, Sendable {
    case string(String)
    case strings([String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let strings = try? container.decode([String].self) {
            self = .strings(strings)
        } else {
            throw DecodingError.typeMismatch(
                ArgumentValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or [String]")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .strings(let strings):
            try container.encode(strings)
        }
    }

    public var asList: [String] {
        switch self {
        case .string(let s):
            return [s]
        case .strings(let arr):
            return arr
        }
    }
}

public enum ArgumentEntry: Codable, Sendable {
    case plain(String)
    case conditional(rules: [Rule]?, value: ArgumentValue)

    private enum CodingKeys: String, CodingKey {
        case rules
        case value
    }

    public init(from decoder: Decoder) throws {
        if let singleContainer = try? decoder.singleValueContainer(),
           let string = try? singleContainer.decode(String.self) {
            self = .plain(string)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rules = try container.decodeIfPresent([Rule].self, forKey: .rules)
        let value = try container.decode(ArgumentValue.self, forKey: .value)
        self = .conditional(rules: rules, value: value)
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .plain(let string):
            var container = encoder.singleValueContainer()
            try container.encode(string)
        case .conditional(let rules, let value):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(rules, forKey: .rules)
            try container.encode(value, forKey: .value)
        }
    }
}

public struct AssetIndexReference: Codable, Sendable {
    public let id: String
    public let sha1: String
    public let size: Int
    public let url: URL
    public let totalSize: Int?

    public init(id: String, sha1: String, size: Int, url: URL, totalSize: Int? = nil) {
        self.id = id
        self.sha1 = sha1
        self.size = size
        self.url = url
        self.totalSize = totalSize
    }
}

public struct AssetIndexData: Decodable, Sendable {
    public struct AssetObject: Decodable, Sendable {
        public let hash: String
        public let size: Int

        public init(hash: String, size: Int) {
            self.hash = hash
            self.size = size
        }
    }

    public let objects: [String: AssetObject]
    public let virtual: Bool?
    public let mapToResources: Bool?

    private enum CodingKeys: String, CodingKey {
        case objects
        case virtual
        case mapToResources = "map_to_resources"
    }

    public init(objects: [String: AssetObject], virtual: Bool? = nil, mapToResources: Bool? = nil) {
        self.objects = objects
        self.virtual = virtual
        self.mapToResources = mapToResources
    }
}

public struct VersionDownloads: Codable, Sendable {
    public let client: DownloadArtifact?

    public init(client: DownloadArtifact? = nil) {
        self.client = client
    }
}

public struct DownloadArtifact: Codable, Sendable {
    public let path: String?
    public let sha1: String
    public let size: Int
    public let url: URL

    public init(path: String? = nil, sha1: String, size: Int, url: URL) {
        self.path = path
        self.sha1 = sha1
        self.size = size
        self.url = url
    }
}

public struct LibraryDownloads: Codable, Sendable {
    public let artifact: DownloadArtifact?
    public let classifiers: [String: DownloadArtifact]?

    public init(artifact: DownloadArtifact? = nil, classifiers: [String: DownloadArtifact]? = nil) {
        self.artifact = artifact
        self.classifiers = classifiers
    }
}

public struct LibraryExtract: Codable, Sendable {
    public let exclude: [String]?

    public init(exclude: [String]? = nil) {
        self.exclude = exclude
    }
}

public struct JavaVersionReference: Codable, Sendable {
    public let component: String
    public let majorVersion: Int

    public init(component: String, majorVersion: Int) {
        self.component = component
        self.majorVersion = majorVersion
    }
}

public struct Library: Codable, Sendable {
    public let name: String
    public let downloads: LibraryDownloads?
    public let natives: [String: String]?
    public let rules: [Rule]?
    public let url: String?
    public let extract: LibraryExtract?

    public init(
        name: String,
        downloads: LibraryDownloads? = nil,
        natives: [String: String]? = nil,
        rules: [Rule]? = nil,
        url: String? = nil,
        extract: LibraryExtract? = nil
    ) {
        self.name = name
        self.downloads = downloads
        self.natives = natives
        self.rules = rules
        self.url = url
        self.extract = extract
    }

    public var nativeClassifier: String? {
        guard let osx = natives?["osx"] else { return nil }
        return osx.replacingOccurrences(of: "${arch}", with: "64")
    }

    public var resolvedArtifact: (path: String, url: URL, sha1: String?, size: Int?)? {
        if natives != nil {
            guard let classifier = nativeClassifier else {
                return nil
            }
            if let classifierArtifact = downloads?.classifiers?[classifier] {
                let relativePath: String
                if let customPath = classifierArtifact.path {
                    relativePath = customPath
                } else if let mavenPath = Self.pathFromMavenCoordinates("\(name):\(classifier)") {
                    relativePath = mavenPath
                } else {
                    relativePath = classifierArtifact.url.lastPathComponent
                }
                return (path: relativePath, url: classifierArtifact.url, sha1: classifierArtifact.sha1, size: classifierArtifact.size)
            }
            let coordsWithClassifier = "\(name):\(classifier)"
            guard let path = Self.pathFromMavenCoordinates(coordsWithClassifier) else {
                return nil
            }
            var base = url ?? "https://libraries.minecraft.net/"
            if !base.hasSuffix("/") {
                base.append("/")
            }
            guard let artifactURL = URL(string: base + path) else {
                return nil
            }
            return (path: path, url: artifactURL, sha1: nil, size: nil)
        }

        if let artifact = downloads?.artifact {
            let relativePath: String
            if let customPath = artifact.path {
                relativePath = customPath
            } else if let mavenPath = Self.pathFromMavenCoordinates(name) {
                relativePath = mavenPath
            } else {
                relativePath = artifact.url.lastPathComponent
            }
            return (path: relativePath, url: artifact.url, sha1: artifact.sha1, size: artifact.size)
        }

        guard let path = Self.pathFromMavenCoordinates(name) else {
            return nil
        }

        var base = url ?? "https://libraries.minecraft.net/"
        if !base.hasSuffix("/") {
            base.append("/")
        }

        guard let artifactURL = URL(string: base + path) else {
            return nil
        }

        return (path: path, url: artifactURL, sha1: nil, size: nil)
    }

    private static func pathFromMavenCoordinates(_ coords: String) -> String? {
        var baseCoords = coords
        var ext = "jar"

        if let atIndex = baseCoords.firstIndex(of: "@") {
            ext = String(baseCoords[baseCoords.index(after: atIndex)...])
            baseCoords = String(baseCoords[..<atIndex])
        }

        let parts = baseCoords.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3 else {
            return nil
        }

        let group = parts[0].replacingOccurrences(of: ".", with: "/")
        let artifact = parts[1]
        let version = parts[2]
        let classifier = parts.count > 3 ? parts[3] : nil

        let filename: String
        if let classifier = classifier, !classifier.isEmpty {
            filename = "\(artifact)-\(version)-\(classifier).\(ext)"
        } else {
            filename = "\(artifact)-\(version).\(ext)"
        }

        return "\(group)/\(artifact)/\(version)/\(filename)"
    }
}
