import Foundation
import LauncherCore

print("\(LauncherInfo.name) \(LauncherInfo.version)")

final class ProgressPrinter: @unchecked Sendable {
    private let lock = NSLock()
    private var lastDecile: [String: Int] = [:]

    func update(phase: String, progress: DownloadProgress) {
        guard progress.totalFiles > 0 else { return }
        let percent = (progress.completedFiles * 100) / progress.totalFiles
        let decile = (percent / 10) * 10
        lock.lock()
        defer { lock.unlock() }
        let last = lastDecile[phase] ?? -10
        if decile >= last + 10 {
            lastDecile[phase] = decile
            print("[\(phase)] \(decile)% (\(progress.completedFiles)/\(progress.totalFiles))")
        }
    }
}

let args = CommandLine.arguments

guard args.count >= 2 else {
    print("Usage: launcher-cli <command> [options]")
    print("Commands:")
    print("  versions              List latest and recent release versions")
    print("  install <versionId>   Install a Minecraft version and its Java runtime")
    print("  install-quilt <mc> [--loader <version>]")
    print("                        Install Quilt for an installed Minecraft version")
    print("  install-fabric <mc> [--loader <version>]")
    print("                        Install Fabric for an installed Minecraft version")
    print("  launch <mc> [--fabric] [--name <nick>] [--instance <name>] [--dry-run]")
    print("                        Start the game (offline nick, default Player)")
    print("  diagnose <instance-name>")
    print("                        Diagnose crash from logs and crash reports")
    print("  mods search <query> [--mc <version>] [--loader fabric]")
    print("  mods list <instance>")
    print("  mods install <instance> <slug-or-id>")
    print("  mods toggle <instance> <fileName>")
    print("  mods remove <instance> <fileName>")
    print("  mods updates <instance> [--apply]")
    print("  mods upgrade-check <instance> <gameVersion>")
    print("  snapshots <instance>  List snapshots for an instance")
    print("  snapshot <instance> [reason]")
    print("                        Create a snapshot")
    print("  upgrade <instance> <gameVersion>")
    print("                        Upgrade instance game version")
    print("  restore <instance> <snapshot-id>")
    print("                        Restore instance from snapshot")
    print("  optimize <instance> --preset <maxFPS_PvP|balancedLoD|shadersVisual|heavyModpack> [--shaders] [--lod] [--framegen] [--os mac|windows] [--apply] [--optional]")
    print("                        Optimize instance mods and configuration")
    print("  mrpack export <instance> <file.mrpack> [--version 1.0.0] [--no-shaders] [--no-config]")
    print("                        Export instance to a Modrinth .mrpack modpack")
    print("  mrpack inspect <file.mrpack>")
    print("                        Inspect a Modrinth .mrpack modpack")
    print("  mrpack import <file.mrpack> [--name \"My pack\"] [--group Mods] [--memory 6144]")
    print("                        Import a Modrinth .mrpack modpack")
    print("  ai-plan \"description\" [--version 1.21.4] [--provider claude|gemini] [--key-env VAR] [--model id] [--answer file.json] [--install <instance>]")
    print("                        Ask the AI for a Fabric mod list (key is read from the environment variable); --answer uses a saved reply instead")
    print("  catalog search <mod|modpack|shader|resourcepack> <query> [--game-version V]")
    print("  catalog install <kind> <slug> <instance>")
    print("  catalog modpack <slug> [name]")
    print("  update check          Look for a newer launcher on GitHub Releases (debug builds: VOXEL_UPDATE_URL overrides the address)")
    exit(1)
}

