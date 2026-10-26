import Foundation

public enum DiagnosticSeverity: String, Codable, Sendable {
    case info
    case warning
    case critical
}

public struct DiagnosticIssue: Codable, Sendable, Equatable {
    public var code: String
    public var severity: DiagnosticSeverity
    public var message: String
    public var values: [String: String]

    public init(
        code: String,
        severity: DiagnosticSeverity,
        message: String,
        values: [String: String] = [:]
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.values = values
    }
}

public enum AutoFixAction: Codable, Hashable, Sendable {
    case enableZeroStutterZGC
    case installMemoryMods
    case adjustRAMAllocation(recommendedMB: Int)
    case installEntityAndChunkMods
    case fixRenderDistanceAndLockFPS

    private enum CodingKeys: String, CodingKey {
        case type
        case recommendedMB
    }

    private enum ActionType: String, Codable {
        case enableZeroStutterZGC
        case installMemoryMods
        case adjustRAMAllocation
        case installEntityAndChunkMods
        case fixRenderDistanceAndLockFPS
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ActionType.self, forKey: .type)
        switch type {
        case .enableZeroStutterZGC:
            self = .enableZeroStutterZGC
        case .installMemoryMods:
            self = .installMemoryMods
        case .adjustRAMAllocation:
            let mb = try container.decode(Int.self, forKey: .recommendedMB)
            self = .adjustRAMAllocation(recommendedMB: mb)
        case .installEntityAndChunkMods:
            self = .installEntityAndChunkMods
        case .fixRenderDistanceAndLockFPS:
            self = .fixRenderDistanceAndLockFPS
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .enableZeroStutterZGC:
            try container.encode(ActionType.enableZeroStutterZGC, forKey: .type)
        case .installMemoryMods:
            try container.encode(ActionType.installMemoryMods, forKey: .type)
        case .adjustRAMAllocation(let mb):
            try container.encode(ActionType.adjustRAMAllocation, forKey: .type)
            try container.encode(mb, forKey: .recommendedMB)
        case .installEntityAndChunkMods:
            try container.encode(ActionType.installEntityAndChunkMods, forKey: .type)
        case .fixRenderDistanceAndLockFPS:
            try container.encode(ActionType.fixRenderDistanceAndLockFPS, forKey: .type)
        }
    }
}

/// A comprehensive summary of launcher telemetry and gameplay health during a session.
///
/// Smoothness Score Calculation:
/// Penalty per minute of post-warmup playtime:
/// `penaltyPerMinute = (minor * 1.0 + critical * 6.0 + tickDrops * 0.5) / minutes`
/// `score = clamp(100 - round(penaltyPerMinute * 10), 0...100)`
/// With no events the score is 100; exactly one critical freeze per minute yields <= 40.
public struct SessionHealthReport: Codable, Sendable, Equatable {
    public var smoothnessScore: Int
    public var totalPlaytimeSeconds: TimeInterval
    public var gcMicroFreezesCount: Int
    public var maxGcPauseMs: Double
    public var serverTickDropsCount: Int
    public var maxTickBehindMs: Int
    public var criticalFreezeCount: Int
    public var minorStutterCount: Int
    public var isConclusive: Bool
    public var allocatedMemoryMB: Int
    public var gcProfile: String
    public var javaArchitecture: JavaArchitecture
    public var detectedIssues: [DiagnosticIssue]
    public var oneClickFixes: [AutoFixAction]
    public var generatedAt: Date

