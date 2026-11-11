import Foundation

/// Visibility rule for a hosted lobby: open to friends or invite only.
public enum LobbyPrivacy: String, Codable, Sendable {
    case friends
    case invite
}

/// Request body for creating a lobby. Encodes directly to the RPC's `p_` parameter names.
public struct LobbyCreateRequest: Encodable, Sendable {
    public let name: String
    public let mcVersion: String
    public let loader: String
    public let packURL: String?
    public let packSHA1: String?
    public let privacy: LobbyPrivacy
    public let maxPlayers: Int
    public let nick: String

    private enum CodingKeys: String, CodingKey {
        case name = "p_name"
        case mcVersion = "p_mc_version"
        case loader = "p_loader"
        case packURL = "p_pack_url"
        case packSHA1 = "p_pack_sha1"
        case privacy = "p_privacy"
        case maxPlayers = "p_max_players"
        case nick = "p_nick"
    }

    public init(
        name: String,
        mcVersion: String,
        loader: String,
        packURL: String?,
        packSHA1: String?,
        privacy: LobbyPrivacy,
        maxPlayers: Int,
        nick: String
    ) {
        self.name = name
        self.mcVersion = mcVersion
        self.loader = loader
        self.packURL = packURL
        self.packSHA1 = packSHA1
        self.privacy = privacy
        self.maxPlayers = maxPlayers
        self.nick = nick
    }

    // Encodes nil pack fields as explicit JSON null rather than omitting the key.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(mcVersion, forKey: .mcVersion)
        try container.encode(loader, forKey: .loader)
        if let packURL {
            try container.encode(packURL, forKey: .packURL)
        } else {
            try container.encodeNil(forKey: .packURL)
        }
        if let packSHA1 {
            try container.encode(packSHA1, forKey: .packSHA1)
        } else {
            try container.encodeNil(forKey: .packSHA1)
        }
        try container.encode(privacy, forKey: .privacy)
        try container.encode(maxPlayers, forKey: .maxPlayers)
        try container.encode(nick, forKey: .nick)
    }
}

/// A newly created lobby's identifier and join code.
public struct CreatedLobby: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let code: String

    private enum CodingKeys: String, CodingKey {
        case id = "lobby_id"
        case code
    }

    public init(id: String, code: String) {
        self.id = id
        self.code = code
    }
}

/// Outcome of an invite_to_lobby call.
public enum LobbyInviteResult: String, Sendable {
    case invited
    case forbidden
    case notFriends = "not_friends"
}

/// Visibility rule for who may edit a lobby's content list.
public enum LobbyEditPolicy: String, Codable, Sendable, CaseIterable {
    case host
    case friends
    case all
}

/// The lobby details returned when a join succeeds.
public struct JoinedLobby: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let mcVersion: String
    public let loader: String
    public let packURL: String?
    public let packSHA1: String?
    public let address: String?
    public let maxPlayers: Int
    public let host: String
    public let status: String
    public let editPolicy: LobbyEditPolicy
    public let syncShaders: Bool
    public let syncResourcePacks: Bool
    public let canEdit: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case mcVersion = "mc_version"
        case loader
        case packURL = "pack_url"
        case packSHA1 = "pack_sha1"
        case address
        case maxPlayers = "max_players"
        case host
        case status
        case editPolicy = "edit_policy"
        case syncShaders = "sync_shaders"
        case syncResourcePacks = "sync_resourcepacks"
        case canEdit = "can_edit"
    }

    public init(
        id: String,
        name: String,
        mcVersion: String,
        loader: String,
        packURL: String?,
        packSHA1: String?,
        address: String? = nil,
        maxPlayers: Int,
        host: String,
        status: String = "open",
        editPolicy: LobbyEditPolicy = .host,
        syncShaders: Bool = false,
        syncResourcePacks: Bool = true,
        canEdit: Bool = false
    ) {
        self.id = id
        self.name = name
        self.mcVersion = mcVersion
        self.loader = loader
        self.packURL = packURL
        self.packSHA1 = packSHA1
        self.address = address
        self.maxPlayers = maxPlayers
        self.host = host
        self.status = status
        self.editPolicy = editPolicy
        self.syncShaders = syncShaders
        self.syncResourcePacks = syncResourcePacks
        self.canEdit = canEdit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mcVersion = try container.decode(String.self, forKey: .mcVersion)
        loader = try container.decode(String.self, forKey: .loader)
        packURL = try container.decodeIfPresent(String.self, forKey: .packURL)
        packSHA1 = try container.decodeIfPresent(String.self, forKey: .packSHA1)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        maxPlayers = try container.decode(Int.self, forKey: .maxPlayers)
        host = try container.decode(String.self, forKey: .host)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "open"
        editPolicy = try container.decodeIfPresent(LobbyEditPolicy.self, forKey: .editPolicy) ?? .host
        syncShaders = try container.decodeIfPresent(Bool.self, forKey: .syncShaders) ?? false
        syncResourcePacks = try container.decodeIfPresent(Bool.self, forKey: .syncResourcePacks) ?? true
        canEdit = try container.decodeIfPresent(Bool.self, forKey: .canEdit) ?? false
    }
}

