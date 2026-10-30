import Foundation

/// Relationship state between the current user and another account.
public enum FriendRelation: String, Codable, Sendable {
    case friend
    case incoming
    case outgoing
}

/// A single row from the friends overview.
public struct FriendEntry: Codable, Sendable, Identifiable, Equatable {
    public let userID: String
    public let tag: String
    public let displayName: String
    public let avatarName: String?
    public let relation: FriendRelation
    public let online: Bool
    public let activity: String?
    public let lastSeenAt: Date?

    public var id: String { userID }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case tag
        case displayName = "display_name"
        case avatarName = "avatar_name"
        case relation
        case online
        case activity
        case lastSeenAt = "last_seen_at"
    }

    public init(
        userID: String,
        tag: String,
        displayName: String,
        avatarName: String?,
        relation: FriendRelation,
        online: Bool,
        activity: String?,
        lastSeenAt: Date?
    ) {
        self.userID = userID
        self.tag = tag
        self.displayName = displayName
        self.avatarName = avatarName
        self.relation = relation
        self.online = online
        self.activity = activity
        self.lastSeenAt = lastSeenAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(String.self, forKey: .userID)
        tag = try container.decode(String.self, forKey: .tag)
        displayName = try container.decode(String.self, forKey: .displayName)
        avatarName = try container.decodeIfPresent(String.self, forKey: .avatarName)
        relation = try container.decode(FriendRelation.self, forKey: .relation)
        // Missing or null presence fields mean "not online".
        online = try container.decodeIfPresent(Bool.self, forKey: .online) ?? false
        activity = try container.decodeIfPresent(String.self, forKey: .activity)

        if let raw = try container.decodeIfPresent(String.self, forKey: .lastSeenAt) {
            lastSeenAt = Self.parseDate(raw)
        } else {
            lastSeenAt = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userID, forKey: .userID)
        try container.encode(tag, forKey: .tag)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(avatarName, forKey: .avatarName)
        try container.encode(relation, forKey: .relation)
        try container.encode(online, forKey: .online)
        try container.encodeIfPresent(activity, forKey: .activity)

        if let lastSeenAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: lastSeenAt), forKey: .lastSeenAt)
        }
    }

    /// Parses an ISO8601 timestamp, with or without fractional seconds.
    private static func parseDate(_ raw: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: raw) {
            return date
        }

        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]
        return withoutFraction.date(from: raw)
    }
}

/// Outcome of a friend request action, as returned by the RPCs.
public enum FriendRequestResult: String, Sendable {
    case sent
    case accepted
    case notFound = "not_found"
    case closed
    case exists
    case selfRequest = "self"
    case limit
}

/// Client for the Ember friends system: overview, requests, presence.
public struct EmberFriends: Sendable {
    private let auth: EmberAuth

    public init(auth: EmberAuth = EmberAuth()) {
        self.auth = auth
    }

    public func overview(session: EmberSession) async throws -> [FriendEntry] {
        let data = try await auth.perform(
            path: "rest/v1/rpc/friends_overview",
            method: "POST",
            body: Data("{}".utf8),
            session: session,
            prefer: nil
        )
        return try Self.decode(data)
    }

    public func sendRequest(tag: String, session: EmberSession) async throws -> FriendRequestResult {
        let data = try await auth.perform(
            path: "rest/v1/rpc/send_friend_request",
            method: "POST",
            body: try JSONEncoder().encode(TagBody(tag: tag)),
            session: session,
            prefer: nil
        )
        return try decodeResult(from: data)
    }

    public func respond(userID: String, accept: Bool, session: EmberSession) async throws -> FriendRequestResult {
        let data = try await auth.perform(
            path: "rest/v1/rpc/respond_friend_request",
            method: "POST",
            body: try JSONEncoder().encode(RespondBody(user: userID, accept: accept)),
            session: session,
            prefer: nil
        )
        return try decodeResult(from: data)
    }

    public func remove(userID: String, session: EmberSession) async throws {
        _ = try await auth.perform(
            path: "rest/v1/rpc/remove_friend",
            method: "POST",
            body: try JSONEncoder().encode(UserBody(user: userID)),
            session: session,
            prefer: nil
        )
    }

    public func heartbeat(activity: String?, session: EmberSession) async throws {
        _ = try await auth.perform(
            path: "rest/v1/rpc/set_presence",
            method: "POST",
            body: try JSONEncoder().encode(ActivityBody(activity: activity)),
            session: session,
            prefer: nil
        )
    }

    /// Decodes a friends_overview response. Public so it can be unit tested directly.
    public static func decode(_ data: Data) throws -> [FriendEntry] {
        do {
            return try JSONDecoder().decode([FriendEntry].self, from: data)
        } catch {
            throw EmberAuthError.invalidResponse
        }
    }

    private func decodeResult(from data: Data) throws -> FriendRequestResult {
        guard
            let raw = try? JSONDecoder().decode(String.self, from: data),
            let result = FriendRequestResult(rawValue: raw)
        else {
            throw EmberAuthError.invalidResponse
        }
        return result
    }
}

private struct TagBody: Encodable, Sendable {
    let tag: String

    private enum CodingKeys: String, CodingKey {
        case tag = "p_tag"
    }
}

private struct RespondBody: Encodable, Sendable {
    let user: String
    let accept: Bool

    private enum CodingKeys: String, CodingKey {
        case user = "p_user"
        case accept = "p_accept"
    }
}

private struct UserBody: Encodable, Sendable {
    let user: String

    private enum CodingKeys: String, CodingKey {
        case user = "p_user"
    }
}

private struct ActivityBody: Encodable, Sendable {
    let activity: String?

    private enum CodingKeys: String, CodingKey {
        case activity = "p_activity"
    }

    // Encodes `nil` as explicit JSON null rather than omitting the key.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let activity {
            try container.encode(activity, forKey: .activity)
        } else {
            try container.encodeNil(forKey: .activity)
        }
    }
}