    public init(
        smoothnessScore: Int,
        totalPlaytimeSeconds: TimeInterval,
        gcMicroFreezesCount: Int,
        maxGcPauseMs: Double,
        serverTickDropsCount: Int,
        maxTickBehindMs: Int,
        criticalFreezeCount: Int,
        minorStutterCount: Int,
        isConclusive: Bool,
        allocatedMemoryMB: Int,
        gcProfile: String,
        javaArchitecture: JavaArchitecture,
        detectedIssues: [DiagnosticIssue],
        oneClickFixes: [AutoFixAction],
        generatedAt: Date = Date()
    ) {
        self.smoothnessScore = smoothnessScore
        self.totalPlaytimeSeconds = totalPlaytimeSeconds
        self.gcMicroFreezesCount = gcMicroFreezesCount
        self.maxGcPauseMs = maxGcPauseMs
        self.serverTickDropsCount = serverTickDropsCount
        self.maxTickBehindMs = maxTickBehindMs
        self.criticalFreezeCount = criticalFreezeCount
        self.minorStutterCount = minorStutterCount
        self.isConclusive = isConclusive
        self.allocatedMemoryMB = allocatedMemoryMB
        self.gcProfile = gcProfile
        self.javaArchitecture = javaArchitecture
        self.detectedIssues = detectedIssues
        self.oneClickFixes = oneClickFixes
        self.generatedAt = generatedAt
    }

