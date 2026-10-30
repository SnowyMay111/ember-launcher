import Foundation

/// Where Ember accounts live (Supabase). Both values are public by design: the anon key only works within the row-level-security rules.
/// Empty values mean "not configured": the account screens then say so instead of failing.
public enum EmberBackend {
    public static let urlString = ""
    public static let anonKey = ""

    public static var baseURL: URL? { urlString.isEmpty ? nil : URL(string: urlString) }
    public static var isConfigured: Bool { baseURL != nil && !anonKey.isEmpty }
}
