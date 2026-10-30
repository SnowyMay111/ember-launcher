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

private final class RefreshRateProviderBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: (@Sendable () -> Int?)?

    func get() -> (@Sendable () -> Int?)? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: (@Sendable () -> Int?)?) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}

public final class GameLauncher: Sendable {
    public let paths: LauncherPaths
    public let store: InstanceStore
    public let installer: VersionInstaller
    public let runtimeManager: JavaRuntimeManager
    private let refreshRateBox = RefreshRateProviderBox()

    public var displayRefreshRateProvider: (@Sendable () -> Int?)? {
        get { refreshRateBox.get() }
        set { refreshRateBox.set(newValue) }
    }

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
        if force {
            // A forced reinstall may bring new libraries: drop the unpacked natives (and their marker) so the next launch unpacks them again.
            for id in Set([instance.versionId, instance.minecraftVersion]) where !id.isEmpty {
                try? fm.removeItem(at: paths.versionDir(id).appendingPathComponent("natives", isDirectory: true))
            }
        }
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
        } else if instance.loader == "quilt" {
            let needsInstall = force
                || instance.versionId.isEmpty
                || !fm.fileExists(atPath: paths.versionJSON(instance.versionId).path)
                || !fm.fileExists(atPath: paths.versionJSON(instance.minecraftVersion).path)
            if needsInstall {
                let quiltInstaller = QuiltInstaller(paths: paths, installer: installer)
                let profileId = try await quiltInstaller.install(
                    minecraftVersion: instance.minecraftVersion,
                    loaderVersion: instance.loaderVersion,
                    progress: progress
                )
                let suffix = "-\(instance.minecraftVersion)"
                updated.versionId = profileId
                updated.loaderVersion = String(profileId.dropFirst(QuiltInstaller.profilePrefix.count).dropLast(suffix.count))
                if updated != instance {
                    try store.save(updated)
                }
            }
            return updated
        } else if let kind = ForgeLoaderKind(instanceLoader: instance.loader) {
            let needsInstall = force
                || instance.versionId.isEmpty
                || !fm.fileExists(atPath: paths.versionJSON(instance.versionId).path)
                || !fm.fileExists(atPath: paths.versionJSON(instance.minecraftVersion).path)
            if needsInstall {
                let forgeInstaller = ForgeInstaller(paths: paths, installer: installer, runtimeManager: runtimeManager)
                let result = try await forgeInstaller.install(
                    loader: kind,
                    minecraftVersion: instance.minecraftVersion,
                    loaderVersion: instance.loaderVersion,
                    progress: progress
                )
                updated.versionId = result.versionId
                updated.loaderVersion = result.loaderVersion
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
        account: MinecraftAccount,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> LaunchCommand {
        let java = try await ensureJava(for: instance, progress: progress)
        return try buildCommand(instance: instance, account: account, javaExecutable: java)
    }

    /// Downloads Mojang's Java for the installed version if it is missing and returns its `java` executable.
    @discardableResult
    public func ensureJava(
        for instance: Instance,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        let version = try resolveInstalled(instance)
        let defaultComponent = version.javaVersion?.component ?? (version.arguments == nil ? "jre-legacy" : "java-runtime-delta")
        let component = version.javaVersion?.component ?? defaultComponent
        let hasArm64Natives = version.libraries.contains {
            $0.name.contains("natives-macos-arm64") || ($0.downloads?.classifiers?["natives-macos-arm64"] != nil)
        }
        return try await runtimeManager.ensureRuntime(
            component: component,
            hasArm64Natives: hasArm64Natives,
            progress: progress
        )
    }

    public func buildCommand(instance: Instance, account: MinecraftAccount, javaExecutable: URL) throws -> LaunchCommand {
        let version = try resolveInstalled(instance)
        guard let mainClass = version.mainClass else {
            throw GameLauncherError.missingMainClass(version.id)
        }
        guard version.arguments != nil || version.minecraftArguments != nil || mainClass == "net.minecraft.client.Minecraft" else {
            throw GameLauncherError.unsupportedLegacyVersion(version.id)
        }

        let fm = FileManager.default
        let gameDir = store.gameDirectory(for: instance.name)
        let instanceDir = store.instanceDirectory(for: instance.name)
        let nativesDir = paths.versionDir(version.id).appendingPathComponent("natives", isDirectory: true)
        try fm.createDirectory(at: gameDir, withIntermediateDirectories: true, attributes: nil)
        try fm.createDirectory(at: nativesDir, withIntermediateDirectories: true, attributes: nil)

        let modsDir = gameDir.appendingPathComponent("mods", isDirectory: true)
        let refreshRate = instance.lockFpsToMonitor ? displayRefreshRateProvider?() : nil
        let renderCap = instance.capRenderDistance ? 12 : nil
        do {
            _ = try MinecraftOptionsPatcher.patch(
                instanceDirectory: gameDir,
                modsDirectory: modsDir,
                lockFpsToMonitor: instance.lockFpsToMonitor,
                displayRefreshRate: refreshRate,
                renderDistanceCap: renderCap
            )
        } catch {
            // Options patch failure must not block game launch
        }

        var classpath: [String] = []
        var seen = Set<String>()
        let nativesMarker = nativesDir.appendingPathComponent(".extracted")
        // The marker holds a stamp of the native libraries it was made from, so changed libraries are unpacked again.
        let nativesStamp = version.libraries
            .filter { RuleEvaluator.isAllowed(rules: $0.rules) && ($0.nativeClassifier != nil || $0.extract != nil) }
            .compactMap { $0.resolvedArtifact.map { "\($0.path):\($0.sha1 ?? "")" } }
            .sorted()
            .joined(separator: "\n")
        let needsNativesExtract = (try? String(contentsOf: nativesMarker, encoding: .utf8)) != nativesStamp
        var nativesOK = true

        for library in version.libraries {
            guard RuleEvaluator.isAllowed(rules: library.rules),
                  let artifact = library.resolvedArtifact else { continue }
            let file = paths.libraries.appendingPathComponent(artifact.path)

            if needsNativesExtract, library.nativeClassifier != nil || library.extract != nil {
                if fm.fileExists(atPath: file.path) {
                    do {
                        try ZipArchive.extract(file, to: nativesDir)
                    } catch {
                        nativesOK = false
                    }
                    if let excludes = library.extract?.exclude {
                        for pattern in excludes {
                            let clean = pattern.hasSuffix("/") ? String(pattern.dropLast()) : pattern
                            let target = nativesDir.appendingPathComponent(clean)
                            try? fm.removeItem(at: target)
                        }
                    }
                } else {
                    nativesOK = false
                }
            }

            guard seen.insert(file.path).inserted else { continue }
            guard fm.fileExists(atPath: file.path) else {
                throw GameLauncherError.missingLibrary(artifact.path)
            }
            classpath.append(file.path)
        }
        if needsNativesExtract && nativesOK {
            try? Data(nativesStamp.utf8).write(to: nativesMarker)
        }
        let clientJar = paths.versionJAR(version.clientJarID)
        guard fm.fileExists(atPath: clientJar.path) else {
            throw GameLauncherError.versionNotInstalled(version.clientJarID)
        }
        classpath.append(clientJar.path)
        let classpathString = classpath.joined(separator: ":")

        var assetsDirPath = paths.assetsRoot.path
        var gameAssetsDirPath = paths.assetsRoot.path
        if let assetIndexRef = version.assetIndex {
            let indexFile = paths.assetsIndexes.appendingPathComponent("\(assetIndexRef.id).json")
            if let indexData = try? Data(contentsOf: indexFile),
               let assetIndex = try? JSONDecoder().decode(AssetIndexData.self, from: indexData) {
                if assetIndex.virtual == true {
                    let virtualDir = paths.assetsRoot.appendingPathComponent("virtual/\(assetIndexRef.id)", isDirectory: true)
                    assetsDirPath = virtualDir.path
                    gameAssetsDirPath = virtualDir.path
                    for (relPath, object) in assetIndex.objects {
                        let hash = object.hash
                        let first2 = String(hash.prefix(2))
                        let src = paths.assetsObjects.appendingPathComponent(first2).appendingPathComponent(hash)
                        let dest = virtualDir.appendingPathComponent(relPath)
                        if !fm.fileExists(atPath: dest.path) {
                            try? fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                            try? fm.copyItem(at: src, to: dest)
                        }
                    }
                }
                if assetIndex.mapToResources == true {
                    let resourcesDir = gameDir.appendingPathComponent("resources", isDirectory: true)
                    gameAssetsDirPath = resourcesDir.path
                    for (relPath, object) in assetIndex.objects {
                        let hash = object.hash
                        let first2 = String(hash.prefix(2))
                        let src = paths.assetsObjects.appendingPathComponent(first2).appendingPathComponent(hash)
                        let dest = resourcesDir.appendingPathComponent(relPath)
                        if !fm.fileExists(atPath: dest.path) {
                            try? fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                            try? fm.copyItem(at: src, to: dest)
                        }
                    }
                }
            }
        }

        let variables: [String: String] = [
            "auth_player_name": account.name,
            "auth_session": "token:\(account.accessToken):\(account.uuid.replacingOccurrences(of: "-", with: ""))",
            "auth_uuid": account.uuid.replacingOccurrences(of: "-", with: ""),
            "auth_access_token": account.accessToken,
            "auth_xuid": "0",
            "clientid": "0",
            "user_type": account.userType,
            "user_properties": "{}",
            // Forge's `-DignoreList` names `${version_name}.jar`; the client jar on the classpath is the parent's, so that name must match it.
            "version_name": ForgeLoaderKind(instanceLoader: instance.loader) == nil ? version.id : version.clientJarID,
            "version_type": "release",
            "game_directory": gameDir.path,
            "game_assets": gameAssetsDirPath,
            "assets_root": assetsDirPath,
            "assets_index_name": version.assets ?? version.assetIndex?.id ?? "legacy",
            "natives_directory": nativesDir.path,
            "library_directory": paths.libraries.path,
            "classpath_separator": ":",
            "launcher_name": LauncherInfo.name,
            "launcher_version": LauncherInfo.version,
            "classpath": classpathString,
        ]

        let rawLegacyArgs = version.minecraftArguments ?? ""
        let hasGameDirPlaceholder = rawLegacyArgs.contains("${game_directory}") || (version.arguments?.game?.contains(where: {
            switch $0 {
            case .plain(let s): return s.contains("${game_directory}")
            case .conditional(_, let v): return v.asList.contains(where: { $0.contains("${game_directory}") })
            }
        }) ?? false)

        var userHomeArg: String?
        if !hasGameDirPlaceholder {
            if let homeDir = setupLegacyHomeDirectory(instanceDir: instanceDir, gameDir: gameDir) {
                userHomeArg = "-Duser.home=\(homeDir.path)"
            }
        }

        var jvmArguments: [String]
        let gameArguments: [String]

        if let arguments = version.arguments {
            jvmArguments = expand(arguments.jvm, variables: variables)
            if !jvmArguments.contains("-cp") && !jvmArguments.contains("-classpath") {
                jvmArguments += ["-cp", classpathString]
            }
            gameArguments = expand(arguments.game, variables: variables)
        } else {
            jvmArguments = [
                "-Djava.library.path=\(nativesDir.path)",
                "-Dminecraft.launcher.name=\(LauncherInfo.name)",
                "-Dminecraft.launcher.version=\(LauncherInfo.version)",
                "-cp",
                classpathString
            ]
            if mainClass == "net.minecraft.client.Minecraft" {
                gameArguments = [account.name, "token:0:0"]
            } else if let rawArgs = version.minecraftArguments {
                let tokens = rawArgs.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                gameArguments = tokens.map { substitute($0, variables: variables) }
            } else {
                gameArguments = []
            }
        }

        if let userHomeArg = userHomeArg {
            jvmArguments.append(userHomeArg)
        }

        DiagnosticJVMFlags.prepare(instanceDirectory: instanceDir)
        let effectiveJavaMajor = version.javaVersion?.majorVersion ?? (version.arguments == nil ? 8 : nil)
        let diagnosticArgs = DiagnosticJVMFlags.arguments(
            instanceDirectory: instanceDir,
            javaMajor: effectiveJavaMajor,
            userArguments: instance.extraJVMArgs
        )

        let memory = JVMArgumentsBuilder.arguments(
            memoryMB: instance.memoryMB,
            profile: instance.gcProfile,
            javaMajor: effectiveJavaMajor,
            userArguments: instance.extraJVMArgs
        )
        let all = memory + diagnosticArgs + instance.extraJVMArgs + jvmArguments + [mainClass] + gameArguments

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
        if command.executable.path.contains("-x64") {
            let rosettaPath = "/Library/Apple/usr/share/rosetta/rosetta"
            if !fm.fileExists(atPath: rosettaPath) {
                throw JavaRuntimeError.rosettaRequired
            }
        }

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

    private func setupLegacyHomeDirectory(instanceDir: URL, gameDir: URL) -> URL? {
        let homeDir = instanceDir.appendingPathComponent(".home", isDirectory: true)
        let appSupport = homeDir
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        let mcSymlink = appSupport.appendingPathComponent("minecraft")
        let fm = FileManager.default
        try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: nil)
        if !fm.fileExists(atPath: mcSymlink.path) && (try? fm.destinationOfSymbolicLink(atPath: mcSymlink.path)) == nil {
            try? fm.createSymbolicLink(at: mcSymlink, withDestinationURL: gameDir)
        }
        return homeDir
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
