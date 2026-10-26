import Foundation

/// Garbage collector choice for an instance. `auto` picks by system RAM and Java version.
public enum GCProfile: String, Codable, Sendable, CaseIterable {
    case auto
    case zeroStutterZGC
    case tunedG1GC
    /// No GC flags from the launcher; the JVM defaults (plus the user's own args) apply.
    case none
}

/// Memory numbers for the UI slider.
public struct MemoryRecommendation: Sendable, Equatable {
    public let minMB: Int
    public let recommendedRangeMB: ClosedRange<Int>
    public let overAllocationWarningThresholdMB: Int
    public let systemMemoryMB: Int

    /// A warning text when `memoryMB` is likely to cause long GC pauses or starve the system.
    public func warning(forMB memoryMB: Int) -> String? {
        if memoryMB > systemMemoryMB {
            return "More than the physical RAM of this Mac: the game will swap and freeze."
        }
        if memoryMB > overAllocationWarningThresholdMB {
            return "Too much memory causes long garbage collector pauses and stutters. Stay within \(recommendedRangeMB.lowerBound)-\(recommendedRangeMB.upperBound) MB."
        }
        return nil
    }
}

public enum JVMArgumentsBuilder {
    public static var systemMemoryMB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
    }

    public static func memoryRecommendation(
        systemMemoryMB: Int = JVMArgumentsBuilder.systemMemoryMB,
        isModded: Bool
    ) -> MemoryRecommendation {
        let range: ClosedRange<Int>
        switch systemMemoryMB {
        case ..<9_000:
            range = 3072...4096
        case ..<15_000:
            range = isModded ? 4096...6144 : 3072...4096
        default:
            range = isModded ? 6144...8192 : 4096...6144
        }
        let threshold = min(10_240, systemMemoryMB * 7 / 10)
        return MemoryRecommendation(
            minMB: 2048,
            recommendedRangeMB: range,
            overAllocationWarningThresholdMB: threshold,
            systemMemoryMB: systemMemoryMB
        )
    }

    /// `auto` becomes ZGC only on Java 21+ with 16 GB or more (pre-touching the heap hurts small Macs); G1 otherwise.
    public static func resolveProfile(
        _ requested: GCProfile,
        javaMajor: Int?,
        systemMemoryMB: Int = JVMArgumentsBuilder.systemMemoryMB
    ) -> GCProfile {
        guard requested == .auto else { return requested }
        if let javaMajor, javaMajor >= 21, systemMemoryMB >= 15_000 {
            return .zeroStutterZGC
        }
        return .tunedG1GC
    }

    public static func gcArguments(
        profile: GCProfile,
        javaMajor: Int?,
        memoryMB: Int,
        systemMemoryMB: Int = JVMArgumentsBuilder.systemMemoryMB
    ) -> [String] {
        switch profile {
        case .auto, .none:
            return []
        case .zeroStutterZGC:
            var args = ["-XX:+UseZGC"]
            // Generational mode is opt-in on Java 21-23, always on in 24+ (the flag is obsolete there).
            if let javaMajor, (21...23).contains(javaMajor) {
                args.append("-XX:+ZGenerational")
            }
            // Touching the whole heap at start costs seconds and RAM, so only when it is a modest share.
            if memoryMB * 2 <= systemMemoryMB {
                args.append("-XX:+AlwaysPreTouch")
            }
            args.append("-XX:+DisableExplicitGC")
            return args
        case .tunedG1GC:
            return [
                "-XX:+UseG1GC",
                "-XX:+ParallelRefProcEnabled",
                "-XX:MaxGCPauseMillis=30",
                "-XX:+UnlockExperimentalVMOptions",
                "-XX:+DisableExplicitGC",
                "-XX:G1NewSizePercent=20",
                "-XX:G1ReservePercent=20",
                "-XX:MaxTenuringThreshold=1"
            ]
        }
    }

    /// Memory plus GC flags. The user's own `-XX:+Use…GC` wins: two collectors make the JVM refuse to start.
    public static func arguments(
        memoryMB: Int,
        profile: GCProfile,
        javaMajor: Int?,
        userArguments: [String],
        systemMemoryMB: Int = JVMArgumentsBuilder.systemMemoryMB
    ) -> [String] {
        let resolved = resolveProfile(profile, javaMajor: javaMajor, systemMemoryMB: systemMemoryMB)
        let userPicksGC = userArguments.contains { $0.hasPrefix("-XX:+Use") && $0.hasSuffix("GC") }
        let gc = userPicksGC
            ? []
            : gcArguments(profile: resolved, javaMajor: javaMajor, memoryMB: memoryMB, systemMemoryMB: systemMemoryMB)
        // Xms = Xmx only for pre-touch, and not when the user sets heap flags: a smaller user -Xmx would make the JVM refuse to start.
        let userSetsHeap = userArguments.contains { $0.hasPrefix("-Xmx") || $0.hasPrefix("-Xms") }
        let preTouch = gc.contains("-XX:+AlwaysPreTouch") && !userSetsHeap
        let initial = preTouch ? memoryMB : min(memoryMB, 512)
        return ["-Xms\(initial)M", "-Xmx\(memoryMB)M"] + gc
    }
}
