import Foundation

public enum OptimizationLoader: String, Codable, Sendable, Equatable, CaseIterable {
    case fabric
    case neoforge
    case forge

    public init?(instanceLoader: String) {
        let lower = instanceLoader.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch lower {
        case "forge":
            self = .forge
        case "neoforge":
            self = .neoforge
        case "fabric":
            self = .fabric
        default:
            return nil
        }
    }
}

public enum OptimizationOS: String, Codable, Sendable, Equatable {
    case macOS = "macOS"
    case windows = "windows"

    public static var current: OptimizationOS {
        #if os(macOS)
        return .macOS
        #else
        return .windows
        #endif
    }
}

public enum OptimizationPreset: String, Codable, Sendable, Equatable, CaseIterable {
    case maxFPS_PvP = "maxFPS_PvP"
    case balancedLoD = "balancedLoD"
    case shadersVisual = "shadersVisual"
    case heavyModpack = "heavyModpack"

    public init?(string: String) {
        if let match = OptimizationPreset(rawValue: string) {
            self = match
            return
        }
        let lower = string.lowercased()
        switch lower {
        case "maxfps_pvp", "maxfps", "pvp":
            self = .maxFPS_PvP
        case "balancedlod", "balanced", "lod":
            self = .balancedLoD
        case "shadersvisual", "shaders", "visual":
            self = .shadersVisual
        case "heavymodpack", "heavy", "modpack":
            self = .heavyModpack
        default:
            return nil
        }
    }
}

public struct OptimizationContext: Codable, Sendable, Equatable {
    public var mcVersion: String
    public var loader: OptimizationLoader
    public var os: OptimizationOS
    public var preset: OptimizationPreset
    public var enableShaders: Bool
    public var enableLoD: Bool
    public var enableFrameGen: Bool
    public var asyncForHeavyModpack: Bool

    public init(
        mcVersion: String,
        loader: OptimizationLoader,
        os: OptimizationOS,
        preset: OptimizationPreset,
        enableShaders: Bool,
        enableLoD: Bool,
        enableFrameGen: Bool,
        asyncForHeavyModpack: Bool = false
    ) {
        self.mcVersion = mcVersion
        self.loader = loader
        self.os = os
        self.preset = preset
        self.enableShaders = enableShaders
        self.enableLoD = enableLoD
        self.enableFrameGen = enableFrameGen
        self.asyncForHeavyModpack = asyncForHeavyModpack
    }
}

public struct BlockedMod: Codable, Sendable, Equatable {
    public var slug: String
    public var reason: String
    public var code: String

    public init(slug: String, reason: String, code: String) {
        self.slug = slug
        self.reason = reason
        self.code = code
    }
}

public struct OptimizationNotice: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, Equatable {
        case info
        case warning
    }

    public var kind: Kind
    public var message: String
    public var code: String

    public init(kind: Kind, message: String, code: String) {
        self.kind = kind
        self.message = message
        self.code = code
    }
}

public struct OptimizationPlan: Codable, Sendable, Equatable {
    public var slugs: [String]
    public var optionalSlugs: [String]
    public var blocked: [BlockedMod]
    public var notices: [OptimizationNotice]

    public init(
        slugs: [String] = [],
        optionalSlugs: [String] = [],
        blocked: [BlockedMod] = [],
        notices: [OptimizationNotice] = []
    ) {
        self.slugs = slugs
        self.optionalSlugs = optionalSlugs
        self.blocked = blocked
        self.notices = notices
    }
}

public enum OptimizationRuleEngine {
    /// First Minecraft version with Mojang's own (experimental, opt-in) Vulkan renderer.
    /// Checked on Modrinth 2026-10-26: Sodium 0.9.0 for 26.2 supports it, VulkanMod has no builds after 26.1.2.
    public static let nativeVulkanSince = "26.2"

