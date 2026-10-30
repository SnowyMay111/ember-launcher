import Foundation

public enum LauncherInfo {
    public static let name = "mc-launcher"
    public static let version = "0.2.3"
    /// Sent as User-Agent with every request, as Modrinth and GitHub ask: the project and where to reach it.
    public static let userAgent = "SnowyMay111/ember-launcher/\(version) (github.com/SnowyMay111/ember-launcher)"
}
