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
    /// Followers on Modrinth; nil when the response (or an older cache) lacks it.
    public let follows: Int?

    public init(
        projectId: String,
        slug: String,
        title: String,
        description: String,
        author: String,
        iconURL: URL? = nil,
        downloads: Int,
        categories: [String] = [],
        follows: Int? = nil
    ) {
        self.projectId = projectId
        self.slug = slug
        self.title = title
        self.description = description
        self.author = author
        self.iconURL = iconURL
        self.downloads = downloads
        self.categories = categories
        self.follows = follows
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
        case follows
    }
}

public struct ModrinthSearchResult: Codable, Sendable, Equatable {
    public let hits: [ModrinthHit]
    public let totalHits: Int
    /// What to pass as `offset` for the next page; nil means the number of hits loaded so far. Not coded.
    public var nextOffset: Int? = nil
    /// False when nothing is left to load; nil means "loaded < totalHits". Not coded.
    public var hasMore: Bool? = nil

    public init(hits: [ModrinthHit], totalHits: Int, nextOffset: Int? = nil, hasMore: Bool? = nil) {
        self.hits = hits
        self.totalHits = totalHits
        self.nextOffset = nextOffset
        self.hasMore = hasMore
    }

    enum CodingKeys: String, CodingKey {
        case hits
        case totalHits = "total_hits"
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hits == rhs.hits && lhs.totalHits == rhs.totalHits
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