    /// Compares two Minecraft version strings using numeric dot components.
    /// Non-numeric suffixes like "-snapshot-5" / "-rc-1" sort before the plain release of the same numbers.
    ///
    /// Examples:
    /// - `compareMinecraftVersions("26.3", "1.21.1") == .orderedDescending`
    /// - `compareMinecraftVersions("1.21.10", "1.21.9") == .orderedDescending`
    /// - `compareMinecraftVersions("26.3-rc-1", "26.3") == .orderedAscending`
    /// - `compareMinecraftVersions("26.3-snapshot-5", "26.3") == .orderedAscending`
    public static func compareMinecraftVersions(_ a: String, _ b: String) -> ComparisonResult {
        let parsedA = parseVersion(a)
        let parsedB = parseVersion(b)

        let maxCount = max(parsedA.numbers.count, parsedB.numbers.count)
        for i in 0..<maxCount {
            let numA = i < parsedA.numbers.count ? parsedA.numbers[i] : 0
            let numB = i < parsedB.numbers.count ? parsedB.numbers[i] : 0
            if numA < numB {
                return .orderedAscending
            } else if numA > numB {
                return .orderedDescending
            }
        }

        switch (parsedA.suffix, parsedB.suffix) {
        case (.some, .none):
            return .orderedAscending
        case (.none, .some):
            return .orderedDescending
        case (.some(let sA), .some(let sB)):
            return sA.localizedStandardCompare(sB)
        case (.none, .none):
            return .orderedSame
        }
    }

    private static func parseVersion(_ v: String) -> (numbers: [Int], suffix: String?) {
        let clean = v.trimmingCharacters(in: .whitespacesAndNewlines)
        var numPart = ""
        var suffix: String? = nil
        for (idx, ch) in clean.enumerated() {
            if ch.isNumber || ch == "." {
                numPart.append(ch)
            } else {
                let suffixIndex = clean.index(clean.startIndex, offsetBy: idx)
                var s = String(clean[suffixIndex...])
                if s.hasPrefix("-") {
                    s = String(s.dropFirst())
                }
                suffix = s
                break
            }
        }
        let numbers = numPart.split(separator: ".").compactMap { Int($0) }
        return (numbers, suffix)
    }

    public static func context(
        for instance: Instance,
        preset: OptimizationPreset,
        enableShaders: Bool = false,
        enableLoD: Bool = false,
        enableFrameGen: Bool = false,
        os: OptimizationOS = .current
    ) -> OptimizationContext {
        let loader = OptimizationLoader(instanceLoader: instance.loader) ?? .fabric
        return OptimizationContext(
            mcVersion: instance.minecraftVersion,
            loader: loader,
            os: os,
            preset: preset,
            enableShaders: enableShaders,
            enableLoD: enableLoD,
            enableFrameGen: enableFrameGen
        )
    }

