import Foundation

public enum QuiltInstallerError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case noLoaderFound(String)
    case missingProfileId

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .noLoaderFound(let mc):
            return "No Quilt loader found for Minecraft version '\(mc)'"
        case .missingProfileId:
            return "Quilt profile JSON is missing an 'id' field"
        }
    }
}

private struct QuiltLoaderEntry: Decodable {
    struct Loader: Decodable {
        let version: String
    }
    let loader: Loader
}

private struct QuiltProfileResponse: Decodable {
    let id: String
}

private struct QuiltGameVersion: Decodable {
    let version: String
}

/// Installs Quilt Loader from meta.quiltmc.org; the profile JSON has the same shape as Fabric's.
public final class QuiltInstaller: Sendable {
    static let metaBase = "https://meta.quiltmc.org/v3/versions"
    public static let profilePrefix = "quilt-loader-"

    public let paths: LauncherPaths
    public let installer: VersionInstaller
    public let downloader: Downloader

    public init(paths: LauncherPaths, installer: VersionInstaller, downloader: Downloader = Downloader()) {
        self.paths = paths
        self.installer = installer
        self.downloader = downloader
    }

    public func supportedGameVersions() async throws -> Set<String> {
        let urlString = "\(Self.metaBase)/game"
        guard let url = URL(string: urlString) else {
            throw QuiltInstallerError.invalidURL(urlString)
        }
        let entries = try await downloader.fetchJSON([QuiltGameVersion].self, from: url)
        return Set(entries.map { $0.version })
    }

    /// Quilt marks no loader as stable; a version without a "-beta" or "-rc" suffix is a release.
    public func latestStableLoader(for mc: String) async throws -> String {
        let urlString = "\(Self.metaBase)/loader/\(mc)"
        guard let url = URL(string: urlString) else {
            throw QuiltInstallerError.invalidURL(urlString)
        }
        let entries = try await downloader.fetchJSON([QuiltLoaderEntry].self, from: url)
        // The list is not sorted, so take the highest release by number.
        let versions = entries.map(\.loader.version)
        let releases = versions.filter { !$0.contains("-") }
        let best = (releases.isEmpty ? versions : releases).max { $0.compare($1, options: .numeric) == .orderedAscending }
        guard let best else {
            throw QuiltInstallerError.noLoaderFound(mc)
        }
        return best
    }

    public func install(
        minecraftVersion: String,
        loaderVersion: String? = nil,
        progress: @escaping @Sendable (String, DownloadProgress) -> Void = { _, _ in }
    ) async throws -> String {
        try paths.ensureDirectories()

        let loader: String
        if let customLoader = loaderVersion, !customLoader.isEmpty {
            loader = customLoader
        } else {
            loader = try await latestStableLoader(for: minecraftVersion)
        }

        _ = try await installer.install(versionId: minecraftVersion, progress: progress)

        let profileURLString = "\(Self.metaBase)/loader/\(minecraftVersion)/\(loader)/profile/json"
        guard let profileURL = URL(string: profileURLString) else {
            throw QuiltInstallerError.invalidURL(profileURLString)
        }
        let profileData = try await downloader.fetchData(profileURL)
        let profile = try JSONDecoder().decode(QuiltProfileResponse.self, from: profileData)
        guard !profile.id.isEmpty else {
            throw QuiltInstallerError.missingProfileId
        }

        let versionDir = paths.versionDir(profile.id)
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true, attributes: nil)
        try profileData.write(to: paths.versionJSON(profile.id), options: .atomic)

        let resolved = try installer.resolve(versionId: profile.id)
        try await installer.installLibraries(of: resolved) { prog in
            progress("libraries", prog)
        }

        return profile.id
    }
}
