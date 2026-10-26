import Foundation

public enum ForgeLoaderKind: String, Sendable, CaseIterable {
    case forge
    case neoforge

    public init?(instanceLoader: String) {
        self.init(rawValue: instanceLoader.lowercased())
    }

    public var displayName: String {
        switch self {
        case .forge: return "Forge"
        case .neoforge: return "NeoForge"
        }
    }
}

public enum ForgeInstallerError: Error, LocalizedError, Sendable {
    case noVersion(loader: String, minecraft: String)
    case installerUnavailable(loader: String, version: String)
    case installerFailed(loader: String, log: String)
    case versionNotCreated(loader: String)

    public var errorDescription: String? {
        switch self {
        case .noVersion(let loader, let minecraft):
            return "\(loader) has no build for Minecraft \(minecraft)"
        case .installerUnavailable(let loader, let version):
            return "Could not download the \(loader) installer for \(version)"
        case .installerFailed(let loader, let log):
            return "The \(loader) installer failed. \(log)"
        case .versionNotCreated(let loader):
            return "The \(loader) installer finished but created no version"
        }
    }
}

private struct ForgePromotions: Decodable {
    let promos: [String: String]
}

private struct NeoForgeVersions: Decodable {
    let versions: [String]
}

/// Installs Forge and NeoForge the way their own installers do: download the installer jar and run it
/// against the launcher folder, which writes the version JSON and every library (including the patched client).
public final class ForgeInstaller: Sendable {
    public let paths: LauncherPaths
    public let installer: VersionInstaller
    public let downloader: Downloader
    public let runtimeManager: JavaRuntimeManager

    public init(
        paths: LauncherPaths,
        installer: VersionInstaller,
        runtimeManager: JavaRuntimeManager,
        downloader: Downloader = Downloader()
    ) {
        self.paths = paths
        self.installer = installer
        self.runtimeManager = runtimeManager
        self.downloader = downloader
    }

    // MARK: - Versions

    private static let promotionsURL = URL(string: "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json")!
    private static let neoForgeVersionsURL = URL(string: "https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge")!

    /// Forge builds start at 1.8.9 here; older installers do not support a headless install.
    static func isSupportedForgeMinecraft(_ id: String) -> Bool {
        let parts = id.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2, parts[0] == 1 else { return false }
        return parts[1] > 8 || (parts[1] == 8 && parts.count >= 3 && parts[2] >= 9)
    }

    /// NeoForge numbers its builds after the Minecraft version: 1.21.1 → `21.1.`, 1.21 → `21.0.`, 26.3 → `26.3.`.
    static func neoForgePrefix(for minecraft: String) -> String {
        guard minecraft.hasPrefix("1.") else { return minecraft + "." }
        let parts = minecraft.dropFirst(2).split(separator: ".")
        guard let first = parts.first else { return minecraft + "." }
        return parts.count > 1 ? "\(first).\(parts[1])." : "\(first).0."
    }

    /// The Minecraft versions out of `candidates` that this loader has a build for.
    public func supportedGameVersions(loader: ForgeLoaderKind, among candidates: [String]) async throws -> Set<String> {
        switch loader {
        case .forge:
            let promos = try await downloader.fetchJSON(ForgePromotions.self, from: Self.promotionsURL).promos
            var found = Set<String>()
            for key in promos.keys {
                for suffix in ["-recommended", "-latest"] where key.hasSuffix(suffix) {
                    found.insert(String(key.dropLast(suffix.count)))
                }
            }
            return Set(candidates.filter { found.contains($0) && Self.isSupportedForgeMinecraft($0) })
        case .neoforge:
            let versions = try await downloader.fetchJSON(NeoForgeVersions.self, from: Self.neoForgeVersionsURL).versions
            return Set(candidates.filter { id in
                let prefix = Self.neoForgePrefix(for: id)
                return versions.contains { $0.hasPrefix(prefix) }
            })
        }
    }

    /// The recommended Forge build, else the newest; for NeoForge the newest stable build, else the newest beta.
    public func latestLoaderVersion(loader: ForgeLoaderKind, minecraft: String) async throws -> String {
        switch loader {
        case .forge:
            let promos = try await downloader.fetchJSON(ForgePromotions.self, from: Self.promotionsURL).promos
            if let version = promos["\(minecraft)-recommended"] ?? promos["\(minecraft)-latest"] { return version }
        case .neoforge:
            let prefix = Self.neoForgePrefix(for: minecraft)
            let versions = try await downloader.fetchJSON(NeoForgeVersions.self, from: Self.neoForgeVersionsURL).versions
                .filter { $0.hasPrefix(prefix) }
            let ordered = { (list: [String]) in list.max { $0.compare($1, options: .numeric) == .orderedAscending } }
            if let stable = ordered(versions.filter { !$0.contains("-") }) ?? ordered(versions) { return stable }
        }
        throw ForgeInstallerError.noVersion(loader: loader.displayName, minecraft: minecraft)
    }

    // MARK: - Install

