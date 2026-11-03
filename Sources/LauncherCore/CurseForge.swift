import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum CurseForgeError: Error, LocalizedError, Sendable, Equatable {
    case distributionBlocked(project: String, url: URL?)
    case badResponse(Int)
    case invalidID(String)

    public var errorDescription: String? {
        switch self {
        case .distributionBlocked(let project, let url):
            let suffix = url.map { " Open it on CurseForge: \($0.absoluteString)" } ?? ""
            return "The author of '\(project)' does not allow downloads outside CurseForge.\(suffix)"
        case .badResponse(let status):
            return "CurseForge request failed with HTTP status \(status)"
        case .invalidID(let id):
            return "Invalid CurseForge id '\(id)'"
        }
    }
}

public struct CurseForgeMod: Codable, Sendable, Equatable {
    public struct Logo: Codable, Sendable, Equatable {
        public let thumbnailUrl: String?
        public let url: String?
    }

    public struct Author: Codable, Sendable, Equatable {
        public let name: String
    }

    public struct Category: Codable, Sendable, Equatable {
        public let slug: String?
        public let name: String?
    }

    public struct Links: Codable, Sendable, Equatable {
        public let websiteUrl: String?
    }

    public let id: Int
    public let name: String
    public let slug: String
    public let summary: String
    public let downloadCount: Int
    public let thumbsUpCount: Int?
    public let logo: Logo?
    public let authors: [Author]?
    public let categories: [Category]?
    public let classId: Int?
    /// `false` means third-party launchers must not download this project's files.
    public let allowModDistribution: Bool?
    public let links: Links?

    public var websiteURL: URL? {
        links?.websiteUrl.flatMap { URL(string: $0) }
    }
}

public struct CurseForgeFile: Codable, Sendable, Equatable {
    public struct Hash: Codable, Sendable, Equatable {
        public let value: String
        public let algo: Int
    }

    public struct Dependency: Codable, Sendable, Equatable {
        public let modId: Int
        public let relationType: Int
    }

    public let id: Int
    public let modId: Int
    public let displayName: String
    public let fileName: String
    public let releaseType: Int
    public let fileDate: String
    public let fileLength: Int
    /// nil when the author blocked third-party distribution.
    public let downloadUrl: String?
    /// Mixes game versions ("1.20.1") with loader and side names ("Fabric", "Client").
    public let gameVersions: [String]
    public let hashes: [Hash]
    public let dependencies: [Dependency]
}

struct CurseForgeEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    struct Pagination: Decodable, Sendable {
        let index: Int
        let pageSize: Int
        let resultCount: Int
        let totalCount: Int
    }

    let data: T
    let pagination: Pagination?
}

public final class CurseForgeClient: Sendable {
    public static let defaultBaseURL = URL(string: "https://zhjhuwajaymkykzcpkxi.supabase.co/functions/v1/curseforge-proxy")!
    public static let gameId = 432
    public static let classMod = 6
    public static let classModpack = 4471
    public static let classResourcePack = 12
    public static let classShader = 6552

    static let knownLoaders: Set<String> = ["fabric", "forge", "neoforge", "quilt"]

    public let baseURL: URL
    public let anonKey: String?
    public let downloader: Downloader

