import Foundation

public enum VersionKind: String, Codable, Sendable {
    case release
    case snapshot
    case beta
    case alpha
}

public enum VersionCatalog {
    public static func kind(for type: String) -> VersionKind {
        switch type {
        case "release": return .release
        case "snapshot": return .snapshot
        case "old_beta": return .beta
        case "old_alpha": return .alpha
        default: return .release
        }
    }

    public static func kind(for version: ManifestVersion) -> VersionKind {
        kind(for: version.type)
    }

    public static func launchable(_ manifest: VersionManifest, includeSnapshots: Bool, includeOld: Bool = false) -> [ManifestVersion] {
        manifest.versions.filter { version in
            if version.type == "release" {
                return true
            }
            if includeSnapshots && version.type == "snapshot" {
                return true
            }
            if includeOld && (version.type == "old_beta" || version.type == "old_alpha") {
                return true
            }
            return false
        }
    }
}
