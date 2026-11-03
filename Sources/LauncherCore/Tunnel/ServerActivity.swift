import Foundation

public enum ServerActivityKind: Equatable, Sendable {
    case joined(String)
    case left(String)
    case worldSaved
    case started
}

/// Turns raw server console lines into the short list of things worth showing in a feed.
public enum ServerActivityFeed {
    public static func build(from lines: [String], limit: Int = 8) -> [ServerActivityKind] {
        var events: [ServerActivityKind] = []
        for line in lines {
            switch ServerLogParser.parse(line) {
            case .joined(let player): events.append(.joined(player))
            case .left(let player): events.append(.left(player))
            case .chat: break
            case .other(let message):
                if message.hasPrefix("Done (") && message.contains("For help, type") {
                    events.append(.started)
                } else if message.hasPrefix("Saved the game") || message.contains("All dimensions are saved") {
                    events.append(.worldSaved)
                }
            }
        }
        return Array(events.suffix(limit).reversed())
    }
}