func option(_ name: String) -> String? {
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

func flag(_ name: String) -> Bool {
    args.contains(name)
}

let command = args[1]
let paths = LauncherPaths()
let downloader = Downloader()

do {
    try paths.ensureDirectories()
    switch command {
    case "versions":
        let installer = VersionInstaller(paths: paths, downloader: downloader)
        let manifest = try await installer.fetchManifest()
        if flag("--all") {
            let versions = VersionCatalog.launchable(manifest, includeSnapshots: true, includeOld: true)
            for version in versions {
                let kind = VersionCatalog.kind(for: version.type).rawValue
                print("  - \(version.id) [\(kind)]")
            }
        } else {
            print("Latest release: \(manifest.latest.release)")
            print("Latest snapshot: \(manifest.latest.snapshot)")
            print("Recent releases:")
            let releases = manifest.versions.filter { $0.type == "release" }.prefix(10)
            for version in releases {
                print("  - \(version.id)")
            }
        }

    case "install":
        guard args.count >= 3 else {
            print("Error: Missing versionId. Usage: launcher-cli install <versionId>")
            exit(1)
        }
        let versionId = args[2]
        print("Installing version: \(versionId)...")
        let installer = VersionInstaller(paths: paths, downloader: downloader)
        let printer = ProgressPrinter()
        let versionJSON = try await installer.install(versionId: versionId) { phase, progress in
            printer.update(phase: phase, progress: progress)
        }

        let defaultComponent = versionJSON.javaVersion?.component ?? (versionJSON.arguments == nil ? "jre-legacy" : "java-runtime-delta")
        let component = versionJSON.javaVersion?.component ?? defaultComponent
        let hasArm64 = (versionJSON.libraries ?? []).contains {
            $0.name.contains("natives-macos-arm64") || ($0.downloads?.classifiers?["natives-macos-arm64"] != nil)
        }
        print("Ensuring Java runtime (\(component))...")
        let runtimeManager = JavaRuntimeManager(paths: paths, downloader: downloader)
        let javaURL = try await runtimeManager.ensureRuntime(component: component, hasArm64Natives: hasArm64) { progress in
            printer.update(phase: "runtime", progress: progress)
        }

        print("\nInstallation finished successfully.")
        print("Version: \(versionJSON.id)")
        print("Java executable: \(javaURL.path)")

    case "install-fabric":
        guard args.count >= 3 else {
            print("Error: Missing Minecraft version. Usage: launcher-cli install-fabric <mc> [--loader <version>]")
            exit(1)
        }
        let mc = args[2]
        print("Installing Fabric for \(mc)...")
        let installer = VersionInstaller(paths: paths, downloader: downloader)
        let fabric = FabricInstaller(paths: paths, installer: installer, downloader: downloader)
        let printer = ProgressPrinter()
        let profileId = try await fabric.install(minecraftVersion: mc, loaderVersion: option("--loader")) { phase, progress in
            printer.update(phase: phase, progress: progress)
        }
        print("\nFabric installed: \(profileId)")

    case "install-quilt":
        guard args.count >= 3 else {
            print("Error: Missing Minecraft version. Usage: launcher-cli install-quilt <mc> [--loader <version>]")
            exit(1)
        }
        let quiltMC = args[2]
        print("Installing Quilt for \(quiltMC)...")
        let quiltVersions = VersionInstaller(paths: paths, downloader: downloader)
        let quilt = QuiltInstaller(paths: paths, installer: quiltVersions, downloader: downloader)
        let quiltPrinter = ProgressPrinter()
        let quiltId = try await quilt.install(minecraftVersion: quiltMC, loaderVersion: option("--loader")) { phase, progress in
            quiltPrinter.update(phase: phase, progress: progress)
        }
        print("\nQuilt installed: \(quiltId)")

    case "install-forge":
        guard args.count >= 3 else {
            print("Error: Missing Minecraft version. Usage: launcher-cli install-forge <mc> [--neoforge] [--loader <version>] [--instance <name>]")
            exit(1)
        }
        let mc = args[2]
        let kind: ForgeLoaderKind = flag("--neoforge") ? .neoforge : .forge
        print("Installing \(kind.displayName) for \(mc)...")
        let launcher = GameLauncher(paths: paths, downloader: downloader)
        let instanceName = option("--instance") ?? "\(mc)-\(kind.rawValue)"
        var instance: Instance
        if let existing = try? launcher.store.load(name: instanceName) {
            instance = existing
        } else {
            instance = try launcher.store.create(name: instanceName, minecraftVersion: mc, loader: kind.rawValue, versionId: "")
        }
        let printer = ProgressPrinter()
        instance = try await launcher.ensureInstalled(instance, force: flag("--force")) { phase, progress in
            printer.update(phase: phase, progress: progress)
        }
        print("\n\(kind.displayName) installed: \(instance.versionId) (instance '\(instanceName)')")

    case "launch":
        guard args.count >= 3 else {
            print("Error: Missing Minecraft version. Usage: launcher-cli launch <mc> [--fabric] [--name <nick>] [--instance <name>] [--dry-run]")
            exit(1)
        }
        let mc = args[2]
        let useFabric = flag("--fabric")
        let instanceName = option("--instance") ?? (useFabric ? "\(mc)-fabric" : mc)
        let account = try OfflineAccount(name: option("--name") ?? "Player")
        let launcher = GameLauncher(paths: paths, downloader: downloader)
        let instance = try launcher.prepareInstance(name: instanceName, minecraftVersion: mc, fabric: useFabric)
        let printer = ProgressPrinter()
        let launchCommand = try await launcher.makeCommand(instance: instance, account: MinecraftAccount(offline: account)) { progress in
            printer.update(phase: "runtime", progress: progress)
        }

        if flag("--dry-run") {
            print(launchCommand.displayString)
        } else {
            print("Starting \(instance.versionId) as \(account.name) (instance '\(instance.name)')...")
            let process = try launcher.launch(launchCommand)
            print("Log: \(launchCommand.logURL.path)")
            process.waitUntilExit()
            print("Game exited with code \(process.terminationStatus)")
            exit(process.terminationStatus)
        }

    case "diagnose":
        guard args.count >= 3 else {
            print("Error: Missing instance name. Usage: launcher-cli diagnose <instance-name>")
            exit(1)
        }
        let instanceName = args[2]
        let store = InstanceStore(paths: paths)
        let instance = try store.load(name: instanceName)
        let instanceDir = store.instanceDirectory(for: instance.name)
        let gameDir = store.gameDirectory(for: instance.name)

        let logURL = instanceDir.appendingPathComponent("launcher.log")
        let logText = GameLog.tail(of: logURL)

        let crashFile = GameLog.latestCrashFile(gameDirectory: gameDir, since: .distantPast)
        let crashReportText = crashFile.flatMap { try? String(contentsOf: $0, encoding: .utf8) }

        let diagnosis = CrashAnalyzer.analyze(
            log: logText,
            crashReport: crashReportText,
            reportFile: crashFile,
            exitCode: 1
        )

        print("Kind: \(diagnosis.kind.rawValue)")
        if let culprit = diagnosis.culprit {
            print("Culprit: \(culprit)")
        }
        print("Detail: \(diagnosis.detail)")
        print("Excerpt:")
        print(diagnosis.excerpt)

    case "mods":
        guard args.count >= 3 else {
            print("Usage: launcher-cli mods <subcommand> [options]")
            exit(1)
        }
        let sub = args[2]
        let store = InstanceStore(paths: paths)
        let client = ModrinthClient(downloader: downloader)
        let manager = ModManager(store: store, client: client, downloader: downloader)

        switch sub {
        case "search":
            guard args.count >= 4 else {
                print("Error: Missing search query. Usage: launcher-cli mods search <query> [--mc <version>] [--loader fabric]")
                exit(1)
            }
            let query = args[3]
            let mc = option("--mc")
            let loader = option("--loader") ?? "fabric"
            let hits = try await client.search(query: query, gameVersion: mc, loader: loader)
            for hit in hits {
                print("\(hit.title) (\(hit.slug)) - \(hit.description)")
            }

        case "list":
            guard args.count >= 4 else {
                print("Error: Missing instance name. Usage: launcher-cli mods list <instance>")
                exit(1)
            }
            let instanceName = args[3]
            let mods = try manager.list(instance: instanceName)
            for mod in mods {
                let state = mod.isEnabled ? "[on]" : "[off]"
                var parts: [String] = [state, mod.displayTitle]
                if let versionNumber = mod.record?.versionNumber, !versionNumber.isEmpty {
                    parts.append(versionNumber)
                }
                if let record = mod.record, record.isDependency {
                    if let parent = record.installedFor, !parent.isEmpty {
                        parts.append("(dependency of \(parent))")
                    } else {
                        parts.append("(dependency)")
                    }
                }
                print(parts.joined(separator: " "))
            }

        case "install":
            guard args.count >= 5 else {
                print("Error: Missing arguments. Usage: launcher-cli mods install <instance> <slug-or-id>")
                exit(1)
            }
            let instanceName = args[3]
            let slugOrId = args[4]
            let result = try await manager.install(project: slugOrId, into: instanceName)
            for mod in result.installed {
                if mod.isDependency {
                    print("Installed \(mod.title) \(mod.versionNumber) (dependency)")
                } else {
                    print("Installed \(mod.title) \(mod.versionNumber)")
                }
            }
            for skip in result.skipped {
                print("Skipped: \(skip)")
            }
            for warning in result.warnings {
                print("Warning: \(warning)")
            }

        case "toggle":
            guard args.count >= 5 else {
                print("Error: Missing arguments. Usage: launcher-cli mods toggle <instance> <fileName>")
                exit(1)
            }
            let instanceName = args[3]
            let rawFileName = args[4]
            let cleanFileName = rawFileName.hasSuffix(".disabled")
                ? String(rawFileName.dropLast(".disabled".count))
                : rawFileName
            let modsDir = store.gameDirectory(for: instanceName).appendingPathComponent("mods", isDirectory: true)
            let enabledURL = modsDir.appendingPathComponent(cleanFileName)
            let disabledURL = modsDir.appendingPathComponent("\(cleanFileName).disabled")
            let fm = FileManager.default
            if fm.fileExists(atPath: enabledURL.path) {
                try manager.setEnabled(instance: instanceName, fileName: cleanFileName, enabled: false)
                print("Disabled \(cleanFileName)")
            } else if fm.fileExists(atPath: disabledURL.path) {
                try manager.setEnabled(instance: instanceName, fileName: cleanFileName, enabled: true)
                print("Enabled \(cleanFileName)")
            } else {
                throw ModManagerError.notFound(rawFileName)
            }

        case "remove":
            guard args.count >= 5 else {
                print("Error: Missing arguments. Usage: launcher-cli mods remove <instance> <fileName>")
                exit(1)
            }
            let instanceName = args[3]
            let rawFileName = args[4]
            let cleanFileName = rawFileName.hasSuffix(".disabled")
                ? String(rawFileName.dropLast(".disabled".count))
                : rawFileName
            try manager.remove(instance: instanceName, fileName: cleanFileName)
            print("Removed \(cleanFileName)")

        case "updates":
            guard args.count >= 4 else {
                print("Error: Missing instance name. Usage: launcher-cli mods updates <instance> [--apply]")
                exit(1)
            }
            let instanceName = args[3]
            let shouldApply = flag("--apply")
            let updates = try await manager.updates(instance: instanceName)
            if updates.isEmpty {
                print("No updates available.")
            } else {
                for update in updates {
                    print("\(update.record.title): \(update.record.versionNumber) -> \(update.newVersion.versionNumber)")
                    if shouldApply {
                        try await manager.apply(update: update, instance: instanceName)
                        print("Updated \(update.record.title) to \(update.newVersion.versionNumber)")
                    }
                }
            }

        case "upgrade-check":
            guard args.count >= 5 else {
                print("Error: Missing arguments. Usage: launcher-cli mods upgrade-check <instance> <gameVersion>")
                exit(1)
            }
            let instanceName = args[3]
            let targetGameVersion = args[4]
            let checks = try await manager.checkUpgrade(instance: instanceName, to: targetGameVersion)
            for check in checks {
                if let target = check.targetVersion {
                    print("\(check.record.title): compatible (\(target.versionNumber))")
                } else {
                    print("\(check.record.title): no compatible version found")
                }
            }

        default:
            print("Unknown mods subcommand: \(sub)")
            exit(1)
        }

    case "snapshots":
        guard args.count >= 3 else {
            print("Error: Missing instance name. Usage: launcher-cli snapshots <instance>")
            exit(1)
        }
        let instanceName = args[2]
        let store = InstanceStore(paths: paths)
        let launcher = GameLauncher(paths: paths, downloader: downloader)
        let client = ModrinthClient(downloader: downloader)
        let mods = ModManager(store: store, client: client, downloader: downloader)
        let upgrader = InstanceUpgrader(store: store, launcher: launcher, mods: mods)
        let list = try upgrader.listSnapshots(instance: instanceName)
        for s in list {
            let mb = String(format: "%.1f MB", Double(s.sizeBytes) / 1_048_576.0)
            let v = s.gameVersion ?? "unknown"
            print("\(s.id) \(v) \(mb) \(s.reason)")
        }

    case "snapshot":
        guard args.count >= 3 else {
            print("Error: Missing instance name. Usage: launcher-cli snapshot <instance> [reason]")
            exit(1)
        }
        let instanceName = args[2]
        let reason = args.count >= 4 ? args[3] : "manual"
        let store = InstanceStore(paths: paths)
        let launcher = GameLauncher(paths: paths, downloader: downloader)
        let client = ModrinthClient(downloader: downloader)
        let mods = ModManager(store: store, client: client, downloader: downloader)
        let upgrader = InstanceUpgrader(store: store, launcher: launcher, mods: mods)
        let s = try upgrader.createSnapshot(instance: instanceName, reason: reason)
        print("Created snapshot: \(s.id)")

    case "upgrade":
        guard args.count >= 4 else {
            print("Error: Missing arguments. Usage: launcher-cli upgrade <instance> <gameVersion>")
            exit(1)
        }
        let instanceName = args[2]
        let gameVersion = args[3]
        let store = InstanceStore(paths: paths)
        let launcher = GameLauncher(paths: paths, downloader: downloader)
        let client = ModrinthClient(downloader: downloader)
        let mods = ModManager(store: store, client: client, downloader: downloader)
        let upgrader = InstanceUpgrader(store: store, launcher: launcher, mods: mods)
        let report = try await upgrader.upgrade(instance: instanceName, to: gameVersion) { line in
            print(line)
        }
        print("Snapshot: \(report.snapshot.id)")
        print("Updated (\(report.updated.count)): \(report.updated.joined(separator: ", "))")
        print("Disabled (\(report.disabled.count)): \(report.disabled.joined(separator: ", "))")
        print("Failed (\(report.failed.count)): \(report.failed.joined(separator: ", "))")
        print("New version: \(report.newVersionId)")

    case "restore":
        guard args.count >= 4 else {
            print("Error: Missing arguments. Usage: launcher-cli restore <instance> <snapshot-id>")
            exit(1)
        }
        let instanceName = args[2]
        let snapshotId = args[3]
        let store = InstanceStore(paths: paths)
        let launcher = GameLauncher(paths: paths, downloader: downloader)
        let client = ModrinthClient(downloader: downloader)
        let mods = ModManager(store: store, client: client, downloader: downloader)
        let upgrader = InstanceUpgrader(store: store, launcher: launcher, mods: mods)
        try upgrader.restore(instance: instanceName, snapshot: snapshotId)
        print("Restored \(instanceName) from \(snapshotId)")

    case "optimize":
        guard args.count >= 3 else {
            print("Error: Missing instance name. Usage: launcher-cli optimize <instance> --preset <maxFPS_PvP|balancedLoD|shadersVisual|heavyModpack> [--shaders] [--lod] [--framegen] [--os mac|windows] [--apply] [--optional]")
            exit(1)
        }
        let instanceName = args[2]
        guard let presetString = option("--preset"),
              let preset = OptimizationPreset(string: presetString) else {
            print("Error: Missing or invalid --preset. Options: maxFPS_PvP, balancedLoD, shadersVisual, heavyModpack")
            exit(1)
        }
        let store = InstanceStore(paths: paths)
        let instance = try store.load(name: instanceName)

        var targetOS = OptimizationOS.current
        if let osArg = option("--os")?.lowercased() {
            if osArg == "mac" || osArg == "macos" {
                targetOS = .macOS
            } else if osArg == "windows" || osArg == "win" {
                targetOS = .windows
            }
        }

        let context = OptimizationRuleEngine.context(
            for: instance,
            preset: preset,
            enableShaders: flag("--shaders"),
            enableLoD: flag("--lod"),
            enableFrameGen: flag("--framegen"),
            os: targetOS
        )
        let plan = OptimizationRuleEngine.plan(for: context)

        print("Optimization Plan for '\(instance.name)' (\(context.mcVersion), loader: \(context.loader.rawValue), os: \(context.os.rawValue)):")
        print("Preset: \(context.preset.rawValue)")
        print("\nSlugs to install (\(plan.slugs.count)):")
        for slug in plan.slugs {
            print("  - \(slug)")
        }

        if !plan.optionalSlugs.isEmpty {
            print("\nOptional slugs (\(plan.optionalSlugs.count)):")
            for slug in plan.optionalSlugs {
                print("  - \(slug)")
            }
        }

        if !plan.blocked.isEmpty {
            print("\nBlocked mods (\(plan.blocked.count)):")
            for b in plan.blocked {
                print("  - \(b.slug): \(b.reason)")
            }
        }

        if !plan.notices.isEmpty {
            print("\nNotices (\(plan.notices.count)):")
            for n in plan.notices {
                print("  [\(n.kind.rawValue.uppercased())] \(n.message)")
            }
        }

        if flag("--apply") {
            print("\nApplying optimization plan...")
            let client = ModrinthClient(downloader: downloader)
            let manager = ModManager(store: store, client: client, downloader: downloader)
            let installer = OptimizationInstaller(modManager: manager)
            let report = try await installer.apply(plan, to: instanceName, includeOptional: flag("--optional"))

            print("\nOptimization Report:")
            print("Installed (\(report.installed.count)): \(report.installed.joined(separator: ", "))")
            if !report.alreadyInstalled.isEmpty {
                print("Already installed (\(report.alreadyInstalled.count)): \(report.alreadyInstalled.joined(separator: ", "))")
            }
            if !report.skippedNoVersion.isEmpty {
                print("Skipped (no compatible version) (\(report.skippedNoVersion.count)): \(report.skippedNoVersion.joined(separator: ", "))")
            }
            if !report.failed.isEmpty {
                print("Failed (\(report.failed.count)):")
                for f in report.failed {
                    print("  - \(f.slug): \(f.message)")
                }
            }
            if !report.warnings.isEmpty {
                print("Warnings (\(report.warnings.count)):")
                for w in report.warnings {
                    print("  - \(w)")
                }
            }
        } else {
            print("\nDry run only. Use --apply to install mods.")
        }

    case "mrpack":
        guard args.count >= 3 else {
            print("Usage: launcher-cli mrpack <subcommand> [options]")
            exit(1)
        }
        let sub = args[2]
        switch sub {
        case "export":
            guard args.count >= 5 else {
                print("Error: Missing arguments. Usage: launcher-cli mrpack export <instance> <file.mrpack> [--version 1.0.0] [--no-shaders] [--no-config]")
                exit(1)
            }
            let instanceName = args[3]
            let destPath = args[4]
            let destination = URL(fileURLWithPath: destPath)
            let store = InstanceStore(paths: paths)
            let client = ModrinthClient(downloader: downloader)
            let manager = ModpackManager(store: store, client: client, downloader: downloader)

            let versionLabel = option("--version") ?? "1.0.0"
            let options = MrpackExportOptions(
                includeConfig: !flag("--no-config"),
                includeShaders: !flag("--no-shaders"),
                versionLabel: versionLabel
            )

            let report = try await manager.export(instance: instanceName, to: destination, options: options)
            for warning in report.warnings {
                print("Warning: \(warning)")
            }
            print("Exported \(report.modsLinked) linked mods, \(report.modsBundled) bundled, \(report.overrideFiles) override files -> \(report.archive.path)")

        case "inspect":
            guard args.count >= 4 else {
                print("Error: Missing archive path. Usage: launcher-cli mrpack inspect <file.mrpack>")
                exit(1)
            }
            let archivePath = args[3]
            let archiveURL = URL(fileURLWithPath: archivePath)
            let store = InstanceStore(paths: paths)
            let client = ModrinthClient(downloader: downloader)
            let manager = ModpackManager(store: store, client: client, downloader: downloader)

            let summary = try manager.inspect(archiveURL)
            print("Name: \(summary.name)")
            print("Version: \(summary.versionLabel)")
            if let s = summary.summary, !s.isEmpty {
                print("Summary: \(s)")
            }
            print("Minecraft: \(summary.minecraftVersion)")
            if let loaderVersion = summary.loaderVersion, !loaderVersion.isEmpty {
                print("Loader: \(summary.loader) (\(loaderVersion))")
            } else {
                print("Loader: \(summary.loader)")
            }
            let mb = Double(summary.downloadBytes) / 1_048_576.0
            print("Files: \(summary.fileCount) (\(String(format: "%.1f MB", mb)))")
            print("Overrides: \(summary.overrideFileCount)")

        case "import":
            guard args.count >= 4 else {
                print("Error: Missing archive path. Usage: launcher-cli mrpack import <file.mrpack> [--name \"My pack\"] [--group Mods] [--memory 6144]")
                exit(1)
            }
            let archivePath = args[3]
            let archiveURL = URL(fileURLWithPath: archivePath)
            let store = InstanceStore(paths: paths)
            let client = ModrinthClient(downloader: downloader)
            let manager = ModpackManager(store: store, client: client, downloader: downloader)

            let customName = option("--name")
            let group = option("--group")
            let memoryMB = option("--memory").flatMap { Int($0) } ?? 4096

            final class ProgressPrinter: @unchecked Sendable {
                private let lock = NSLock()
                private var lastPhase = ""
                private var lastPercent = -10

                func report(phase: String, fraction: Double) {
                    let percent = Int(fraction * 100)
                    let decile = (percent / 10) * 10
                    lock.lock()
                    defer { lock.unlock() }
                    if phase != lastPhase {
                        lastPhase = phase
                        lastPercent = decile
                        print("[\(phase)]")
                    } else if phase == "Downloading mods" && decile >= lastPercent + 10 {
                        lastPercent = decile
                        print("[\(phase)] \(percent)%")
                    }
                }
            }
            let printer = ProgressPrinter()
            let report = try await manager.importPack(
                from: archiveURL,
                name: customName,
                group: group,
                memoryMB: memoryMB
            ) { phase, fraction in
                printer.report(phase: phase, fraction: fraction)
            }

            for f in report.failed {
                print("Failed: \(f)")
            }
            for w in report.warnings {
                print("Warning: \(w)")
            }
            print("Imported \(report.filesInstalled) files, \(report.overrideFiles) overrides -> \(report.instanceName)")

        default:
            print("Unknown mrpack subcommand: \(sub)")
            exit(1)
        }

    case "ai-plan":
        guard args.count >= 3 else {
            print("Error: Missing description. Usage: launcher-cli ai-plan \"description\" [--version 1.21.4] [--provider claude|gemini] [--key-env VAR] [--answer file.json] [--install <instance>]")
            exit(1)
        }
        let description = args[2]
        let gameVersion = option("--version") ?? "1.21.4"
        let client: any AIChatClient
        if let answerPath = option("--answer") {
            client = SavedAnswerClient(text: try String(contentsOfFile: answerPath, encoding: .utf8))
        } else {
            let kind = AIProviderKind(rawValue: option("--provider") ?? "claude") ?? .claude
            let envName = option("--key-env") ?? (kind == .claude ? "ANTHROPIC_API_KEY" : "GEMINI_API_KEY")
            client = try makeAIClient(kind: kind, apiKey: ProcessInfo.processInfo.environment[envName] ?? "", model: option("--model"))
        }
        let plan = try await ModpackPlanner(client: client).plan(description: description, minecraftVersion: gameVersion)
        print("\(plan.name) (Minecraft \(plan.minecraftVersion)): \(plan.summary)")
        for mod in plan.mods {
            print("  \(mod.title) [\(mod.slug)] - \(mod.reason)")
        }
        for name in plan.unresolved {
            print("  not found: \(name)")
        }
        if let target = option("--install") {
            let report = await ModpackBuilder(mods: ModManager(store: InstanceStore(paths: paths))).install(plan.mods, into: target) { title, done, total in
                print("[\(done + 1)/\(total)] \(title)")
            }
            print("Installed \(report.installed.count) mods + \(report.dependencies) dependencies into \(target)")
            for line in report.skipped {
                print("Skipped: \(line)")
            }
        }

    case "catalog":
        guard args.count >= 3 else {
            print("Usage: launcher-cli catalog <search|install|modpack> [options]")
            exit(1)
        }
        let sub = args[2]
        let store = InstanceStore(paths: paths)
        let client = ModrinthClient(downloader: downloader)
        let installer = ContentInstaller(store: store, client: client, downloader: downloader)

        switch sub {
        case "search":
            guard args.count >= 5 else {
                print("Usage: launcher-cli catalog search <mod|modpack|shader|resourcepack> <query> [--game-version V]")
                exit(1)
            }
            guard let kind = ContentKind(rawValue: args[3].lowercased()) else {
                print("Error: Invalid kind '\(args[3])'. Allowed: mod, modpack, shader, resourcepack")
                exit(1)
            }
            let query = args[4]
            let gameVersion = option("--game-version")
            let hits = try await client.search(
                query: query,
                projectType: kind.projectType,
                gameVersion: gameVersion
            )
            for hit in hits {
                print("\(hit.title) (\(hit.slug)) - \(hit.description)")
            }

        case "install":
            guard args.count >= 6 else {
                print("Usage: launcher-cli catalog install <kind> <slug> <instance>")
                exit(1)
            }
            guard let kind = ContentKind(rawValue: args[3].lowercased()) else {
                print("Error: Invalid kind '\(args[3])'. Allowed: mod, modpack, shader, resourcepack")
                exit(1)
            }
            let slug = args[4]
            let instanceName = args[5]
            let result = try await installer.install(project: slug, kind: kind, into: instanceName)
            switch result {
            case .installed(let title, let fileName):
                print("Installed \(title) (\(fileName))")
            case .mod(let modResult):
                for mod in modResult.installed {
                    if mod.isDependency {
                        print("Installed \(mod.title) \(mod.versionNumber) (dependency)")
                    } else {
                        print("Installed \(mod.title) \(mod.versionNumber)")
                    }
                }
                for skip in modResult.skipped {
                    print("Skipped: \(skip)")
                }
                for warning in modResult.warnings {
                    print("Warning: \(warning)")
                }
            case .skipped(let reason):
                print("Skipped: \(reason)")
            case .needsShaderLoader:
                print("Requirement: needsShaderLoader")
            case .unsupported(let reason):
                print("Unsupported: \(reason)")
            }

        case "modpack":
            guard args.count >= 4 else {
                print("Usage: launcher-cli catalog modpack <slug> [name]")
                exit(1)
            }
            let slug = args[3]
            let customName = args.count >= 5 && !args[4].hasPrefix("-") ? args[4] : nil
            let report = try await installer.createInstance(fromModpack: slug, name: customName)
            if let loaderVersion = report.loaderVersion, !loaderVersion.isEmpty {
                print("Created instance '\(report.instanceName)' (Minecraft \(report.minecraftVersion), loader \(report.loader) \(loaderVersion))")
            } else {
                print("Created instance '\(report.instanceName)' (Minecraft \(report.minecraftVersion), loader \(report.loader))")
            }
            print("Installed \(report.filesInstalled) files")
            for warning in report.warnings {
                print("Warning: \(warning)")
            }

        default:
            print("Unknown catalog subcommand: \(sub)")
            exit(1)
        }

    case "update":
        guard args.count >= 3, args[2] == "check" else {
            print("Usage: launcher-cli update check")
            exit(1)
        }
        if let update = try await UpdateChecker.checkReportingErrors(currentVersion: LauncherInfo.version) {
            print("update \(update.version) available \(update.assetURL.absoluteString)")
        } else {
            print("up to date")
        }

    default:
        print("Unknown command: \(command)")
        exit(1)
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
