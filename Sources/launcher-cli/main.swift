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
        print("Latest release: \(manifest.latest.release)")
        print("Latest snapshot: \(manifest.latest.snapshot)")
        print("Recent releases:")
        let releases = manifest.versions.filter { $0.type == "release" }.prefix(10)
        for version in releases {
            print("  - \(version.id)")
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

        let component = versionJSON.javaVersion?.component ?? "java-runtime-delta"
        print("Ensuring Java runtime (\(component))...")
        let runtimeManager = JavaRuntimeManager(paths: paths, downloader: downloader)
        let javaURL = try await runtimeManager.ensureRuntime(component: component) { progress in
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
        let launchCommand = try await launcher.makeCommand(instance: instance, account: account) { progress in
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

    default:
        print("Unknown command: \(command)")
        exit(1)
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