    public static func plan(for context: OptimizationContext) -> OptimizationPlan {
        var slugs: [String] = []
        var optionalSlugs: [String] = []
        var blocked: [BlockedMod] = []
        var notices: [OptimizationNotice] = []

        // Rule 1: Memory/entity base
        slugs.append("ferrite-core")
        slugs.append("modernfix")
        slugs.append("entityculling")
        if context.loader != .forge {
            slugs.append("lithium")
            if context.preset == .heavyModpack && !context.asyncForHeavyModpack {
                optionalSlugs.append("async")
            } else {
                slugs.append("async")
            }
        }

        // Rule 2: Render core
        let isNativeVulkan = compareMinecraftVersions(context.mcVersion, nativeVulkanSince) != .orderedAscending

        if isNativeVulkan {
            notices.append(OptimizationNotice(
                kind: .info,
                message: "Mojang native Vulkan renderer is available in Minecraft \(nativeVulkanSince)+ (experimental). Sodium supports it, VulkanMod is not needed.",
                code: "native_vulkan"
            ))
            if context.loader == .forge {
                slugs.append("embeddium")
                slugs.append("immediatelyfast")
                if context.enableShaders || context.preset == .shadersVisual {
                    slugs.append("oculus")
                }
            } else {
                slugs.append("sodium")
                slugs.append("immediatelyfast")
                if context.enableShaders || context.preset == .shadersVisual {
                    slugs.append("iris")
                }
            }
        } else {
            if context.preset == .maxFPS_PvP && !context.enableShaders {
                if context.os == .windows {
                    if context.loader == .fabric {
                        slugs.append("vulkanmod")
                        optionalSlugs.append("beryl")
                    } else if context.loader == .forge {
                        slugs.append("embeddium")
                        slugs.append("immediatelyfast")
                    } else {
                        slugs.append("sodium")
                        slugs.append("immediatelyfast")
                    }
                } else {
                    notices.append(OptimizationNotice(
                        kind: .info,
                        message: "VulkanMod runs through MoltenVK on macOS and may be unstable; using Sodium instead.",
                        code: "vulkanmod_mac_moltenvk"
                    ))
                    if context.loader == .forge {
                        slugs.append("embeddium")
                        slugs.append("immediatelyfast")
                    } else {
                        slugs.append("sodium")
                        slugs.append("immediatelyfast")
                    }
                }
            } else if context.enableShaders || context.preset == .heavyModpack {
                blocked.append(BlockedMod(
                    slug: "vulkanmod",
                    reason: "VulkanMod is incompatible with shaders or heavy modpack configurations.",
                    code: "vulkanmod_shaders_heavy"
                ))
                if context.loader == .forge {
                    slugs.append("embeddium")
                    slugs.append("oculus")
                } else {
                    slugs.append("sodium")
                    slugs.append("iris")
                }
            } else {
                if context.loader == .forge {
                    slugs.append("embeddium")
                    slugs.append("immediatelyfast")
                    if context.enableShaders {
                        slugs.append("oculus")
                    }
                } else {
                    slugs.append("sodium")
                    slugs.append("immediatelyfast")
                    if context.enableShaders {
                        slugs.append("iris")
                    }
                }
            }
        }

        // Rule 3: Chunks/LoD
        if context.preset == .heavyModpack {
            blocked.append(BlockedMod(
                slug: "c2me-fabric",
                reason: "C2ME breaks custom mod structures in heavy modpacks.",
                code: "c2me_heavy_modpack"
            ))
        } else if context.loader == .fabric {
            slugs.append("c2me-fabric")
        }

        if context.enableLoD {
            if context.os == .windows {
                if context.loader == .fabric {
                    slugs.append("voxy")
                } else {
                    slugs.append("distanthorizons")
                }
            } else {
                blocked.append(BlockedMod(
                    slug: "voxy",
                    reason: "Apple froze OpenGL at 4.1; Voxy requires OpenGL 4.4-4.6 and crashes on macOS.",
                    code: "voxy_mac_opengl"
                ))
                blocked.append(BlockedMod(
                    slug: "ggtu",
                    reason: "Apple froze OpenGL at 4.1; GGTU requires OpenGL 4.4-4.6 and crashes on macOS.",
                    code: "voxy_mac_opengl"
                ))
                notices.append(OptimizationNotice(
                    kind: .warning,
                    message: "Apple froze OpenGL at 4.1. Voxy and GGTU require OpenGL 4.4-4.6 (compute shaders / DSA) and crash on Mac; using Distant Horizons instead.",
                    code: "voxy_mac_opengl"
                ))
                slugs.append("distanthorizons")
                if context.loader == .fabric {
                    optionalSlugs.append("bobby")
                }
            }
        }

        // Rule 4: Frame gen
        if context.enableFrameGen {
            if context.os == .windows {
                if slugs.contains("sodium") {
                    slugs.append("ggtu")
                    notices.append(OptimizationNotice(
                        kind: .warning,
                        message: "GGTU frame generation may introduce noticeable input lag.",
                        code: "ggtu_input_lag"
                    ))
                }
            } else {
                notices.append(OptimizationNotice(
                    kind: .info,
                    message: "Frame generation is not available on macOS.",
                    code: "framegen_unavailable_mac"
                ))
            }
        }

        // Conflict safety
        if context.os == .macOS {
            slugs.removeAll { $0 == "voxy" || $0 == "ggtu" }
            optionalSlugs.removeAll { $0 == "voxy" || $0 == "ggtu" }
        }

        let blockedSlugs = Set(blocked.map { $0.slug })
        var resolvedSlugs = slugs.filter { !blockedSlugs.contains($0) }

        if resolvedSlugs.contains("vulkanmod") {
            let conflicting = Set(["sodium", "iris", "embeddium", "oculus"])
            resolvedSlugs.removeAll { conflicting.contains($0) }
            optionalSlugs.removeAll { conflicting.contains($0) }
        }

        var uniqueSlugs: [String] = []
        var seenSlugs = Set<String>()
        for slug in resolvedSlugs {
            if !seenSlugs.contains(slug) {
                seenSlugs.insert(slug)
                uniqueSlugs.append(slug)
            }
        }

        var uniqueOptional: [String] = []
        for slug in optionalSlugs {
            if !seenSlugs.contains(slug) && !blockedSlugs.contains(slug) && !uniqueOptional.contains(slug) {
                uniqueOptional.append(slug)
            }
        }

        return OptimizationPlan(
            slugs: uniqueSlugs,
            optionalSlugs: uniqueOptional,
            blocked: blocked,
            notices: notices
        )
    }
}