    public static func make(
        stats: FreezeStats,
        instance: Instance,
        playtime: TimeInterval,
        architecture: JavaArchitecture,
        voxyIssue: Bool,
        javaMajor: Int?
    ) -> SessionHealthReport {
        let postWarmupPlaytime = max(0.0, playtime - FreezeAnalyzer.warmupSeconds)
        let isConclusive = postWarmupPlaytime >= 120.0

        var issues: [DiagnosticIssue] = []
        var fixes: [AutoFixAction] = []

        let rec = JVMArgumentsBuilder.memoryRecommendation(isModded: instance.loader.lowercased() != "vanilla")
        let resolvedGC = JVMArgumentsBuilder.resolveProfile(instance.gcProfile, javaMajor: javaMajor)
        let gcProfileName: String
        switch resolvedGC {
        case .zeroStutterZGC:
            gcProfileName = "ZGC"
        case .tunedG1GC:
            gcProfileName = "G1"
        case .auto:
            gcProfileName = "Auto"
        case .none:
            gcProfileName = "JVM Default"
        }

        var score = 100
        if isConclusive {
            let minutes = postWarmupPlaytime / 60.0
            if minutes > 0 {
                let penaltyPerMinute = (Double(stats.minorStutterCount) * 1.0
                    + Double(stats.criticalFreezeCount) * 6.0
                    + Double(stats.tickDropCount) * 0.5) / minutes
                let deduction = Int((penaltyPerMinute * 10.0).rounded())
                score = min(max(100 - deduction, 0), 100)
            }

            if stats.criticalFreezeCount > 0 {
                issues.append(DiagnosticIssue(
                    code: "gc_critical",
                    severity: .critical,
                    message: "The Java garbage collector paused the game for up to \(Int(stats.maxPauseMs)) ms while cleaning memory.",
                    values: ["maxPauseMs": String(Int(stats.maxPauseMs)), "count": String(stats.criticalFreezeCount)]
                ))
            } else if stats.minorStutterCount > 0 {
                issues.append(DiagnosticIssue(
                    code: "gc_minor",
                    severity: .warning,
                    message: "Minor GC micro-stutters detected (\(stats.minorStutterCount) times, up to \(Int(stats.maxPauseMs)) ms).",
                    values: ["maxPauseMs": String(Int(stats.maxPauseMs)), "count": String(stats.minorStutterCount)]
                ))
            }

            if stats.outOfMemoryCount > 0 {
                issues.append(DiagnosticIssue(
                    code: "out_of_memory",
                    severity: .critical,
                    message: "The game ran completely out of memory (OutOfMemoryError).",
                    values: ["count": String(stats.outOfMemoryCount)]
                ))
            }

            if stats.allocationStallCount > 0 {
                issues.append(DiagnosticIssue(
                    code: "allocation_stall",
                    severity: .critical,
                    message: "Memory allocation stalled waiting for memory to be freed (\(stats.allocationStallCount) stalls).",
                    values: ["count": String(stats.allocationStallCount)]
                ))
            }

            let hasMemoryPressure = stats.averageHeapOccupancyRatio > 0.85
                || stats.fullGCCount > 0
                || stats.outOfMemoryCount > 0
                || (stats.allocationStallCount > 0 && instance.memoryMB <= rec.recommendedRangeMB.upperBound)

            if hasMemoryPressure {
                issues.append(DiagnosticIssue(
                    code: "memory_pressure",
                    severity: stats.outOfMemoryCount > 0 ? .critical : .warning,
                    message: "High memory pressure observed; heap utilization regularly exceeded 85%.",
                    values: [
                        "avgRatio": String(format: "%.0f%%", stats.averageHeapOccupancyRatio * 100),
                        "fullGCCount": String(stats.fullGCCount)
                    ]
                ))

                let maxSafe = min(rec.recommendedRangeMB.upperBound, rec.systemMemoryMB - 2048)
                if instance.memoryMB < maxSafe {
                    fixes.append(.adjustRAMAllocation(recommendedMB: maxSafe))
                }
                fixes.append(.installMemoryMods)
            }

            if stats.maxPauseMs > 50.0 && instance.memoryMB > rec.overAllocationWarningThresholdMB {
                let targetMB = rec.recommendedRangeMB.upperBound
                if instance.memoryMB != targetMB {
                    fixes.append(.adjustRAMAllocation(recommendedMB: targetMB))
                }
            }

            if (stats.criticalFreezeCount > 0 || stats.minorStutterCount > 0)
                && (instance.gcProfile == .tunedG1GC || instance.gcProfile == .none || instance.gcProfile == .auto)
                && (javaMajor ?? 0) >= 21
                && resolvedGC != .zeroStutterZGC {
                fixes.append(.enableZeroStutterZGC)
            }

            if stats.tickDropCount >= 3 {
                issues.append(DiagnosticIssue(
                    code: "tick_drops",
                    severity: .warning,
                    message: "Server tick drops detected (\(stats.tickDropCount) times, up to \(stats.maxTickBehindMs) ms behind).",
                    values: ["tickDropCount": String(stats.tickDropCount), "maxTickBehindMs": String(stats.maxTickBehindMs)]
                ))
                fixes.append(.installEntityAndChunkMods)
            }
        }

        if architecture == .rosetta {
            issues.append(DiagnosticIssue(
                code: "rosetta_java",
                severity: .critical,
                message: "Minecraft is running under Rosetta translation instead of native Apple Silicon ARM64.",
                values: [:]
            ))
        }

        if voxyIssue {
            issues.append(DiagnosticIssue(
                code: "voxy_render_distance",
                severity: .warning,
                message: "Voxy is enabled with high render distance which causes heavy stuttering.",
                values: [:]
            ))
            fixes.append(.fixRenderDistanceAndLockFPS)
        }

        let hasAnyFreeze = stats.criticalFreezeCount > 0
            || stats.minorStutterCount > 0
            || stats.allocationStallCount > 0

        if isConclusive && hasAnyFreeze && !instance.lockFpsToMonitor {
            fixes.append(.fixRenderDistanceAndLockFPS)
        }

        var uniqueFixes: [AutoFixAction] = []
        var seenFixes = Set<AutoFixAction>()
        for fix in fixes {
            if seenFixes.insert(fix).inserted {
                uniqueFixes.append(fix)
            }
        }

        return SessionHealthReport(
            smoothnessScore: score,
            totalPlaytimeSeconds: playtime,
            gcMicroFreezesCount: stats.minorStutterCount + stats.criticalFreezeCount,
            maxGcPauseMs: stats.maxPauseMs,
            serverTickDropsCount: stats.tickDropCount,
            maxTickBehindMs: stats.maxTickBehindMs,
            criticalFreezeCount: stats.criticalFreezeCount,
            minorStutterCount: stats.minorStutterCount,
            isConclusive: isConclusive,
            allocatedMemoryMB: instance.memoryMB,
            gcProfile: gcProfileName,
            javaArchitecture: architecture,
            detectedIssues: issues,
            oneClickFixes: uniqueFixes,
            generatedAt: Date()
        )
    }
}
