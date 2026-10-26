import Foundation

public struct ModpackBuildReport: Sendable, Equatable {
    public let installed: [String]
    public let dependencies: Int
    public let skipped: [String]

    public init(
        installed: [String] = [],
        dependencies: Int = 0,
        skipped: [String] = []
    ) {
        self.installed = installed
        self.dependencies = dependencies
        self.skipped = skipped
    }
}

public final class ModpackBuilder: Sendable {
    public let mods: ModManager

    public init(mods: ModManager) {
        self.mods = mods
    }

    public func install(
        _ selected: [PlannedMod],
        into instanceName: String,
        progress: @escaping @Sendable (_ title: String, _ done: Int, _ total: Int) -> Void
    ) async -> ModpackBuildReport {
        var installed: [String] = []
        var dependenciesCount = 0
        var skipped: [String] = []

        let total = selected.count
        for (index, mod) in selected.enumerated() {
            progress(mod.title, index, total)

            let compatibility = await mods.compatibility(project: mod.projectId, instance: instanceName)
            switch compatibility {
            case .conflict(let with):
                skipped.append("\(mod.title): conflicts with \(with)")
            case .unavailable:
                skipped.append("\(mod.title): no release for this version")
            default:
                do {
                    let result = try await mods.install(project: mod.projectId, into: instanceName)
                    installed.append(mod.title)
                    let depCount = result.installed.filter(\.isDependency).count
                    dependenciesCount += depCount
                } catch {
                    skipped.append("\(mod.title): \(error.localizedDescription)")
                }
            }
        }

        return ModpackBuildReport(
            installed: installed,
            dependencies: dependenciesCount,
            skipped: skipped
        )
    }
}
