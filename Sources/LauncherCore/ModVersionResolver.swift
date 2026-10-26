import Foundation

extension ModManager {
    /// The best release of `project` for the instance, skipping versions that cannot work next to what is
    /// installed. Modrinth's newest build for a game version can pin a library version that does not exist
    /// for that game version (Iris 1.11.4 for 26.1 pins a Sodium that is only built for 26.2).
    public func resolveVersion(
        project idOrSlug: String,
        instance: Instance,
        installed: [ModRecord]
    ) async throws -> ModrinthVersion? {
        let candidates = try await client.versions(
            project: idOrSlug,
            gameVersion: instance.minecraftVersion,
            loader: instance.loader.lowercased()
        )
        for candidate in Self.byReleaseType(candidates) {
            if await fits(candidate, instance: instance, installed: installed) {
                return candidate
            }
        }
        return nil
    }

    /// Whether a version's required dependencies, when Modrinth pins an exact version, exist for the instance's
    /// game version and loader and agree with the installed copy; also false when it is marked incompatible
    /// with an installed mod.
    func fits(_ version: ModrinthVersion, instance: Instance, installed: [ModRecord]) async -> Bool {
        let loader = instance.loader.lowercased()
        for dependency in version.dependencies {
            guard let projectId = dependency.projectId, !projectId.isEmpty else { continue }
            let present = installed.first { $0.projectId == projectId }
            switch dependency.type {
            case .incompatible:
                if present != nil { return false }
            case .required:
                guard let pinnedId = dependency.versionId, !pinnedId.isEmpty,
                      let pinned = try? await client.version(id: pinnedId) else { continue }
                guard pinned.gameVersions.contains(instance.minecraftVersion), pinned.loaders.contains(loader) else {
                    return false
                }
                if let present, present.versionId != pinnedId,
                   !Self.sameReleaseLine(present.versionNumber, pinned.versionNumber) {
                    return false
                }
            case .optional, .embedded, .unknown:
                break
            }
        }
        return true
    }

    /// Release first, then beta, then alpha; newest first inside each group (the list arrives newest first).
    static func byReleaseType(_ versions: [ModrinthVersion]) -> [ModrinthVersion] {
        func rank(_ type: String) -> Int {
            switch type.lowercased() {
            case "release": return 0
            case "beta": return 1
            case "alpha": return 2
            default: return 3
            }
        }
        return versions.enumerated()
            .sorted { (rank($0.element.versionType), $0.offset) < (rank($1.element.versionType), $1.offset) }
            .map(\.element)
    }

    /// Mods of the same line (0.8.x with 0.8.x, 2.x with 2.x) work together; a missing number counts as a match.
    static func sameReleaseLine(_ a: String, _ b: String) -> Bool {
        guard let lineA = releaseLine(a), let lineB = releaseLine(b) else { return true }
        return lineA == lineB
    }

    /// "mc26.1.1-0.8.9-fabric" and "0.8.9+mc26.1.1" are both line "0.8"; "1.11.4+26.1" is "1".
    private static func releaseLine(_ versionNumber: String) -> String? {
        let withoutGameVersion = versionNumber.replacingOccurrences(
            of: #"(?i)mc[-_]?\d+(\.\d+)*"#, with: " ", options: .regularExpression
        )
        guard let range = withoutGameVersion.range(of: #"\d+\.\d+(\.\d+)?"#, options: .regularExpression) else {
            return nil
        }
        let parts = withoutGameVersion[range].split(separator: ".")
        guard let major = parts.first else { return nil }
        return major == "0" && parts.count > 1 ? "0.\(parts[1])" : String(major)
    }
}
