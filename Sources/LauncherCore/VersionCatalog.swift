import Foundation

public enum VersionCatalog {
    public static let firstLaunchableReleaseTime = "2018-07-18" // 1.13: older versions use legacy launch arguments we do not support yet

    public static func launchable(_ manifest: VersionManifest, includeSnapshots: Bool) -> [ManifestVersion] {
        manifest.versions.filter { version in
            guard let releaseTime = version.releaseTime, releaseTime >= firstLaunchableReleaseTime else {
                return false
            }
            if version.type == "release" {
                return true
            }
            if includeSnapshots && version.type == "snapshot" {
                return true
            }
            return false
        }
    }
}