/// Outcome of a join_lobby call.
public enum LobbyJoinOutcome: Sendable, Equatable {
    case ok(JoinedLobby)
    case notFound
    case closed
    case forbidden
    case full
    case nickTaken
    case notReady
    /// Too many wrong join codes within a minute.
    case rateLimited
}

/// A single row of a lobby's roster.
public struct LobbyMember: Codable, Sendable, Identifiable, Equatable {
    public let userID: String
    public let nick: String
    public let state: String
    public let canEdit: Bool

    public var id: String { userID }

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case nick
        case state
        case canEdit = "can_edit"
    }

    public init(userID: String, nick: String, state: String, canEdit: Bool = false) {
        self.userID = userID
        self.nick = nick
        self.state = state
        self.canEdit = canEdit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(String.self, forKey: .userID)
        nick = try container.decode(String.self, forKey: .nick)
        state = try container.decode(String.self, forKey: .state)
        canEdit = try container.decodeIfPresent(Bool.self, forKey: .canEdit) ?? false
    }
}

/// A joined lobby member's public profile tag and display name, as returned by lobby_roster_tags.
public struct LobbyMemberTag: Codable, Sendable, Equatable {
    public let userID: String
    public let tag: String
    public let displayName: String

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case tag
        case displayName = "display_name"
    }

    public init(userID: String, tag: String, displayName: String) {
        self.userID = userID
        self.tag = tag
        self.displayName = displayName
    }

    // Profile fields may be null for incomplete profiles; decode those as empty strings.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(String.self, forKey: .userID)
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
    }
}

/// A row of the visible_lobbies listing.
public struct VisibleLobby: Codable, Sendable, Identifiable, Equatable {
    public let lobbyID: String
    public let name: String
    public let mcVersion: String
    public let loader: String
    public let hostUser: String
    public let hostTag: String
    public let hostName: String
    public let players: Int
    public let maxPlayers: Int
    public let invited: Bool
    public let ready: Bool
    public let running: Bool

    public var id: String { lobbyID }

    private enum CodingKeys: String, CodingKey {
        case lobbyID = "lobby_id"
        case name
        case mcVersion = "mc_version"
        case loader
        case hostUser = "host_user"
        case hostTag = "host_tag"
        case hostName = "host_name"
        case players
        case maxPlayers = "max_players"
        case invited
        case ready
        case running
    }

