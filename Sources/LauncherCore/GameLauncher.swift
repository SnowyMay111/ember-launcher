import Foundation

public enum GameLauncherError: Error, LocalizedError, Sendable {
    case versionNotInstalled(String)
    case missingMainClass(String)
    case unsupportedLegacyVersion(String)
    case missingLibrary(String)
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .versionNotInstalled(let id):
            return "Version '\(id)' is not installed. Run install first."
        case .missingMainClass(let id):
            return "Version '\(id)' has no main class"
        case .unsupportedLegacyVersion(let id):
            return "Version '\(id)' uses the old argument format (before 1.13), not supported"
        case .missingLibrary(let path):
            return "Library file is missing: \(path). Run install again."
        case .launchFailed(let reason):
            return "Could not start the game: \(reason)"
        }
    }
}

public struct LaunchCommand: Sendable {
    public let executable: URL
    public let arguments: [String]
    public let workingDirectory: URL
    public let logURL: URL

    public init(executable: URL, arguments: [String], workingDirectory: URL, logURL: URL) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.logURL = logURL
    }

    /// One argument per line, readable in a terminal.
    public var displayString: String {
        ([executable.path] + arguments).joined(separator: " \\\n  ")
    }
}

public final class GameLauncher: Sendable {
    public let paths: LauncherPaths
    public let store: InstanceStore
    public let installer: VersionInstaller
    public let runtimeManager: JavaRuntimeManager

    public init(paths: LauncherPaths, downloader: Downloader = Downloader()) {
        self.paths = paths
        self.store = InstanceStore(paths: paths)
        self.installer = VersionInstaller(paths: paths, downloader: downloader)
        self.runtimeManager = JavaRuntimeManager(paths: paths, downloader: downloader)
    }

    // MARK: - Instances

