import Foundation

public enum FabricInstallerError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case noStableLoaderFound(String)
    case missingProfileId

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .noStableLoaderFound(let mc):
            return "No stable Fabric loader found for Minecraft version '\(mc)'"
        case .missingProfileId:
            return "Fabric profile JSON is missing an 'id' field"
        }
    }
}

private struct FabricLoaderEntry: Decodable {
    struct Loader: Decodable {
        let version: String
        let stable: Bool?
    }
    let loader: Loader
}

private struct FabricProfileResponse: Decodable {
    let id: String
}

private struct FabricGameVersion: Decodable {
    let version: String
    let stable: Bool
}

public final class FabricInstaller: Sendable {
    public let paths: LauncherPaths
    public let installer: VersionInstaller
    public let downloader: Downloader

    public init(paths: LauncherPaths, installer: VersionInstaller, downloader: Downloader = Downloader()) {
        self.paths = paths
        self.installer = installer
        self.downloader = downloader
    }

    public func supportedGameVersions() async throws -> Set<String> {
        guard let url = URL(string: "https://meta.fabricmc.net/v2/versions/game") else {
            throw FabricInstallerError.invalidURL("https://meta.fabricmc.net/v2/versions/game")
        }
        let entries = try await downloader.fetchJSON([FabricGameVersion].self, from: url)
        return Set(entries.map { $0.version })
    }

    public func latestStableLoader(for mc: String) async throws -> String {
        guard let url = URL(string: "https://meta.fabricmc.net/v2/versions/loader/\(mc)") else {
            throw FabricInstallerError.invalidURL("https://meta.fabricmc.net/v2/versions/loader/\(mc)")
        }
        let entries = try await downloader.fetchJSON([FabricLoaderEntry].self, from: url)
        guard let stable = entries.first(where: { $0.loader.stable == true }) else {
            throw FabricInstallerError.noStableLoaderFound(mc)
        }
        return stable.loader.version
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

        // 1. Ensure vanilla <mc> is installed
        _ = try await installer.install(versionId: minecraftVersion, progress: progress)

        // 2. Download profile JSON
        let profileURLString = "https://meta.fabricmc.net/v2/versions/loader/\(minecraftVersion)/\(loader)/profile/json"
        guard let profileURL = URL(string: profileURLString) else {
            throw FabricInstallerError.invalidURL(profileURLString)
        }
        let profileData = try await downloader.fetchData(profileURL)
        let profile = try JSONDecoder().decode(FabricProfileResponse.self, from: profileData)
        let profileId = profile.id
        guard !profileId.isEmpty else {
            throw FabricInstallerError.missingProfileId
        }

        // Save to versions/<id>/<id>.json
        let versionDir = paths.versionDir(profileId)
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true, attributes: nil)
        let versionJSONURL = paths.versionJSON(profileId)
        try profileData.write(to: versionJSONURL, options: .atomic)

        // 3. Resolve and download libraries of the merged ResolvedVersion
        let resolved = try installer.resolve(versionId: profileId)
        try await installer.installLibraries(of: resolved) { prog in
            progress("libraries", prog)
        }

        return profileId
    }
}