    /// Installs vanilla `minecraftVersion`, then the loader on top. Returns the version id the instance should launch.
    public func install(
        loader: ForgeLoaderKind,
        minecraftVersion: String,
        loaderVersion: String? = nil,
        progress: @escaping @Sendable (String, DownloadProgress) -> Void = { _, _ in }
    ) async throws -> (versionId: String, loaderVersion: String) {
        try paths.ensureDirectories()
        func step(_ done: Int) { progress("loader", DownloadProgress(completedFiles: done, totalFiles: 100, completedBytes: 0)) }

        _ = try await installer.install(versionId: minecraftVersion, progress: progress)
        step(5)

        let version: String
        if let loaderVersion, !loaderVersion.isEmpty {
            version = loaderVersion
        } else {
            version = try await latestLoaderVersion(loader: loader, minecraft: minecraftVersion)
        }

        let jar = try await downloadInstaller(loader: loader, minecraft: minecraftVersion, version: version)
        step(15)

        let java = try await javaForInstaller(minecraftVersion: minecraftVersion)
        step(20)

        try prepareLauncherProfiles()
        try await run(loader: loader, jar: jar, java: java, version: version)

        guard let versionId = installedVersionId(loader: loader, loaderVersion: version) else {
            throw ForgeInstallerError.versionNotCreated(loader: loader.displayName)
        }
        step(100)
        return (versionId, version)
    }

    private var installersDirectory: URL {
        paths.root.appendingPathComponent("installers", isDirectory: true)
    }

    private func downloadInstaller(loader: ForgeLoaderKind, minecraft: String, version: String) async throws -> URL {
        let candidates: [String]
        switch loader {
        case .forge:
            // A few old builds carry the Minecraft version twice in their file names.
            candidates = [
                "https://maven.minecraftforge.net/net/minecraftforge/forge/\(minecraft)-\(version)/forge-\(minecraft)-\(version)-installer.jar",
                "https://maven.minecraftforge.net/net/minecraftforge/forge/\(minecraft)-\(version)-\(minecraft)/forge-\(minecraft)-\(version)-\(minecraft)-installer.jar",
            ]
        case .neoforge:
            candidates = ["https://maven.neoforged.net/releases/net/neoforged/neoforge/\(version)/neoforge-\(version)-installer.jar"]
        }

        let fm = FileManager.default
        try fm.createDirectory(at: installersDirectory, withIntermediateDirectories: true, attributes: nil)
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            let dest = installersDirectory.appendingPathComponent(url.lastPathComponent)
            if fm.fileExists(atPath: dest.path) { return dest }
            do {
                try await downloader.download(url: url, to: dest, sha1: nil, size: nil)
                return dest
            } catch {
                continue
            }
        }
        throw ForgeInstallerError.installerUnavailable(loader: loader.displayName, version: version)
    }

    /// Same runtime the game itself will use, so the installer's processors run on a Java the version supports.
    private func javaForInstaller(minecraftVersion: String) async throws -> URL {
        let vanilla = try installer.resolve(versionId: minecraftVersion)
        let component = vanilla.javaVersion?.component ?? (vanilla.arguments == nil ? "jre-legacy" : "java-runtime-delta")
        let hasArm64Natives = vanilla.libraries.contains {
            $0.name.contains("natives-macos-arm64") || ($0.downloads?.classifiers?["natives-macos-arm64"] != nil)
        }
        return try await runtimeManager.ensureRuntime(component: component, hasArm64Natives: hasArm64Natives)
    }

    /// The installer refuses to run in a folder that has no `launcher_profiles.json`.
    private func prepareLauncherProfiles() throws {
        let file = paths.root.appendingPathComponent("launcher_profiles.json")
        guard !FileManager.default.fileExists(atPath: file.path) else { return }
        try Data(#"{"profiles":{},"version":3}"#.utf8).write(to: file, options: .atomic)
    }

    private func run(loader: ForgeLoaderKind, jar: URL, java: URL, version: String) async throws {
        // NeoForge spells the flag with dashes; Forge (and old NeoForge builds) in camel case.
        let flags = loader == .neoforge ? ["--install-client", "--installClient"] : ["--installClient"]
        var lastLog = ""
        for flag in flags {
            let logURL = installersDirectory.appendingPathComponent("\(loader.rawValue)-\(version).log")
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
            let log = try FileHandle(forWritingTo: logURL)
            defer { try? log.close() }

            let process = Process()
            process.executableURL = java
            process.arguments = ["-jar", jar.path, flag, paths.root.path]
            process.currentDirectoryURL = installersDirectory
            process.standardOutput = log
            process.standardError = log

            let status: Int32 = try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
                do { try process.run() } catch { continuation.resume(throwing: error) }
            }
            if status == 0 { return }

            let text = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            lastLog = text.split(separator: "\n").suffix(6).joined(separator: " ")
        }
        throw ForgeInstallerError.installerFailed(loader: loader.displayName, log: lastLog)
    }

    /// The version folder the installer created for this loader build.
    private func installedVersionId(loader: ForgeLoaderKind, loaderVersion: String) -> String? {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: paths.versions.path)) ?? []
        return entries.first { id in
            let lower = id.lowercased()
            guard id.contains(loaderVersion), FileManager.default.fileExists(atPath: paths.versionJSON(id).path) else { return false }
            return loader == .neoforge ? lower.contains("neoforge") : (lower.contains("forge") && !lower.contains("neoforge"))
        }
    }
}
