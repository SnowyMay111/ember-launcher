import Foundation

public enum ModrinthError: Error, LocalizedError, Sendable, Equatable {
    case badURL
    case noCompatibleVersion(project: String, gameVersion: String, loader: String)

    public var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid URL"
        case .noCompatibleVersion(let project, let gameVersion, let loader):
            return "No compatible version found for project '\(project)' with game version '\(gameVersion)' and loader '\(loader)'"
        }
    }
}

public struct ModrinthHit: Codable, Sendable, Equatable {
    public let projectId: String
    public let slug: String
    public let title: String
    public let description: String
    public let author: String
    public let iconURL: URL?
    public let downloads: Int
    public let categories: [String]

    public init(
        projectId: String,
        slug: String,
        title: String,
        description: String,
        author: String,
        iconURL: URL? = nil,
        downloads: Int,
        categories: [String] = []
    ) {
        self.projectId = projectId
        self.slug = slug
        self.title = title
        self.description = description
        self.author = author
        self.iconURL = iconURL
        self.downloads = downloads
        self.categories = categories
    }

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case slug
        case title
        case description
        case author
        case iconURL = "icon_url"
        case downloads
        case categories
    }
}

public struct ModrinthSearchResult: Codable, Sendable, Equatable {
    public let hits: [ModrinthHit]
    public let totalHits: Int

    public init(hits: [ModrinthHit], totalHits: Int) {
        self.hits = hits
        self.totalHits = totalHits
    }

    enum CodingKeys: String, CodingKey {
        case hits
        case totalHits = "total_hits"
    }
}

public typealias ModrinthSearchResponse = ModrinthSearchResult

public struct ModrinthFile: Codable, Sendable, Equatable {
    public let url: URL
    public let filename: String
    public let size: Int
    public let sha1: String?
    public let primary: Bool

    public init(
        url: URL,
        filename: String,
        size: Int,
        sha1: String? = nil,
        primary: Bool = false
    ) {
        self.url = url
        self.filename = filename
        self.size = size
        self.sha1 = sha1
        self.primary = primary
    }

    enum CodingKeys: String, CodingKey {
        case url
        case filename
        case size
        case hashes
        case primary
    }

    enum HashesCodingKeys: String, CodingKey {
        case sha1
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decode(URL.self, forKey: .url)
        self.filename = try container.decode(String.self, forKey: .filename)
        self.size = try container.decode(Int.self, forKey: .size)
        self.primary = try container.decodeIfPresent(Bool.self, forKey: .primary) ?? false

        if let hashesContainer = try? container.nestedContainer(keyedBy: HashesCodingKeys.self, forKey: .hashes) {
            self.sha1 = try hashesContainer.decodeIfPresent(String.self, forKey: .sha1)
        } else {
            self.sha1 = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(filename, forKey: .filename)
        try container.encode(size, forKey: .size)
        try container.encode(primary, forKey: .primary)

        if let sha1 = sha1 {
            var hashesContainer = container.nestedContainer(keyedBy: HashesCodingKeys.self, forKey: .hashes)
            try hashesContainer.encode(sha1, forKey: .sha1)
        }
    }
}

public struct ModrinthDependency: Codable, Sendable, Equatable {
    public enum DependencyType: String, Codable, Sendable, Equatable {
        case required
        case optional
        case incompatible
        case embedded
        case unknown

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = DependencyType(rawValue: rawValue) ?? .unknown
        }
    }

    public let projectId: String?
    public let versionId: String?
    public let type: DependencyType

    public init(projectId: String? = nil, versionId: String? = nil, type: DependencyType) {
        self.projectId = projectId
        self.versionId = versionId
        self.type = type
    }

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case versionId = "version_id"
        case type = "dependency_type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.projectId = try container.decodeIfPresent(String.self, forKey: .projectId)
        self.versionId = try container.decodeIfPresent(String.self, forKey: .versionId)
        self.type = try container.decodeIfPresent(DependencyType.self, forKey: .type) ?? .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(projectId, forKey: .projectId)
        try container.encodeIfPresent(versionId, forKey: .versionId)
        try container.encode(type, forKey: .type)
    }
}

public typealias ModrinthDependencyType = ModrinthDependency.DependencyType

public struct ModrinthVersion: Codable, Sendable, Equatable {
    public let id: String
    public let projectId: String
    public let name: String
    public let versionNumber: String
    public let versionType: String
    public let datePublished: String
    public let gameVersions: [String]
    public let loaders: [String]
    public let files: [ModrinthFile]
    public let dependencies: [ModrinthDependency]

    public var primaryFile: ModrinthFile? {
        files.first(where: { $0.primary }) ?? files.first
    }

    public init(
        id: String,
        projectId: String,
        name: String,
        versionNumber: String,
        versionType: String,
        datePublished: String,
        gameVersions: [String],
        loaders: [String],
        files: [ModrinthFile],
        dependencies: [ModrinthDependency] = []
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.versionNumber = versionNumber
        self.versionType = versionType
        self.datePublished = datePublished
        self.gameVersions = gameVersions
        self.loaders = loaders
        self.files = files
        self.dependencies = dependencies
    }

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case name
        case versionNumber = "version_number"
        case versionType = "version_type"
        case datePublished = "date_published"
        case gameVersions = "game_versions"
        case loaders
        case files
        case dependencies
    }
}

