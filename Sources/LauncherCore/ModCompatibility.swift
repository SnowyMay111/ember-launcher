import Foundation

/// What installing a mod into a given instance would mean, checked before anything is downloaded.
public enum ModCompatibility: Sendable, Equatable {
    /// Fits as is: no required dependency is missing.
    case ready
    /// Fits, but this many required dependencies will be downloaded with it.
    case needs(count: Int)
    /// An installed mod is marked incompatible by this one.
    case conflict(with: String)
    /// No release for this game version and loader.
    case unavailable
    /// Could not be checked (offline, rate limit).
    case unknown
}

extension ModManager {
    /// Looks at the best version of `project` for the instance and compares its direct dependencies
    /// with what is already installed. Deeper dependencies are not followed, so `needs` is a minimum.
    public func compatibility(project idOrSlug: String, instance name: String) async -> ModCompatibility {
        guard let instance = try? store.load(name: name) else { return .unknown }
        let installed = ((try? list(instance: name)) ?? []).compactMap(\.record)
        let installedIDs = Set(installed.map(\.projectId))
        let version: ModrinthVersion?
        do {
            version = try await resolveVersion(project: idOrSlug, instance: instance, installed: installed)
        } catch {
            return .unknown
        }
        guard let version else { return .unavailable }

        for dependency in version.dependencies where dependency.type == .incompatible {
            guard let id = dependency.projectId,
                  let record = installed.first(where: { $0.projectId == id }) else { continue }
            return .conflict(with: record.title)
        }

        let missing = Set(
            version.dependencies
                .filter { $0.type == .required }
                .compactMap(\.projectId)
                .filter { !$0.isEmpty && !installedIDs.contains($0) }
        )
        return missing.isEmpty ? .ready : .needs(count: missing.count)
    }
}
