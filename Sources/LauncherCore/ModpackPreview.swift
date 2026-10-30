import Foundation

/// Classifies a modpack file by its install location inside the pack.
public enum ModpackPreviewKind: String, Sendable {
    case mod, resourcePack, shader, other

    /// Derives a kind from the file's relative path prefix.
    public init(path: String) {
        if path.hasPrefix("mods/") { self = .mod }
        else if path.hasPrefix("resourcepacks/") { self = .resourcePack }
        else if path.hasPrefix("shaderpacks/") { self = .shader }
        else { self = .other }
    }

    /// Ordering used when sorting preview entries.
    var sortOrder: Int {
        switch self {
        case .mod: return 0
        case .resourcePack: return 1
        case .shader: return 2
        case .other: return 3
        }
    }
}

/// A single file in a modpack preview, enriched with Modrinth metadata where available.
public struct ModpackPreviewEntry: Sendable, Identifiable, Equatable {
    public var id: String
    public var path: String
    public var fileName: String
    public var kind: ModpackPreviewKind
    public var projectId: String?
    public var versionId: String?
    public var title: String
    public var summary: String?
    public var iconURL: URL?
    public var size: Int64
    public var requiredBy: [String]

    public init(
        id: String,
        path: String,
        fileName: String,
        kind: ModpackPreviewKind,
        projectId: String?,
        versionId: String?,
        title: String,
        summary: String?,
        iconURL: URL?,
        size: Int64,
        requiredBy: [String]
    ) {
        self.id = id
        self.path = path
        self.fileName = fileName
        self.kind = kind
        self.projectId = projectId
        self.versionId = versionId
        self.title = title
        self.summary = summary
        self.iconURL = iconURL
        self.size = size
        self.requiredBy = requiredBy
    }
}

/// A fully resolved preview of an mrpack: its summary plus per-file metadata.
public struct ModpackPreview: Sendable {
    public var summary: MrpackSummary
    public var archive: URL
    public var workDir: URL
    public var entries: [ModpackPreviewEntry]

    public init(summary: MrpackSummary, archive: URL, workDir: URL, entries: [ModpackPreviewEntry]) {
        self.summary = summary
        self.archive = archive
        self.workDir = workDir
        self.entries = entries
    }
}

/// Splits an array into chunks of at most `size` elements.
private func chunked<T>(_ items: [T], size: Int) -> [[T]] {
    guard size > 0, !items.isEmpty else { return items.isEmpty ? [] : [items] }
    return stride(from: 0, to: items.count, by: size).map {
        Array(items[$0..<min($0 + size, items.count)])
    }
}

extension ModrinthClient {
    /// Fetches Modrinth versions by id, chunking requests to respect the API limit.
    public func versions(ids: [String]) async throws -> [ModrinthVersion] {
        guard !ids.isEmpty else { return [] }
        var result: [ModrinthVersion] = []
        for chunk in chunked(ids, size: 50) {
            let data = try JSONSerialization.data(withJSONObject: chunk)
            let idsString = String(data: data, encoding: .utf8) ?? "[]"
            var components = URLComponents(string: "https://api.modrinth.com/v2/versions")
            components?.queryItems = [URLQueryItem(name: "ids", value: idsString)]
            guard let url = components?.url else { throw ModrinthError.badURL }
            result += try await downloader.fetchJSON([ModrinthVersion].self, from: url)
        }
        return result
    }
}

extension ModpackManager {
    /// A file's path paired with the Modrinth ids parsed from its download URL, if any.
    private struct ParsedFile {
        let file: MrpackFile
        let projectId: String?
        let versionId: String?
    }

    /// Fetches Modrinth projects by id, chunking requests to respect the API limit.
    private func resolveProjects(ids: [String]) async throws -> [ModrinthProject] {
        var result: [ModrinthProject] = []
        for chunk in chunked(ids, size: 100) {
            result += try await client.projects(ids: chunk)
        }
        return result
    }