    /// A file name from the API is joined to a local path, so it must be a single plain path component.
    public static func isSafeFilename(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && trimmed != "." && trimmed != ".."
            && !trimmed.contains("/") && !trimmed.contains("\\") && !trimmed.contains("\0")
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
        let filename = try container.decode(String.self, forKey: .filename)
        guard Self.isSafeFilename(filename) else {
            throw DecodingError.dataCorruptedError(forKey: .filename, in: container, debugDescription: "Unsafe file name: \(filename)")
        }
        self.filename = filename
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

/// Facade over Modrinth and CurseForge; "cf:" ids go to CurseForge, everything else to Modrinth.
public final class ModrinthClient: Sendable {
    public let downloader: Downloader
    public let curseForge: CurseForgeClient

    public init(downloader: Downloader = Downloader(), curseForge: CurseForgeClient? = nil) {
        self.downloader = downloader
        self.curseForge = curseForge ?? CurseForgeClient(anonKey: EmberBackend.anonKey, downloader: downloader)
    }

    public func searchPage(
        query: String,
        projectType: String = "mod",
        gameVersion: String? = nil,
        loader: String? = nil,
        loaders: [String] = [],
        categories: [String] = [],
        categoryGroups: [[String]] = [],
        sortBy: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> ModrinthSearchResult {
        // Modrinth category slugs have no CurseForge equivalent.
        let curseForgeApplies = categories.isEmpty && categoryGroups.isEmpty
            && CurseForgeClient.classId(projectType: projectType) != nil
        let empty = ModrinthSearchResult(hits: [], totalHits: 0)

        switch CatalogSource.current {
        case .modrinth:
            break
        case .curseforge:
            guard curseForgeApplies else { return empty }
            return try await curseForgeSearchPage(
                query: query, projectType: projectType, gameVersion: gameVersion, loader: loader ?? loaders.first,
                sortBy: sortBy, limit: limit, offset: offset
            )
        case .both where curseForgeApplies:
            // `offset` is a cursor from packCursor here, not a plain position.
            let quota = max(limit / 2, 1)
            let (mOff, cOff) = Self.unpackCursor(offset)
            async let modrinthTask = modrinthSearchPage(
                query: query, projectType: projectType, gameVersion: gameVersion, loader: loader, loaders: loaders,
                categories: categories, categoryGroups: categoryGroups, sortBy: sortBy, limit: quota, offset: mOff
            )
            async let curseTask = try? await curseForgeSearchPage(
                query: query, projectType: projectType, gameVersion: gameVersion, loader: loader ?? loaders.first,
                sortBy: sortBy, limit: quota, offset: cOff
            )
            var modrinth: ModrinthSearchResult?
            var modrinthError: (any Error)?
            do { modrinth = try await modrinthTask } catch { modrinthError = error }
            var curse = await curseTask
            if let modrinthError, curse == nil { throw modrinthError }

            // One side ran out: fill the page from the other so it stays about `limit` long.
            if let m = modrinth, let c = curse {
                let modrinthDone = m.hits.count < quota && mOff + m.hits.count >= m.totalHits
                let curseDone = c.hits.count < quota && cOff + c.hits.count >= c.totalHits
                if modrinthDone, c.hits.count >= quota, let extra = try? await curseForgeSearchPage(
                    query: query, projectType: projectType, gameVersion: gameVersion, loader: loader ?? loaders.first,
                    sortBy: sortBy, limit: quota - m.hits.count, offset: cOff + c.hits.count
                ) {
                    curse = ModrinthSearchResult(hits: c.hits + extra.hits, totalHits: c.totalHits)
                } else if curseDone, m.hits.count >= quota, let extra = try? await modrinthSearchPage(
                    query: query, projectType: projectType, gameVersion: gameVersion, loader: loader, loaders: loaders,
                    categories: categories, categoryGroups: categoryGroups, sortBy: sortBy,
                    limit: quota - c.hits.count, offset: mOff + m.hits.count
                ) {
                    modrinth = ModrinthSearchResult(hits: m.hits + extra.hits, totalHits: m.totalHits)
                }
            }
            return Self.assembleBothPage(
                modrinth: modrinth, curseforge: curse, limit: limit, modrinthOffset: mOff, curseforgeOffset: cOff,
                modrinthTotal: modrinth?.totalHits ?? 0, curseforgeTotal: curse?.totalHits ?? 0
            )
        case .both:
            break
        }

        return try await modrinthSearchPage(
            query: query, projectType: projectType, gameVersion: gameVersion, loader: loader, loaders: loaders,
            categories: categories, categoryGroups: categoryGroups, sortBy: sortBy, limit: limit, offset: offset
        )
    }

    /// Interleaves Modrinth and CurseForge hits, dropping CurseForge hits that look like the same mod (slug or title).
    static func mergeSearchResults(modrinth: ModrinthSearchResult, curseforge: ModrinthSearchResult) -> ModrinthSearchResult {
        let slugs = Set(modrinth.hits.map(\.slug))
        let titles = Set(modrinth.hits.map { $0.title.lowercased() })
        var hits: [ModrinthHit] = []
        for index in 0..<max(modrinth.hits.count, curseforge.hits.count) {
            if index < modrinth.hits.count {
                hits.append(modrinth.hits[index])
            }
            if index < curseforge.hits.count {
                let hit = curseforge.hits[index]
                if !slugs.contains(hit.slug), !titles.contains(hit.title.lowercased()) {
                    hits.append(hit)
                }
            }
        }
        return ModrinthSearchResult(hits: hits, totalHits: modrinth.totalHits + curseforge.totalHits)
    }

    static let cursorBase = 1_000_000

    /// Packs the per-side offsets of a merged search into one `offset`; both must stay below `cursorBase`.
    static func packCursor(modrinth: Int, curseforge: Int) -> Int {
        min(max(modrinth, 0), cursorBase - 1) * cursorBase + min(max(curseforge, 0), cursorBase - 1)
    }

    static func unpackCursor(_ cursor: Int) -> (modrinth: Int, curseforge: Int) {
        let value = max(cursor, 0)
        return (value / cursorBase, value % cursorBase)
    }

    /// Final page of a merged search. A nil side failed: it keeps its offset and does not count towards `hasMore`.
    /// Offsets advance by the raw hit counts, before duplicates are dropped.
    static func assembleBothPage(
        modrinth: ModrinthSearchResult?,
        curseforge: ModrinthSearchResult?,
        limit: Int,
        modrinthOffset: Int,
        curseforgeOffset: Int,
        modrinthTotal: Int,
        curseforgeTotal: Int
    ) -> ModrinthSearchResult {
        let empty = ModrinthSearchResult(hits: [], totalHits: 0)
        let merged = mergeSearchResults(modrinth: modrinth ?? empty, curseforge: curseforge ?? empty)
        let modrinthNext = modrinthOffset + (modrinth?.hits.count ?? 0)
        let curseNext = curseforgeOffset + (curseforge?.hits.count ?? 0)
        // An empty side is finished even if its total claims more, so a page can never repeat forever.
        let modrinthMore = modrinth.map { !$0.hits.isEmpty && modrinthNext < modrinthTotal } ?? false
        let curseMore = curseforge.map { !$0.hits.isEmpty && curseNext < curseforgeTotal } ?? false
        return ModrinthSearchResult(
            hits: merged.hits,
            totalHits: (modrinth == nil ? 0 : modrinthTotal) + (curseforge == nil ? 0 : curseforgeTotal),
            nextOffset: packCursor(modrinth: modrinthNext, curseforge: curseNext),
            hasMore: modrinthMore || curseMore
        )
    }

    /// Modrinth `index` to CurseForge `sortField`; nil follows Modrinth's default (relevance with a query, else downloads).
    static func curseForgeSortField(sortBy: String?, query: String) -> Int {
        switch sortBy ?? (query.isEmpty ? "downloads" : "relevance") {
        case "downloads": return 6
        case "follows": return 2
        case "newest": return 11
        case "updated": return 3
        default: return query.isEmpty ? 2 : 1
        }
    }

    private func curseForgeSearchPage(
        query: String,
        projectType: String,
        gameVersion: String?,
        loader: String?,
        sortBy: String?,
        limit: Int,
        offset: Int
    ) async throws -> ModrinthSearchResult {
        guard let classId = CurseForgeClient.classId(projectType: projectType) else {
            return ModrinthSearchResult(hits: [], totalHits: 0)
        }
        return try await curseForge.searchPage(
            query: query,
            classId: classId,
            gameVersion: gameVersion,
            loader: loader,
            sortField: Self.curseForgeSortField(sortBy: sortBy, query: query),
            limit: limit,
            offset: offset
        )
    }

    private func modrinthSearchPage(
        query: String,
        projectType: String,
        gameVersion: String?,
        loader: String?,
        loaders: [String],
        categories: [String],
        categoryGroups: [[String]],
        sortBy: String?,
        limit: Int,
        offset: Int
    ) async throws -> ModrinthSearchResult {
        var components = URLComponents(string: "https://api.modrinth.com/v2/search")
        var facets: [[String]] = []
        if !projectType.isEmpty {
            facets.append(["project_type:\(projectType)"])
        }
        if let gameVersion = gameVersion, !gameVersion.isEmpty {
            facets.append(["versions:\(gameVersion)"])
        }
        if let loader = loader, !loader.isEmpty {
            facets.append(["categories:\(loader)"])
        }
        if !loaders.isEmpty {
            facets.append(loaders.map { "categories:\($0)" })
        }
        for category in categories where !category.isEmpty {
            facets.append(["categories:\(category)"])
        }
        for group in categoryGroups where !group.isEmpty {
            facets.append(group.map { "categories:\($0)" })
        }
        let facetsData = try JSONSerialization.data(withJSONObject: facets)
        let facetsString = String(data: facetsData, encoding: .utf8) ?? "[]"

        let index = sortBy ?? (query.isEmpty ? "downloads" : "relevance")
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

        return try await downloader.fetchJSON(ModrinthSearchResult.self, from: url)
    }

    public func search(
        query: String,
        projectType: String = "mod",
        gameVersion: String? = nil,
        loader: String? = nil,
        loaders: [String] = [],
        sortBy: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ModrinthHit] {
        let result = try await searchPage(
            query: query,
            projectType: projectType,
            gameVersion: gameVersion,
            loader: loader,
            loaders: loaders,
            sortBy: sortBy,
            limit: limit,
            offset: offset
        )
        return result.hits
    }

    public func project(idOrSlug: String) async throws -> ModrinthProject {
        if CurseForgeClient.isCurseForgeID(idOrSlug) {
            return try await curseForge.project(id: idOrSlug)
        }
        let escaped = idOrSlug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? idOrSlug
        guard let url = URLComponents(string: "https://api.modrinth.com/v2/project/\(escaped)")?.url else {
            throw ModrinthError.badURL
        }
        return try await downloader.fetchJSON(ModrinthProject.self, from: url)
    }

    public func projects(ids: [String]) async throws -> [ModrinthProject] {
        let curseIDs = ids.filter(CurseForgeClient.isCurseForgeID)
        guard !curseIDs.isEmpty else {
            return try await modrinthProjects(ids: ids)
        }
        async let modrinth = modrinthProjects(ids: ids.filter { !CurseForgeClient.isCurseForgeID($0) })
        async let curse = curseForge.projects(ids: curseIDs)
        let (modrinthList, curseList) = try await (modrinth, curse)

        // Modrinth ids may be slugs; CurseForge projects only match by their "cf:" id.
        var remaining = modrinthList + curseList
        var ordered: [ModrinthProject] = []
        for id in ids {
            if let index = remaining.firstIndex(where: {
                $0.id == id || (!CurseForgeClient.isCurseForgeID($0.id) && $0.slug == id)
            }) {
                ordered.append(remaining.remove(at: index))
            }
        }
        return ordered + remaining
    }

    private func modrinthProjects(ids: [String]) async throws -> [ModrinthProject] {
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

    /// Projects by slug as search-style hits, in the order of `slugs`; slugs Modrinth does not know are skipped.
    public func hits(slugs: [String]) async throws -> [ModrinthHit] {
        guard !slugs.isEmpty else { return [] }
        let data = try JSONSerialization.data(withJSONObject: slugs)
        var components = URLComponents(string: "https://api.modrinth.com/v2/projects")
        components?.queryItems = [URLQueryItem(name: "ids", value: String(data: data, encoding: .utf8) ?? "[]")]
        guard let url = components?.url else { throw ModrinthError.badURL }

        struct Raw: Decodable {
            let id: String
            let slug: String
            let title: String
            let description: String
            let icon_url: URL?
            let downloads: Int
            let categories: [String]
            let followers: Int?
        }
        let raw = try await downloader.fetchJSON([Raw].self, from: url)
        let bySlug = Dictionary(raw.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
        return slugs.compactMap { bySlug[$0] }.map {
            ModrinthHit(
                projectId: $0.id, slug: $0.slug, title: $0.title, description: $0.description, author: "",
                iconURL: $0.icon_url, downloads: $0.downloads, categories: $0.categories, follows: $0.followers
            )
        }
    }

    public func versions(
        project idOrSlug: String,
        gameVersion: String? = nil,
        loader: String? = nil
    ) async throws -> [ModrinthVersion] {
        if CurseForgeClient.isCurseForgeID(idOrSlug) {
            return try await curseForge.versions(project: idOrSlug, gameVersion: gameVersion, loader: loader)
        }
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
        if CurseForgeClient.isCurseForgeID(id) {
            return try await curseForge.version(id: id)
        }
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URLComponents(string: "https://api.modrinth.com/v2/version/\(escaped)")?.url else {
            throw ModrinthError.badURL
        }
        return try await downloader.fetchJSON(ModrinthVersion.self, from: url)
    }
}