    public init(
        lobbyID: String,
        name: String,
        mcVersion: String,
        loader: String,
        hostUser: String,
        hostTag: String,
        hostName: String,
        players: Int,
        maxPlayers: Int,
        invited: Bool,
        ready: Bool,
        running: Bool = false
    ) {
        self.lobbyID = lobbyID
        self.name = name
        self.mcVersion = mcVersion
        self.loader = loader
        self.hostUser = hostUser
        self.hostTag = hostTag
        self.hostName = hostName
        self.players = players
        self.maxPlayers = maxPlayers
        self.invited = invited
        self.ready = ready
        self.running = running
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lobbyID = try container.decode(String.self, forKey: .lobbyID)
        name = try container.decode(String.self, forKey: .name)
        mcVersion = try container.decode(String.self, forKey: .mcVersion)
        loader = try container.decode(String.self, forKey: .loader)
        hostUser = try container.decode(String.self, forKey: .hostUser)
        hostTag = try container.decode(String.self, forKey: .hostTag)
        hostName = try container.decode(String.self, forKey: .hostName)
        players = try container.decode(Int.self, forKey: .players)
        maxPlayers = try container.decode(Int.self, forKey: .maxPlayers)
        invited = try container.decode(Bool.self, forKey: .invited)
        ready = try container.decode(Bool.self, forKey: .ready)
        running = try container.decodeIfPresent(Bool.self, forKey: .running) ?? false
    }
}

/// The kind of content tracked in a lobby's item list.
public enum LobbyItemKind: String, Codable, Sendable, CaseIterable {
    case mod
    case shader
    case resourcepack
}

/// A single mod/shader/resource pack entry in a lobby's content list.
public struct LobbyItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let kind: LobbyItemKind
    public let projectID: String?
    public let versionID: String
    public let title: String
    public let addedBy: String?
    public let addedNick: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case projectID = "project_id"
        case versionID = "version_id"
        case title
        case addedBy = "added_by"
        case addedNick = "added_nick"
    }

    public init(
        id: String,
        kind: LobbyItemKind,
        projectID: String?,
        versionID: String,
        title: String,
        addedBy: String?,
        addedNick: String?
    ) {
        self.id = id
        self.kind = kind
        self.projectID = projectID
        self.versionID = versionID
        self.title = title
        self.addedBy = addedBy
        self.addedNick = addedNick
    }
}

/// Full snapshot of a lobby's room state, as returned by lobby_info.
public struct LobbyInfo: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let mcVersion: String
    public let loader: String
    public let host: String
    public let status: String
    public let maxPlayers: Int
    public let editPolicy: LobbyEditPolicy
    public let syncShaders: Bool
    public let syncResourcePacks: Bool
    public let canEdit: Bool
    public let address: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case mcVersion = "mc_version"
        case loader
        case host
        case status
        case maxPlayers = "max_players"
        case editPolicy = "edit_policy"
        case syncShaders = "sync_shaders"
        case syncResourcePacks = "sync_resourcepacks"
        case canEdit = "can_edit"
        case address
    }

    public init(
        id: String,
        name: String,
        mcVersion: String,
        loader: String,
        host: String,
        status: String,
        maxPlayers: Int,
        editPolicy: LobbyEditPolicy,
        syncShaders: Bool,
        syncResourcePacks: Bool,
        canEdit: Bool,
        address: String?
    ) {
        self.id = id
        self.name = name
        self.mcVersion = mcVersion
        self.loader = loader
        self.host = host
        self.status = status
        self.maxPlayers = maxPlayers
        self.editPolicy = editPolicy
        self.syncShaders = syncShaders
        self.syncResourcePacks = syncResourcePacks
        self.canEdit = canEdit
        self.address = address
    }
}

/// Outcome of add_lobby_item / remove_lobby_item.
public enum LobbyItemResult: String, Sendable {
    case ok
    case forbidden
    case locked
    case limit
    case duplicate
    case invalid
    case notFound = "not_found"
}

/// A single pending WebRTC signaling message for the tunnel handshake.
public struct TunnelSignal: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let from: String
    public let payload: String

    private enum CodingKeys: String, CodingKey {
        case id
        case from = "from_user"
        case payload
    }

    public init(id: Int, from: String, payload: String) {
        self.id = id
        self.from = from
        self.payload = payload
    }
}
