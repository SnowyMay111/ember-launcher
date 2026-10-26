import Foundation

public struct RuleOS: Codable, Sendable {
    public let name: String?
    public let arch: String?
    public let version: String?

    public init(name: String? = nil, arch: String? = nil, version: String? = nil) {
        self.name = name
        self.arch = arch
        self.version = version
    }
}

public struct Rule: Codable, Sendable {
    public let action: String
    public let os: RuleOS?
    public let features: [String: Bool]?

    public init(action: String, os: RuleOS? = nil, features: [String: Bool]? = nil) {
        self.action = action
        self.os = os
        self.features = features
    }
}

public enum RuleEvaluator {
    public static func isAllowed(rules: [Rule]?) -> Bool {
        guard let rules = rules, !rules.isEmpty else {
            return true
        }

        var allowed = false

        for rule in rules {
            if matches(rule: rule) {
                allowed = (rule.action == "allow")
            }
        }

        return allowed
    }

    private static func matches(rule: Rule) -> Bool {
        // Mojang specification: launcher features rules are false (demo, custom resolution, etc.)
        if let features = rule.features, !features.isEmpty {
            return false
        }

        if let os = rule.os {
            if let osName = os.name {
                if osName != "osx" {
                    return false
                }
            }

            if let osArch = os.arch {
                if osArch == "x86" {
                    return false
                }
                if osArch != "arm64" {
                    return false
                }
            }
        }

        return true
    }
}
