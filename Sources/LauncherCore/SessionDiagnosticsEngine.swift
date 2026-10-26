import Foundation

public struct SkippedFix: Codable, Sendable, Equatable {
    public var action: AutoFixAction
    public var reason: String

    public init(action: AutoFixAction, reason: String) {
        self.action = action
        self.reason = reason
    }
}

public struct AutoFixReport: Sendable {
    public var applied: [AutoFixAction]
    public var skipped: [SkippedFix]
    public var installReport: OptimizationApplyReport?
    public var backupPath: String?

    public init(
        applied: [AutoFixAction] = [],
        skipped: [SkippedFix] = [],
        installReport: OptimizationApplyReport? = nil,
        backupPath: String? = nil
    ) {
        self.applied = applied
        self.skipped = skipped
        self.installReport = installReport
        self.backupPath = backupPath
    }
}

public actor SessionDiagnosticsEngine {
    private let store: InstanceStore
    private let installer: OptimizationInstaller

    public init(store: InstanceStore, installer: OptimizationInstaller) {
        self.store = store
        self.installer = installer
    }

    public func analyze(
        instance: Instance,
        playtime: TimeInterval,
        javaExecutable: URL?
    ) -> SessionHealthReport {
        var analyzer = FreezeAnalyzer()
        let instanceDir = store.instanceDirectory(for: instance.name)
        let logsDir = instanceDir.appendingPathComponent("logs", isDirectory: true)

        let rotatedLog = logsDir.appendingPathComponent("gc_telemetry.log.0")
        if let rotatedText = try? String(contentsOf: rotatedLog, encoding: .utf8) {
            analyzer.ingestGC(lines: rotatedText.components(separatedBy: "\n"))
        }

        let currentGCLog = logsDir.appendingPathComponent("gc_telemetry.log")
        if let currentText = try? String(contentsOf: currentGCLog, encoding: .utf8) {
            analyzer.ingestGC(lines: currentText.components(separatedBy: "\n"))
        }

        let gameLogURL = instanceDir.appendingPathComponent("launcher.log")
        let gameTail = GameLog.tail(of: gameLogURL, maxBytes: 500_000)
        if !gameTail.isEmpty {
            analyzer.ingestGameLog(lines: gameTail.components(separatedBy: "\n"))
        }

        let arch: JavaArchitecture
        if let javaExecutable {
            arch = FreezeAnalyzer.javaArchitecture(of: javaExecutable)
        } else {
            arch = .unknown
        }

        let gameDir = store.gameDirectory(for: instance.name)
        let modsDir = gameDir.appendingPathComponent("mods", isDirectory: true)
        let optionsFile = gameDir.appendingPathComponent("options.txt")
        let voxyIssue = FreezeAnalyzer.voxyWithHighRenderDistance(modsDirectory: modsDir, optionsFile: optionsFile)

        let javaMajor = javaExecutable.flatMap { Self.detectJavaMajor(executable: $0) }
        let stats = analyzer.snapshot()
        let report = SessionHealthReport.make(
            stats: stats,
            instance: instance,
            playtime: playtime,
            architecture: arch,
            voxyIssue: voxyIssue,
            javaMajor: javaMajor
        )

        let reportURL = instanceDir.appendingPathComponent("last_session_health.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(report) {
            try? data.write(to: reportURL, options: .atomic)
        }

        return report
    }

    public func loadLastReport(instanceName: String) -> SessionHealthReport? {
        let instanceDir = store.instanceDirectory(for: instanceName)
        let reportURL = instanceDir.appendingPathComponent("last_session_health.json")
        guard let data = try? Data(contentsOf: reportURL) else { return nil }
        return try? JSONDecoder().decode(SessionHealthReport.self, from: data)
    }

    public nonisolated func monitor(
        instance: Instance,
        javaExecutable: URL?,
        interval: TimeInterval = 5,
        isRunning: @escaping @Sendable () -> Bool
    ) -> AsyncStream<SessionHealthReport> {
        AsyncStream { continuation in
            let task = Task {
                let startTime = Date()
                let instanceDir = self.store.instanceDirectory(for: instance.name)
                let logsDir = instanceDir.appendingPathComponent("logs", isDirectory: true)
                let gcLogURL = logsDir.appendingPathComponent("gc_telemetry.log")
                let gameLogURL = instanceDir.appendingPathComponent("launcher.log")

                var gcOffset: UInt64 = 0
                var gameOffset: UInt64 = 0
                var analyzer = FreezeAnalyzer()

                let arch: JavaArchitecture
                if let javaExecutable {
                    arch = FreezeAnalyzer.javaArchitecture(of: javaExecutable)
                } else {
                    arch = .unknown
                }

                let gameDir = self.store.gameDirectory(for: instance.name)
                let modsDir = gameDir.appendingPathComponent("mods", isDirectory: true)
                let optionsFile = gameDir.appendingPathComponent("options.txt")
                let javaMajor = javaExecutable.flatMap { SessionDiagnosticsEngine.detectJavaMajor(executable: $0) }

                while !Task.isCancelled && isRunning() {
                    let newGCLines = FreezeAnalyzer.readNewLines(of: gcLogURL, fromOffset: &gcOffset)
                    let newGameLines = FreezeAnalyzer.readNewLines(of: gameLogURL, fromOffset: &gameOffset)

                    if !newGCLines.isEmpty || !newGameLines.isEmpty {
                        analyzer.ingestGC(lines: newGCLines)
                        analyzer.ingestGameLog(lines: newGameLines)

                        let playtime = Date().timeIntervalSince(startTime)
                        let voxyIssue = FreezeAnalyzer.voxyWithHighRenderDistance(modsDirectory: modsDir, optionsFile: optionsFile)
                        let report = SessionHealthReport.make(
                            stats: analyzer.snapshot(),
                            instance: instance,
                            playtime: playtime,
                            architecture: arch,
                            voxyIssue: voxyIssue,
                            javaMajor: javaMajor
                        )
                        continuation.yield(report)
                    }

                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }

                let finalPlaytime = Date().timeIntervalSince(startTime)
                let finalVoxy = FreezeAnalyzer.voxyWithHighRenderDistance(modsDirectory: modsDir, optionsFile: optionsFile)
                let finalReport = SessionHealthReport.make(
                    stats: analyzer.snapshot(),
                    instance: instance,
                    playtime: finalPlaytime,
                    architecture: arch,
                    voxyIssue: finalVoxy,
                    javaMajor: javaMajor
                )
                continuation.yield(finalReport)
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func applyFixes(
        _ fixes: [AutoFixAction],
        for instance: Instance,
        progress: (@Sendable (Double, String) -> Void)? = nil
    ) async throws -> AutoFixReport {
        var currentInstance = try store.load(name: instance.name)
        let instanceDir = store.instanceDirectory(for: currentInstance.name)
        let originalJSON = store.instanceJSON(for: currentInstance.name)

        // Create backup
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let backupFileName = "instance.json.backup-\(formatter.string(from: Date()))"
        let backupURL = instanceDir.appendingPathComponent(backupFileName)
        try? FileManager.default.copyItem(at: originalJSON, to: backupURL)

        var applied: [AutoFixAction] = []
        var skipped: [SkippedFix] = []
        var modSlugsToInstall: [String] = []

        let totalSteps = Double(max(fixes.count, 1))
        var currentStep = 0.0

        for fix in fixes {
            currentStep += 1.0
            let stepFraction = currentStep / totalSteps

            switch fix {
            case .enableZeroStutterZGC:
                progress?(stepFraction, "Enabling Zero-Stutter ZGC")
                currentInstance.gcProfile = .zeroStutterZGC
                do {
                    try store.save(currentInstance)
                    applied.append(fix)
                } catch {
                    skipped.append(SkippedFix(action: fix, reason: error.localizedDescription))
                }

            case .adjustRAMAllocation(let mb):
                progress?(stepFraction, "Adjusting RAM allocation to \(mb) MB")
                currentInstance.memoryMB = mb
                do {
                    try store.save(currentInstance)
                    applied.append(fix)
                } catch {
                    skipped.append(SkippedFix(action: fix, reason: error.localizedDescription))
                }

            case .fixRenderDistanceAndLockFPS:
                progress?(stepFraction, "Configuring display refresh rate cap and render distance")
                currentInstance.lockFpsToMonitor = true
                currentInstance.capRenderDistance = true
                do {
                    try store.save(currentInstance)
                    applied.append(fix)
                } catch {
                    skipped.append(SkippedFix(action: fix, reason: error.localizedDescription))
                }

            case .installMemoryMods:
                if currentInstance.loader.lowercased() != "fabric" {
                    skipped.append(SkippedFix(action: fix, reason: "Memory optimization mods only support Fabric loaders."))
                } else {
                    modSlugsToInstall.append(contentsOf: ["ferrite-core", "modernfix"])
                    applied.append(fix)
                }

            case .installEntityAndChunkMods:
                if currentInstance.loader.lowercased() != "fabric" {
                    skipped.append(SkippedFix(action: fix, reason: "Tick drop optimization mods only support Fabric loaders."))
                } else {
                    modSlugsToInstall.append(contentsOf: ["lithium", "entityculling", "async"])
                    applied.append(fix)
                }
            }
        }

        var installReport: OptimizationApplyReport? = nil
        if !modSlugsToInstall.isEmpty {
            progress?(0.9, "Installing optimization mods")
            let plan = OptimizationPlan(slugs: modSlugsToInstall)
            do {
                installReport = try await installer.apply(plan, to: currentInstance.name)
            } catch {
                skipped.append(SkippedFix(
                    action: .installMemoryMods,
                    reason: "Failed to install mods: \(error.localizedDescription)"
                ))
            }
        }

        progress?(1.0, "Optimizations complete")
        return AutoFixReport(
            applied: applied,
            skipped: skipped,
            installReport: installReport,
            backupPath: backupURL.path
        )
    }

    private static func detectJavaMajor(executable: URL) -> Int? {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["-version"]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)

        guard let quoteStart = output.firstIndex(of: "\"") else { return nil }
        let rest = output[output.index(after: quoteStart)...]
        guard let quoteEnd = rest.firstIndex(of: "\"") else { return nil }
        let versionString = String(rest[..<quoteEnd])

        let parts = versionString.split(separator: ".")
        if let first = parts.first, let major = Int(first) {
            if major == 1, parts.count > 1, let second = Int(parts[1]) {
                return second
            }
            return major
        }
        return nil
    }
}