public struct ModrinthProject: Codable, Sendable, Equatable {
    public let id: String
    public let slug: String
    public let title: String
    public let description: String
    public let iconURL: URL?
    public let projectType: String

    public init(
        id: String,
        slug: String,
        title: String,
        description: String,
        iconURL: URL? = nil,
        projectType: String
    ) {
        self.id = id
        self.slug = slug
        self.title = title
        self.description = description
        self.iconURL = iconURL
        self.projectType = projectType
    }

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case title
        case description
        case iconURL = "icon_url"
        case projectType = "project_type"
    }
}

public final class ModrinthClient: Sendable {
    public let downloader: Downloader

    public init(downloader: Downloader = Downloader()) {
        self.downloader = downloader
    }

    public func search(
        query: String,
        gameVersion: String? = nil,
        loader: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ModrinthHit] {
        var components = URLComponents(string: "https://api.modrinth.com/v2/search")
        var facets: [[String]] = [["project_type:mod"]]
        if let gameVersion = gameVersion, !gameVersion.isEmpty {
            facets.append(["versions:\(gameVersion)"])
        }
        if let loader = loader, !loader.isEmpty {
            facets.append(["categories:\(loader)"])
        }
        let facetsData = try JSONSerialization.data(withJSONObject: facets)
        let facetsString = String(data: facetsData, encoding: .utf8) ?? "[]"

        let index = query.isEmpty ? "downloads" : "relevance"
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "index", value: index),
            URLQueryItem(name: "facets", value: facetsString)
        ]

        guard let url = components?.url else {
            throw ModrinthError.badURL
        }

        let response = try await downloader.fetchJSON(ModrinthSearchResult.self, from: url)
        return response.hits
    }

    public func project(idOrSlug: String) async throws -> ModrinthProject {
        let escaped = idOrSlug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idOrSlug
        guard let url = URLComponents(string: "https://api.modrinth.com/v2/project/\(escaped)")?.url else {
            throw ModrinthError.badURL
        }
        return try await downloader.fetchJSON(ModrinthProject.self, from: url)
    }

    public func projects(ids: [String]) async throws -> [ModrinthProject] {
        guard !ids.isEmpty else {
            return []
        }
        let data = try JSONSerialization.data(withJSONObject: ids)
        let idsString = String(data: data, encoding: .utf8) ?? "[]"

        var components = URLComponents(string: "https://api.modrinth.com/v2/projects")
        components?.queryItems = [
            URLQueryItem(name: "ids", value: idsString)
        ]

        guard let url = components?.url else {
            throw ModrinthError.badURL
        }

        return try await downloader.fetchJSON([ModrinthProject].self, from: url)
    }

    public func versions(
        project idOrSlug: String,
        gameVersion: String? = nil,
        loader: String? = nil
    ) async throws -> [ModrinthVersion] {
        let escaped = idOrSlug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idOrSlug
        var components = URLComponents(string: "https://api.modrinth.com/v2/project/\(escaped)/version")
        var queryItems: [URLQueryItem] = []

        if let gameVersion = gameVersion, !gameVersion.isEmpty {
            let data = try JSONSerialization.data(withJSONObject: [gameVersion])
            if let jsonString = String(data: data, encoding: .utf8) {
                queryItems.append(URLQueryItem(name: "game_versions", value: jsonString))
            }
        }

        if let loader = loader, !loader.isEmpty {
            let data = try JSONSerialization.data(withJSONObject: [loader])
            if let jsonString = String(data: data, encoding: .utf8) {
                queryItems.append(URLQueryItem(name: "loaders", value: jsonString))
            }
        }

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw ModrinthError.badURL
        }

        let versions = try await downloader.fetchJSON([ModrinthVersion].self, from: url)
        return versions.sorted { $0.datePublished > $1.datePublished }
    }

    public func bestVersion(
        project idOrSlug: String,
        gameVersion: String,
        loader: String
    ) async throws -> ModrinthVersion? {
        let list = try await versions(project: idOrSlug, gameVersion: gameVersion, loader: loader)
        if list.isEmpty {
            return nil
        }
        if let release = list.first(where: { $0.versionType.lowercased() == "release" }) {
            return release
        }
        if let beta = list.first(where: { $0.versionType.lowercased() == "beta" }) {
            return beta
        }
        if let alpha = list.first(where: { $0.versionType.lowercased() == "alpha" }) {
            return alpha
        }
        return list.first
    }

    public func version(id: String) async throws -> ModrinthVersion {
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URLComponents(string: "https://api.modrinth.com/v2/version/\(escaped)")?.url else {
            throw ModrinthError.badURL
        }
        return try await downloader.fetchJSON(ModrinthVersion.self, from: url)
    }
}
