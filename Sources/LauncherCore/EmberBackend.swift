import Foundation

/// Where Ember accounts live (Supabase). Both values are public by design: the publishable key only works within the row-level-security rules.
/// Empty values mean "not configured": the account screens then say so instead of failing.
public enum EmberBackend {
    public static let urlString = "https://zhjhuwajaymkykzcpkxi.supabase.co"
    public static let anonKey = "sb_publishable_LjU6CeL2XN77gkC9xoUS0Q_i9HXrMY-"

    public static var baseURL: URL? { urlString.isEmpty ? nil : URL(string: urlString) }
    public static var isConfigured: Bool { baseURL != nil && !anonKey.isEmpty }
}