    /// Extracts the Modrinth projectId/versionId from a cdn.modrinth.com download URL.
    private func modrinthIds(for file: MrpackFile) -> (projectId: String?, versionId: String?) {
        for urlString in file.downloads {
            guard let url = URL(string: urlString), url.host == "cdn.modrinth.com" else { continue }
            let components = url.pathComponents
            if let dataIdx = components.firstIndex(of: "data"),
               components.count > dataIdx + 3,
               components[dataIdx + 2] == "versions" {
                return (components[dataIdx + 1], components[dataIdx + 3])
            }
        }
        return (nil, nil)
    }

    /// Extracts and inspects an mrpack, resolving Modrinth metadata for each client-side file.
    public func preview(archive: URL, workDir: URL) async throws -> ModpackPreview {
        try validateArchiveBeforeExtract(archive)
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? fm.removeItem(at: tempDir) }

        try extractWithinLimit(archive, to: tempDir)
        try validateNoSymbolicLinks(in: tempDir)
        let (index, _, _, _) = try parseAndValidateIndex(in: tempDir)

        let clientFiles = index.files.filter { $0.env?.client != "unsupported" }
        for file in clientFiles {
            guard isSafeRelativePath(file.path, relativeTo: tempDir) else { throw ModpackError.unsafePath(file.path) }
        }

        let summary = try inspect(archive)

        let parsed: [ParsedFile] = clientFiles.map { file in
            let (projectId, versionId) = modrinthIds(for: file)
            return ParsedFile(file: file, projectId: projectId, versionId: versionId)
        }

        let projectIds = Array(Set(parsed.compactMap(\.projectId)))
        // Old download URLs may carry a version number instead of an id; Modrinth rejects the whole request for those.
        let versionIds = Array(Set(parsed.compactMap(\.versionId).filter { id in
            id.count == 8 && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        }))

        var projectsById: [String: ModrinthProject] = [:]
        if !projectIds.isEmpty, let projects = try? await resolveProjects(ids: projectIds) {
            for project in projects { projectsById[project.id] = project }
        }
        var versionsById: [String: ModrinthVersion] = [:]
        if !versionIds.isEmpty, let versions = try? await client.versions(ids: versionIds) {
            for version in versions { versionsById[version.id] = version }
        }

        var entries: [ModpackPreviewEntry] = parsed.map { item in
            let fileName = (item.file.path as NSString).lastPathComponent
            let project = item.projectId.flatMap { projectsById[$0] }
            let title = project?.title ?? (fileName as NSString).deletingPathExtension
            return ModpackPreviewEntry(
                id: item.file.path,
                path: item.file.path,
                fileName: fileName,
                kind: ModpackPreviewKind(path: item.file.path),
                projectId: item.projectId,
                versionId: item.versionId,
                title: title,
                summary: project?.description,
                iconURL: project?.iconURL,
                size: Int64(item.file.fileSize),
                requiredBy: []
            )
        }

        // Fill in requiredBy: for each entry's required dependency, append its title to the depended-on entry.
        var requiredByProjectId: [String: [String]] = [:]
        for (index, item) in parsed.enumerated() {
            guard let versionId = item.versionId, let version = versionsById[versionId] else { continue }
            let entryTitle = entries[index].title
            for dependency in version.dependencies where dependency.type == .required {
                guard let depProjectId = dependency.projectId, depProjectId != item.projectId else { continue }
                requiredByProjectId[depProjectId, default: []].append(entryTitle)
            }
        }
        for index in entries.indices {
            guard let projectId = entries[index].projectId, let titles = requiredByProjectId[projectId] else { continue }
            var seen = Set<String>()
            entries[index].requiredBy = titles.filter { seen.insert($0).inserted }
        }

        entries.sort { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            return lhs.title.lowercased() < rhs.title.lowercased()
        }

        return ModpackPreview(summary: summary, archive: archive, workDir: workDir, entries: entries)
    }
}