    /// Latest installed Fabric profile id (`fabric-loader-<loader>-<mc>`) for a Minecraft version.
    public func installedFabricVersionId(minecraftVersion: String) -> String? {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: paths.versions.path)) ?? []
        return entries
            .filter { id in
                id.hasPrefix("fabric-loader-")
                    && id.hasSuffix("-\(minecraftVersion)")
                    && FileManager.default.fileExists(atPath: paths.versionJSON(id).path)
            }
            .max { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Loads the instance, or creates it from an installed vanilla/Fabric version.
    public func prepareInstance(name: String, minecraftVersion: String, fabric: Bool) throws -> Instance {
        if let existing = try? store.load(name: name) {
            return existing
        }
        guard FileManager.default.fileExists(atPath: paths.versionJSON(minecraftVersion).path) else {
            throw GameLauncherError.versionNotInstalled(minecraftVersion)
        }
        if fabric {
            guard let profileId = installedFabricVersionId(minecraftVersion: minecraftVersion) else {
                throw GameLauncherError.versionNotInstalled("fabric for \(minecraftVersion)")
            }
            let loaderVersion = String(
                profileId.dropFirst("fabric-loader-".count).dropLast("-\(minecraftVersion)".count)
            )
            return try store.create(
                name: name,
                minecraftVersion: minecraftVersion,
                loader: "fabric",
                loaderVersion: loaderVersion,
                versionId: profileId
            )
        }
        return try store.create(name: name, minecraftVersion: minecraftVersion)
    }

    public func ensureInstalled(
        _ instance: Instance,
        force: Bool = false,
        progress: @escaping @Sendable (String, DownloadProgress) -> Void = { _, _ in }
    ) async throws -> Instance {
        var updated = instance
        let fm = FileManager.default
        if instance.loader == "fabric" {
            let needsInstall = force
                || instance.versionId.isEmpty
                || !fm.fileExists(atPath: paths.versionJSON(instance.versionId).path)
                || !fm.fileExists(atPath: paths.versionJSON(instance.minecraftVersion).path)
            if needsInstall {
                let fabricInstaller = FabricInstaller(paths: paths, installer: installer)
                let profileId = try await fabricInstaller.install(
                    minecraftVersion: instance.minecraftVersion,
                    loaderVersion: instance.loaderVersion,
                    progress: progress
                )
                let prefix = "fabric-loader-"
                let suffix = "-\(instance.minecraftVersion)"
                let loaderVersion = String(
                    profileId.dropFirst(prefix.count).dropLast(suffix.count)
                )
                updated.versionId = profileId
                updated.loaderVersion = loaderVersion
                if updated != instance {
                    try store.save(updated)
                }
            }
            return updated
        } else {
            let needsInstall = force || !fm.fileExists(atPath: paths.versionJSON(instance.versionId).path)
            if needsInstall {
                _ = try await installer.install(versionId: instance.versionId, progress: progress)
            }
            return updated
        }
    }

    // MARK: - Command

    /// Makes sure Mojang's Java for this version is present, then builds the command.
    public func makeCommand(
        instance: Instance,
        account: OfflineAccount,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> LaunchCommand {
        let version = try resolveInstalled(instance)
        let component = version.javaVersion?.component ?? "java-runtime-delta"
        let java = try await runtimeManager.ensureRuntime(component: component, progress: progress)
        return try buildCommand(instance: instance, account: account, javaExecutable: java)
    }

    public func buildCommand(instance: Instance, account: OfflineAccount, javaExecutable: URL) throws -> LaunchCommand {
        let version = try resolveInstalled(instance)
        guard let mainClass = version.mainClass else {
            throw GameLauncherError.missingMainClass(version.id)
        }
        guard let arguments = version.arguments else {
            throw GameLauncherError.unsupportedLegacyVersion(version.id)
        }

        let fm = FileManager.default
        let gameDir = store.gameDirectory(for: instance.name)
        let nativesDir = paths.versionDir(version.id).appendingPathComponent("natives", isDirectory: true)
        try fm.createDirectory(at: gameDir, withIntermediateDirectories: true, attributes: nil)
        try fm.createDirectory(at: nativesDir, withIntermediateDirectories: true, attributes: nil)

        var classpath: [String] = []
        var seen = Set<String>()
        for library in version.libraries {
            guard RuleEvaluator.isAllowed(rules: library.rules),
                  let artifact = library.resolvedArtifact else { continue }
            let file = paths.libraries.appendingPathComponent(artifact.path)
            guard seen.insert(file.path).inserted else { continue }
            guard fm.fileExists(atPath: file.path) else {
                throw GameLauncherError.missingLibrary(artifact.path)
            }
            classpath.append(file.path)
        }
        let clientJar = paths.versionJAR(version.clientJarID)
        guard fm.fileExists(atPath: clientJar.path) else {
            throw GameLauncherError.versionNotInstalled(version.clientJarID)
        }
        classpath.append(clientJar.path)
        let classpathString = classpath.joined(separator: ":")

        let variables: [String: String] = [
            "auth_player_name": account.name,
            "auth_uuid": account.uuid.replacingOccurrences(of: "-", with: ""),
            "auth_access_token": "0",
            "auth_xuid": "0",
            "clientid": "0",
            "user_type": "legacy",
            "user_properties": "{}",
            "version_name": version.id,
            "version_type": "release",
            "game_directory": gameDir.path,
            "assets_root": paths.assetsRoot.path,
            "assets_index_name": version.assets ?? version.assetIndex?.id ?? "legacy",
            "natives_directory": nativesDir.path,
            "library_directory": paths.libraries.path,
            "classpath_separator": ":",
            "launcher_name": LauncherInfo.name,
            "launcher_version": LauncherInfo.version,
            "classpath": classpathString,
        ]

        var jvmArguments = expand(arguments.jvm, variables: variables)
        if !jvmArguments.contains("-cp") && !jvmArguments.contains("-classpath") {
            jvmArguments += ["-cp", classpathString]
        }
        let gameArguments = expand(arguments.game, variables: variables)

        let memory = JVMArgumentsBuilder.arguments(
            memoryMB: instance.memoryMB,
            profile: instance.gcProfile,
            javaMajor: version.javaVersion?.majorVersion,
            userArguments: instance.extraJVMArgs
        )
        let all = memory + instance.extraJVMArgs + jvmArguments + [mainClass] + gameArguments

        return LaunchCommand(
            executable: javaExecutable,
            arguments: all,
            workingDirectory: gameDir,
            logURL: store.instanceDirectory(for: instance.name).appendingPathComponent("launcher.log")
        )
    }

    // MARK: - Start

    /// Starts the game; its output goes to `command.logURL`. The caller waits on the returned process.
    public func launch(_ command: LaunchCommand) throws -> Process {
        let fm = FileManager.default
        try fm.createDirectory(
            at: command.logURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        fm.createFile(atPath: command.logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: command.logURL)
        defer { try? log.close() }

        let process = Process()
        process.executableURL = command.executable
        process.arguments = command.arguments
        process.currentDirectoryURL = command.workingDirectory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = log
        process.standardError = log
        do {
            try process.run()
        } catch {
            throw GameLauncherError.launchFailed(error.localizedDescription)
        }
        return process
    }

    // MARK: - Helpers

    private func resolveInstalled(_ instance: Instance) throws -> ResolvedVersion {
        guard FileManager.default.fileExists(atPath: paths.versionJSON(instance.versionId).path) else {
            throw GameLauncherError.versionNotInstalled(instance.versionId)
        }
        return try installer.resolve(versionId: instance.versionId)
    }

    private func expand(_ entries: [ArgumentEntry]?, variables: [String: String]) -> [String] {
        var result: [String] = []
        for entry in entries ?? [] {
            switch entry {
            case .plain(let value):
                result.append(substitute(value, variables: variables))
            case .conditional(let rules, let value):
                guard RuleEvaluator.isAllowed(rules: rules) else { continue }
                result.append(contentsOf: value.asList.map { substitute($0, variables: variables) })
            }
        }
        return result
    }

    private func substitute(_ template: String, variables: [String: String]) -> String {
        var result = template
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "${\(key)}", with: value)
        }
        return result
    }
}
