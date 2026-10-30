import Foundation

public enum ServerCommand {
    private static let namePattern = "^[A-Za-z0-9_]{1,16}$"

    private static func isValidName(_ player: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: namePattern) else { return false }
        let range = NSRange(player.startIndex..<player.endIndex, in: player)
        return regex.firstMatch(in: player, range: range) != nil
    }

    public static func heal(_ player: String) -> String? {
        guard isValidName(player) else { return nil }
        return "effect give \(player) minecraft:instant_health 1 10"
    }

    public static func healAndFeed(_ player: String) -> [String]? {
        guard isValidName(player) else { return nil }
        return [
            "effect give \(player) minecraft:instant_health 1 10",
            "effect give \(player) minecraft:saturation 1 20"
        ]
    }

    public static func gamemode(_ mode: String, _ player: String) -> String? {
        let validModes: Set<String> = ["survival", "creative", "adventure", "spectator"]
        guard validModes.contains(mode), isValidName(player) else { return nil }
        return "gamemode \(mode) \(player)"
    }

    public static func op(_ player: String) -> String? {
        guard isValidName(player) else { return nil }
        return "op \(player)"
    }

    public static func deop(_ player: String) -> String? {
        guard isValidName(player) else { return nil }
        return "deop \(player)"
    }

    public static func kick(_ player: String, reason: String?) -> String? {
        guard isValidName(player) else { return nil }
        guard let reason, !reason.isEmpty else { return "kick \(player)" }
        let sanitized = reason.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        return "kick \(player) \(sanitized)"
    }

    public static func ban(_ player: String, reason: String?) -> String? {
        guard isValidName(player) else { return nil }
        guard let reason, !reason.isEmpty else { return "ban \(player)" }
        let sanitized = reason.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        return "ban \(player) \(sanitized)"
    }

    public static func pardon(_ player: String) -> String? {
        guard isValidName(player) else { return nil }
        return "pardon \(player)"
    }

    private static func versionComponents(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }

    private static func isAtLeast(_ version: String, _ reference: [Int]) -> Bool {
        let components = versionComponents(version)
        let count = max(components.count, reference.count)
        for index in 0..<count {
            let a = index < components.count ? components[index] : 0
            let b = index < reference.count ? reference[index] : 0
            if a != b { return a > b }
        }
        return true
    }

    public static func setMaxHealth(_ value: Int, _ player: String, minecraftVersion: String) -> String? {
        guard isValidName(player) else { return nil }
        let clamped = min(max(value, 1), 1024)
        let attribute = isAtLeast(minecraftVersion, [1, 21, 2]) ? "minecraft:max_health" : "minecraft:generic.max_health"
        return "attribute \(player) \(attribute) base set \(clamped)"
    }

    public static func difficulty(_ difficulty: String) -> String? {
        let validDifficulties: Set<String> = ["peaceful", "easy", "normal", "hard"]
        guard validDifficulties.contains(difficulty) else { return nil }
        return "difficulty \(difficulty)"
    }

    public static func gamerule(_ name: String, _ value: Bool) -> String? {
        let validNames: Set<String> = [
            "keepInventory",
            "mobGriefing",
            "doDaylightCycle",
            "doMobSpawning",
            "doFireTick",
            "naturalRegeneration"
        ]
        guard validNames.contains(name) else { return nil }
        return "gamerule \(name) \(value)"
    }

    public static func time(_ time: String) -> String? {
        let validTimes: Set<String> = ["day", "night", "noon", "midnight"]
        guard validTimes.contains(time) else { return nil }
        return "time set \(time)"
    }

    public static func weather(_ weather: String) -> String? {
        let validWeathers: Set<String> = ["clear", "rain", "thunder"]
        guard validWeathers.contains(weather) else { return nil }
        return "weather \(weather)"
    }

    public static func saveAll() -> String {
        "save-all"
    }
}

public enum ServerLogEvent: Equatable {
    case joined(String)
    case left(String)
    case chat(player: String, message: String)
    case other(String)
}

public enum ServerLogParser {
    public static func parse(_ line: String) -> ServerLogEvent {
        let message = stripPrefix(line)

        if let player = matchJoined(message) {
            return .joined(player)
        }
        if let player = matchLeft(message) {
            return .left(player)
        }
        if let (player, text) = matchChat(message) {
            return .chat(player: player, message: text)
        }
        return .other(message)
    }

    private static func stripPrefix(_ line: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "^\\[[^\\]]*\\] \\[[^\\]]*\\]: ") else {
            return line
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if let match = regex.firstMatch(in: line, range: range), let matchRange = Range(match.range, in: line) {
            return String(line[matchRange.upperBound...])
        }
        return line
    }

    private static func matchJoined(_ message: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "^(.+) joined the game$") else { return nil }
        let range = NSRange(message.startIndex..<message.endIndex, in: message)
        guard let match = regex.firstMatch(in: message, range: range),
              let playerRange = Range(match.range(at: 1), in: message) else { return nil }
        return String(message[playerRange])
    }

    private static func matchLeft(_ message: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "^(.+) left the game$") else { return nil }
        let range = NSRange(message.startIndex..<message.endIndex, in: message)
        guard let match = regex.firstMatch(in: message, range: range),
              let playerRange = Range(match.range(at: 1), in: message) else { return nil }
        return String(message[playerRange])
    }

    private static func matchChat(_ message: String) -> (String, String)? {
        guard let regex = try? NSRegularExpression(pattern: "^<(.+)> (.*)$") else { return nil }
        let range = NSRange(message.startIndex..<message.endIndex, in: message)
        guard let match = regex.firstMatch(in: message, range: range),
              let playerRange = Range(match.range(at: 1), in: message),
              let textRange = Range(match.range(at: 2), in: message) else { return nil }
        return (String(message[playerRange]), String(message[textRange]))
    }
}

public struct ServerPlayerTracker {
    public private(set) var online: [String] = []

    public init() {}

    public mutating func apply(_ line: String) {
        switch ServerLogParser.parse(line) {
        case .joined(let player):
            guard !online.contains(where: { $0.caseInsensitiveCompare(player) == .orderedSame }) else { return }
            online.append(player)
            online.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        case .left(let player):
            online.removeAll { $0.caseInsensitiveCompare(player) == .orderedSame }
        case .chat, .other:
            break
        }
    }

    public mutating func reset() {
        online = []
    }
}
