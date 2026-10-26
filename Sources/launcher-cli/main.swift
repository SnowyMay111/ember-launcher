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

    default:
        print("Unknown command: \(command)")
        exit(1)
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