    public init(baseURL: URL = CurseForgeClient.defaultBaseURL, anonKey: String? = nil, downloader: Downloader = Downloader()) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.downloader = downloader
    }

    // MARK: - IDs

    public static func isCurseForgeID(_ id: String) -> Bool {
        id.hasPrefix("cf:")
    }

    public static func numericID(_ id: String) -> Int? {
        let raw = isCurseForgeID(id) ? String(id.dropFirst(3)) : id
        guard let value = Int(raw), value > 0 else { return nil }
        return value
    }

    /// Parses a version id of the form "cf:<modId>:<fileId>".
    static func parseVersionID(_ id: String) -> (modId: Int, fileId: Int)? {
        let parts = id.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "cf",
              let modId = Int(parts[1]), let fileId = Int(parts[2]),
              modId > 0, fileId > 0 else { return nil }
        return (modId, fileId)
    }

    // MARK: - Mapping

    public static func modLoaderType(_ loader: String?) -> Int? {
        switch loader?.lowercased() {
        case "forge": return 1
        case "fabric": return 4
        case "quilt": return 5
        case "neoforge": return 6
        default: return nil
        }
    }

    public static func loaderName(_ modLoaderType: Int) -> String? {
        switch modLoaderType {
        case 1: return "forge"
        case 4: return "fabric"
        case 5: return "quilt"
        case 6: return "neoforge"
        default: return nil
        }
    }

    public static func projectType(classId: Int?) -> String {
        switch classId {
        case classModpack: return "modpack"
        case classResourcePack: return "resourcepack"
        case classShader: return "shader"
        default: return "mod"
        }
    }

    /// nil for project types CurseForge search does not cover.
    public static func classId(projectType: String) -> Int? {
        switch projectType {
        case "mod": return classMod
        case "modpack": return classModpack
        case "resourcepack": return classResourcePack
        case "shader": return classShader
        default: return nil
        }
    }

    static func distributionBlockedError(for mod: CurseForgeMod) -> CurseForgeError {
        .distributionBlocked(project: mod.name.isEmpty ? mod.slug : mod.name, url: mod.websiteURL)
    }

    public static func versionType(_ releaseType: Int) -> String {
        switch releaseType {
        case 2: return "beta"
        case 3: return "alpha"
        default: return "release"
        }
    }

    /// nil for relation types the launcher ignores (4 Tool).
    public static func dependencyType(_ relationType: Int) -> ModrinthDependency.DependencyType? {
        switch relationType {
        case 1, 6: return .embedded
        case 2: return .optional
        case 3: return .required
        case 5: return .incompatible
        default: return nil
        }
    }

    public static func loaders(from gameVersions: [String]) -> [String] {
        var result: [String] = []
        for entry in gameVersions {
            let name = entry.lowercased()
            if knownLoaders.contains(name), !result.contains(name) {
                result.append(name)
            }
        }
        return result
    }

    public static func minecraftVersions(from gameVersions: [String]) -> [String] {
        gameVersions.filter { $0.first.map { $0.isASCII && $0.isNumber } ?? false }
    }

    public static func cdnURL(fileId: Int, fileName: String) -> URL? {
        guard let escaped = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://edge.forgecdn.net/files/\(fileId / 1000)/\(fileId % 1000)/\(escaped)")
    }

    public static func iconURL(of mod: CurseForgeMod) -> URL? {
        [mod.logo?.thumbnailUrl, mod.logo?.url]
            .compactMap { $0 }
            .compactMap { URL(string: $0) }
            .first
    }

    public static func mapMod(_ mod: CurseForgeMod) -> ModrinthHit {
        ModrinthHit(
            projectId: "cf:\(mod.id)",
            slug: mod.slug,
            title: mod.name,
            description: mod.summary,
            author: mod.authors?.first?.name ?? "",
            iconURL: iconURL(of: mod),
            downloads: mod.downloadCount,
            categories: (mod.categories ?? []).compactMap { $0.slug },
            follows: mod.thumbsUpCount
        )
    }

    public static func mapProject(_ mod: CurseForgeMod) -> ModrinthProject {
        ModrinthProject(
            id: "cf:\(mod.id)",
            slug: mod.slug,
            title: mod.name,
            description: mod.summary,
            iconURL: iconURL(of: mod),
            projectType: projectType(classId: mod.classId)
        )
    }

    /// `files` is empty when no URL is known (blocked distribution) or the file name is unsafe.
    public static func mapFile(_ file: CurseForgeFile, modId: Int, distributionAllowed: Bool) -> ModrinthVersion {
        let url = file.downloadUrl.flatMap { URL(string: $0) }
            ?? (distributionAllowed ? cdnURL(fileId: file.id, fileName: file.fileName) : nil)
        var files: [ModrinthFile] = []
        if let url, ModrinthFile.isSafeFilename(file.fileName) {
            let sha1 = file.hashes.first(where: { $0.algo == 1 })?.value
            files = [ModrinthFile(url: url, filename: file.fileName, size: file.fileLength, sha1: sha1, primary: true)]
        }
        let dependencies = file.dependencies.compactMap { dependency -> ModrinthDependency? in
            guard let type = dependencyType(dependency.relationType) else { return nil }
            return ModrinthDependency(projectId: "cf:\(dependency.modId)", type: type)
        }
        return ModrinthVersion(
            id: "cf:\(modId):\(file.id)",
            projectId: "cf:\(modId)",
            name: file.displayName,
            versionNumber: file.displayName,
            versionType: versionType(file.releaseType),
            datePublished: file.fileDate,
            gameVersions: minecraftVersions(from: file.gameVersions),
            loaders: loaders(from: file.gameVersions),
            files: files,
            dependencies: dependencies
        )
    }

    // MARK: - API

    static func searchQuery(
        query: String,
        classId: Int,
        gameVersion: String?,
        loader: String?,
        sortField: Int,
        limit: Int,
        offset: Int
    ) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "gameId", value: String(Self.gameId)),
            URLQueryItem(name: "classId", value: String(classId))
        ]
        if !query.isEmpty {
            items.append(URLQueryItem(name: "searchFilter", value: query))
        }
        if let gameVersion, !gameVersion.isEmpty {
            items.append(URLQueryItem(name: "gameVersion", value: gameVersion))
        }
        if let type = Self.modLoaderType(loader) {
            items.append(URLQueryItem(name: "modLoaderType", value: String(type)))
        }
        items += [
            URLQueryItem(name: "sortField", value: String(sortField)),
            URLQueryItem(name: "sortOrder", value: "desc"),
            URLQueryItem(name: "pageSize", value: String(limit))
        ]
        // An explicit `index=0` makes CurseForge answer with a wrong, tiny result set (SevTech: Ages vanishes), so the first page omits it.
        if offset > 0 {
            items.append(URLQueryItem(name: "index", value: String(offset)))
        }
        return items
    }

    public func searchPage(
        query: String,
        classId: Int = CurseForgeClient.classMod,
        gameVersion: String? = nil,
        loader: String? = nil,
        sortField: Int = 2,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> ModrinthSearchResult {
        let items = Self.searchQuery(
            query: query, classId: classId, gameVersion: gameVersion, loader: loader,
            sortField: sortField, limit: limit, offset: offset
        )
        let envelope = try await fetch([CurseForgeMod].self, path: "v1/mods/search", query: items)
        return ModrinthSearchResult(
            hits: envelope.data.filter { $0.classId == nil || $0.classId == classId }.map(Self.mapMod),
            totalHits: envelope.pagination?.totalCount ?? envelope.data.count
        )
    }

    public func project(id: String) async throws -> ModrinthProject {
        Self.mapProject(try await mod(id: id))
    }

    public func projects(ids: [String]) async throws -> [ModrinthProject] {
        guard !ids.isEmpty else { return [] }
        let numeric = try ids.map { id -> Int in
            guard let value = Self.numericID(id) else { throw CurseForgeError.invalidID(id) }
            return value
        }
        let body = try JSONSerialization.data(withJSONObject: ["modIds": numeric])
        let mods = try await fetch([CurseForgeMod].self, path: "v1/mods", body: body).data
        let byID = Dictionary(mods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return numeric.compactMap { byID[$0] }.map(Self.mapProject)
    }

    public func versions(project: String, gameVersion: String? = nil, loader: String? = nil) async throws -> [ModrinthVersion] {
        guard let modId = Self.numericID(project) else { throw CurseForgeError.invalidID(project) }
        var items: [URLQueryItem] = []
        if let gameVersion, !gameVersion.isEmpty {
            items.append(URLQueryItem(name: "gameVersion", value: gameVersion))
        }
        if let type = Self.modLoaderType(loader) {
            items.append(URLQueryItem(name: "modLoaderType", value: String(type)))
        }
        items += [
            URLQueryItem(name: "pageSize", value: "50")
        ]
        async let mod = mod(numericID: modId)
        async let files = fetch([CurseForgeFile].self, path: "v1/mods/\(modId)/files", query: items)
        let info = try await mod
        let allowed = info.allowModDistribution != false
        let list = try await files.data
            .map { Self.mapFile($0, modId: modId, distributionAllowed: allowed) }
            .sorted { $0.datePublished > $1.datePublished }
        // Blocked mods come back with every file stripped; report that instead of "no compatible version".
        if !allowed, !list.isEmpty, list.allSatisfy({ $0.files.isEmpty }) {
            throw Self.distributionBlockedError(for: info)
        }
        return list
    }

    public func version(id: String) async throws -> ModrinthVersion {
        guard let (modId, fileId) = Self.parseVersionID(id) else { throw CurseForgeError.invalidID(id) }
        async let mod = mod(numericID: modId)
        async let file = file(modId: modId, fileId: fileId)
        let info = try await mod
        let version = Self.mapFile(try await file, modId: modId, distributionAllowed: info.allowModDistribution != false)
        if info.allowModDistribution == false, version.files.isEmpty {
            throw Self.distributionBlockedError(for: info)
        }
        return version
    }

    public func file(modId: Int, fileId: Int) async throws -> CurseForgeFile {
        try await fetch(CurseForgeFile.self, path: "v1/mods/\(modId)/files/\(fileId)").data
    }

    /// Batch lookup, sent in chunks of 100 ids.
    public func files(ids: [Int]) async throws -> [CurseForgeFile] {
        var result: [CurseForgeFile] = []
        for start in stride(from: 0, to: ids.count, by: 100) {
            let body = try JSONSerialization.data(withJSONObject: ["fileIds": Array(ids[start..<min(start + 100, ids.count)])])
            result += try await fetch([CurseForgeFile].self, path: "v1/mods/files", body: body).data
        }
        return result
    }

    /// Batch lookup, sent in chunks of 100 ids.
    public func mods(numericIDs: [Int]) async throws -> [CurseForgeMod] {
        var result: [CurseForgeMod] = []
        for start in stride(from: 0, to: numericIDs.count, by: 100) {
            let body = try JSONSerialization.data(withJSONObject: ["modIds": Array(numericIDs[start..<min(start + 100, numericIDs.count)])])
            result += try await fetch([CurseForgeMod].self, path: "v1/mods", body: body).data
        }
        return result
    }

    public func resolvedDownloadURL(for file: CurseForgeFile, modId: Int) async throws -> URL {
        if let url = file.downloadUrl.flatMap({ URL(string: $0) }) {
            return url
        }
        if let raw = try? await fetch(String?.self, path: "v1/mods/\(modId)/files/\(file.id)/download-url").data,
           let url = URL(string: raw) {
            return url
        }
        let mod = try? await mod(numericID: modId)
        throw CurseForgeError.distributionBlocked(project: mod?.name ?? mod?.slug ?? "cf:\(modId)", url: mod?.websiteURL)
    }

    // MARK: - Transport

    private func mod(id: String) async throws -> CurseForgeMod {
        guard let modId = Self.numericID(id) else { throw CurseForgeError.invalidID(id) }
        return try await mod(numericID: modId)
    }

    private func mod(numericID: Int) async throws -> CurseForgeMod {
        try await fetch(CurseForgeMod.self, path: "v1/mods/\(numericID)").data
    }

    /// Plain GETs go through `downloader`; requests that need the proxy auth headers or a body use URLSession.
    private func fetch<T: Decodable & Sendable>(
        _ type: T.Type,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> CurseForgeEnvelope<T> {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else {
            throw ModrinthError.badURL
        }

        let key = anonKey.flatMap { $0.isEmpty ? nil : $0 }
        guard key != nil || body != nil else {
            return try await downloader.fetchJSON(CurseForgeEnvelope<T>.self, from: url)
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let key {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue(key, forHTTPHeaderField: "apikey")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CurseForgeError.badResponse(http.statusCode)
        }
        return try JSONDecoder().decode(CurseForgeEnvelope<T>.self, from: data)
    }
}
