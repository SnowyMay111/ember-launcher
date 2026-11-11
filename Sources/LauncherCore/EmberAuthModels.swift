import Foundation

/// Supported OAuth providers for Ember accounts.
public enum EmberOAuthProvider: String, CaseIterable, Sendable {
    case google
    case azure
    case discord
}

/// An authenticated Ember account session.
public struct EmberSession: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let userID: String
    public let email: String?

    public var isExpired: Bool {
        expiresAt.timeIntervalSinceNow <= 60
    }

    public init(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        userID: String,
        email: String?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.userID = userID
        self.email = email
    }
}

/// A user's Ember profile.
public struct EmberProfile: Codable, Sendable, Equatable {
    public let id: String
    public let tag: String
    public let displayName: String
    public let bio: String
    public let avatarName: String?
    public let showOnlineStatus: Bool
    public let friendRequests: String
    public let profileVisibility: String
    public let showStats: Bool
    public let playtimeMinutes: Int
    public let instancesCount: Int
    public let modsCount: Int
    public let favoritePack: String?

    public init(
        id: String,
        tag: String,
        displayName: String,
        bio: String,
        avatarName: String?,
        showOnlineStatus: Bool,
        friendRequests: String,
        profileVisibility: String,
        showStats: Bool,
        playtimeMinutes: Int,
        instancesCount: Int,
        modsCount: Int,
        favoritePack: String?
    ) {
        self.id = id
        self.tag = tag
        self.displayName = displayName
        self.bio = bio
        self.avatarName = avatarName
        self.showOnlineStatus = showOnlineStatus
        self.friendRequests = friendRequests
        self.profileVisibility = profileVisibility
        self.showStats = showStats
        self.playtimeMinutes = playtimeMinutes
        self.instancesCount = instancesCount
        self.modsCount = modsCount
        self.favoritePack = favoritePack
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case tag
        case displayName = "display_name"
        case bio
        case avatarName = "avatar_name"
        case showOnlineStatus = "show_online_status"
        case friendRequests = "friend_requests"
        case profileVisibility = "profile_visibility"
        case showStats = "show_stats"
        case playtimeMinutes = "playtime_minutes"
        case instancesCount = "instances_count"
        case modsCount = "mods_count"
        case favoritePack = "favorite_pack"
    }
}

/// Optional changes to an Ember profile.
public struct EmberProfileUpdate: Encodable, Sendable {
    public let tag: String?
    public let displayName: String?
    public let bio: String?
    public let avatarName: String?
    public let showOnlineStatus: Bool?
    public let friendRequests: String?
    public let profileVisibility: String?
    public let showStats: Bool?
    public let playtimeMinutes: Int?
    public let instancesCount: Int?
    public let modsCount: Int?
    public let favoritePack: String?

    public init(
        tag: String? = nil,
        displayName: String? = nil,
        bio: String? = nil,
        avatarName: String? = nil,
        showOnlineStatus: Bool? = nil,
        friendRequests: String? = nil,
        profileVisibility: String? = nil,
        showStats: Bool? = nil,
        playtimeMinutes: Int? = nil,
        instancesCount: Int? = nil,
        modsCount: Int? = nil,
        favoritePack: String? = nil
    ) {
        self.tag = tag
        self.displayName = displayName
        self.bio = bio
        self.avatarName = avatarName
        self.showOnlineStatus = showOnlineStatus
        self.friendRequests = friendRequests
        self.profileVisibility = profileVisibility
        self.showStats = showStats
        self.playtimeMinutes = playtimeMinutes
        self.instancesCount = instancesCount
        self.modsCount = modsCount
        self.favoritePack = favoritePack
    }

    private enum CodingKeys: String, CodingKey {
        case tag
        case displayName = "display_name"
        case bio
        case avatarName = "avatar_name"
        case showOnlineStatus = "show_online_status"
        case friendRequests = "friend_requests"
        case profileVisibility = "profile_visibility"
        case showStats = "show_stats"
        case playtimeMinutes = "playtime_minutes"
        case instancesCount = "instances_count"
        case modsCount = "mods_count"
        case favoritePack = "favorite_pack"
    }
}

/// Errors returned by Ember authentication and profile operations.
public enum EmberAuthError: Error, LocalizedError, Sendable {
    case notConfigured
    case invalidCredentials
    case emailNotConfirmed
    case emailTaken
    case weakPassword(String)
    case tagTaken
    case rateLimited
    case cancelled
    case http(Int, String)
    case invalidResponse

    /// True when the server refused the session itself, so only a new sign-in helps. A dropped connection, a rate
    /// limit or a server fault says nothing about the session and must not sign the user out.
    public var endsSession: Bool {
        switch self {
        case .invalidCredentials: return true
        case .http(let status, _): return (400...403).contains(status)
        default: return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Ember accounts are not set up in this build."
        case .invalidCredentials:
            return "The email or password is incorrect."
        case .emailNotConfirmed:
            return "Please confirm your email before signing in."
        case .emailTaken:
            return "An account with this email already exists."
        case .weakPassword(let message):
            return message.isEmpty ? "The password is too weak." : message
        case .tagTaken:
            return "That tag is already taken."
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .cancelled:
            return "The request was cancelled."
        case .http(let status, let message):
            return message.isEmpty ? "Request failed with status \(status)." : "\(status): \(message)"
        case .invalidResponse:
            return "The server returned an invalid response."
        }
    }
}

/// The result of creating an Ember account.
public enum EmberSignUpResult: Sendable {
    case signedIn(EmberSession)
    case confirmationRequired
}
