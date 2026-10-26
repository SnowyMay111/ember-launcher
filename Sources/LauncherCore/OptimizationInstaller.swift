import Foundation

public struct OptimizationFailedMod: Codable, Sendable, Equatable {
    public var slug: String
    public var message: String

    public init(slug: String, message: String) {
        self.slug = slug
        self.message = message
    }
}

public struct OptimizationApplyReport: Sendable, Equatable {
    public var installed: [String]
    public var skippedNoVersion: [String]
    public var alreadyInstalled: [String]
    public var failed: [OptimizationFailedMod]
    public var warnings: [String]

    public init(
        installed: [String] = [],
        skippedNoVersion: [String] = [],
        alreadyInstalled: [String] = [],
        failed: [OptimizationFailedMod] = [],
        warnings: [String] = []
    ) {
        self.installed = installed
        self.skippedNoVersion = skippedNoVersion
        self.alreadyInstalled = alreadyInstalled
        self.failed = failed
        self.warnings = warnings
    }
}

public struct OptimizationInstaller: Sendable {
    public let modManager: ModManager

    public init(modManager: ModManager) {
        self.modManager = modManager
    }

    public func apply(_ plan: OptimizationPlan, to instanceName: String, includeOptional: Bool = false) async throws -> OptimizationApplyReport {
        let instance = try modManager.store.load(name: instanceName)
        guard instance.loader.lowercased() == "fabric" else {
            throw ModManagerError.unsupportedLoader(instance.loader)
        }

        var targetSlugs = plan.slugs
        if includeOptional {
            targetSlugs.append(contentsOf: plan.optionalSlugs)
        }

        var uniqueSlugs: [String] = []
        var seen = Set<String>()
        for slug in targetSlugs {
            if !seen.contains(slug) {
                seen.insert(slug)
                uniqueSlugs.append(slug)
            }
        }

        var installed: [String] = []
        var skippedNoVersion: [String] = []
        var alreadyInstalled: [String] = []
        var failed: [OptimizationFailedMod] = []
        var warnings: [String] = []

        for slug in uniqueSlugs {
            do {
                let result = try await modManager.install(project: slug, into: instanceName)
                if result.installed.isEmpty && !result.skipped.isEmpty {
                    for skip in result.skipped {
                        if skip.contains("already installed") {
                            alreadyInstalled.append(slug)
                        } else {
                            alreadyInstalled.append(skip)
                        }
                    }
                } else {
                    for item in result.installed {
                        installed.append(item.title.isEmpty ? slug : item.title)
                    }
                }
                warnings.append(contentsOf: result.warnings)
            } catch let error as ModrinthError {
                switch error {
                case .noCompatibleVersion:
                    skippedNoVersion.append(slug)
                default:
                    failed.append(OptimizationFailedMod(slug: slug, message: error.localizedDescription))
                }
            } catch {
                failed.append(OptimizationFailedMod(slug: slug, message: error.localizedDescription))
            }
        }

        return OptimizationApplyReport(
            installed: installed,
            skippedNoVersion: skippedNoVersion,
            alreadyInstalled: alreadyInstalled,
            failed: failed,
            warnings: warnings
        )
    }
}
