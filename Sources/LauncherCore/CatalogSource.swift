import Foundation

/// Which catalogs the browse screens search. Ids prefixed "cf:" are always routed to CurseForge, whatever this says.
public enum CatalogSource: String, Sendable, CaseIterable {
    case both, modrinth, curseforge

    public static let defaultsKey = "ember.catalogSource"

    /// Read on every call: Settings writes the same key through @AppStorage.
    public static var current: CatalogSource {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(CatalogSource.init(rawValue:)) ?? .both
    }
}
