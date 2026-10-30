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

/// Client for the Ember lobby system: hosting, joining, roster, discovery.
public struct EmberLobbies: Sendable {
    private let auth: EmberAuth

    public init(auth: EmberAuth = EmberAuth()) {
        self.auth = auth
    }

    public func create(_ request: LobbyCreateRequest, session: EmberSession) async throws -> CreatedLobby {
        let data = try await auth.perform(
            path: "rest/v1/rpc/create_lobby",
            method: "POST",
            body: try JSONEncoder().encode(request),
            session: session,
            prefer: nil
        )
        return try Self.decodeCreate(data)
    }

    public func setAddress(lobby: String, address: String, session: EmberSession) async throws {
        _ = try await auth.perform(
            path: "rest/v1/rpc/set_lobby_address",
            method: "POST",
            body: try JSONEncoder().encode(SetAddressBody(lobby: lobby, address: address)),
            session: session,
            prefer: nil
        )
    }

    public func heartbeat(lobby: String, session: EmberSession) async throws {
        _ = try await auth.perform(
            path: "rest/v1/rpc/lobby_heartbeat",
            method: "POST",
            body: try JSONEncoder().encode(LobbyBody(lobby: lobby)),
            session: session,
            prefer: nil
        )
    }

    public func close(lobby: String, session: EmberSession) async throws {
        _ = try await auth.perform(
            path: "rest/v1/rpc/close_lobby",
            method: "POST",
            body: try JSONEncoder().encode(LobbyBody(lobby: lobby)),
            session: session,
            prefer: nil
        )
    }

    public func leave(lobby: String, session: EmberSession) async throws {
        _ = try await auth.perform(
            path: "rest/v1/rpc/leave_lobby",
            method: "POST",
            body: try JSONEncoder().encode(LobbyBody(lobby: lobby)),
            session: session,
            prefer: nil
        )
    }

    public func invite(lobby: String, user: String, session: EmberSession) async throws -> LobbyInviteResult {
        let data = try await auth.perform(
            path: "rest/v1/rpc/invite_to_lobby",
            method: "POST",
            body: try JSONEncoder().encode(InviteBody(lobby: lobby, user: user)),
            session: session,
            prefer: nil
        )
        guard
            let raw = try? JSONDecoder().decode(String.self, from: data),
            let result = LobbyInviteResult(rawValue: raw)
        else {
            throw EmberAuthError.invalidResponse
        }
        return result
    }

    public func join(
        code: String?,
        lobbyID: String?,
        nick: String,
        session: EmberSession
    ) async throws -> LobbyJoinOutcome {
        let data = try await auth.perform(
            path: "rest/v1/rpc/join_lobby",
            method: "POST",
            body: try JSONEncoder().encode(JoinLobbyBody(code: code, lobby: lobbyID, nick: nick)),
            session: session,
            prefer: nil
        )
        return try Self.decodeJoin(data)
    }

    public func roster(lobby: String, session: EmberSession) async throws -> [LobbyMember] {
        let data = try await auth.perform(
            path: "rest/v1/rpc/lobby_roster",
            method: "POST",
            body: try JSONEncoder().encode(LobbyBody(lobby: lobby)),
            session: session,
            prefer: nil
        )
        return try Self.decodeRoster(data)
    }

    public func visibleLobbies(session: EmberSession) async throws -> [VisibleLobby] {
        let data = try await auth.perform(
            path: "rest/v1/rpc/visible_lobbies",
            method: "POST",
            body: Data("{}".utf8),
            session: session,
            prefer: nil
        )
        return try Self.decodeVisible(data)
    }

    public func tunnelKey(lobby: String, session: EmberSession) async throws -> String? {
        let data = try await auth.perform(
            path: "rest/v1/rpc/lobby_tunnel_key",
            method: "POST",
            body: try JSONEncoder().encode(LobbyBody(lobby: lobby)),
            session: session,
            prefer: nil
        )
        return try Self.decodeTunnelKey(data)
    }

    public func postSignal(lobby: String, to user: String, payload: String, session: EmberSession) async throws {
        _ = try await auth.perform(
            path: "rest/v1/rpc/post_lobby_signal",
            method: "POST",
            body: try JSONEncoder().encode(PostSignalBody(lobby: lobby, to: user, payload: payload)),
            session: session,
            prefer: nil
        )
    }

    public func fetchSignals(lobby: String, after: Int, session: EmberSession) async throws -> [TunnelSignal] {
        let data = try await auth.perform(
            path: "rest/v1/rpc/fetch_lobby_signals",
            method: "POST",
            body: try JSONEncoder().encode(FetchSignalsBody(lobby: lobby, after: after)),
            session: session,
            prefer: nil
        )
        return try Self.decodeSignals(data)
    }

    public func info(lobby: String, session: EmberSession) async throws -> LobbyInfo? {
        let data = try await auth.perform(
            path: "rest/v1/rpc/lobby_info",
            method: "POST",
            body: try JSONEncoder().encode(LobbyBody(lobby: lobby)),
            session: session,
            prefer: nil
        )
        return try Self.decodeInfo(data)
    }

    public func items(lobby: String, session: EmberSession) async throws -> [LobbyItem] {
        let data = try await auth.perform(
            path: "rest/v1/rpc/lobby_items_list",
            method: "POST",
            body: try JSONEncoder().encode(LobbyBody(lobby: lobby)),
            session: session,
            prefer: nil
        )
        return try Self.decodeItems(data)
    }

    public func addItem(
        lobby: String,
        kind: LobbyItemKind,
        projectID: String?,
        versionID: String,
        title: String,
        session: EmberSession
    ) async throws -> LobbyItemResult {
        let data = try await auth.perform(
            path: "rest/v1/rpc/add_lobby_item",
            method: "POST",
            body: try JSONEncoder().encode(AddItemBody(
                lobby: lobby,
                kind: kind,
                projectID: projectID,
                versionID: versionID,
                title: title
            )),
            session: session,
            prefer: nil
        )
        return try Self.decodeItemResult(data)
    }

    public func removeItem(lobby: String, item: String, session: EmberSession) async throws -> LobbyItemResult {
        let data = try await auth.perform(
            path: "rest/v1/rpc/remove_lobby_item",
            method: "POST",
            body: try JSONEncoder().encode(RemoveItemBody(lobby: lobby, item: item)),
            session: session,
            prefer: nil
        )
        return try Self.decodeItemResult(data)
    }

    public func setSettings(
        lobby: String,
        editPolicy: LobbyEditPolicy,
        syncShaders: Bool,
        syncResourcePacks: Bool,
        session: EmberSession
    ) async throws {
        _ = try await auth.perform(
            path: "rest/v1/rpc/set_lobby_settings",
            method: "POST",
            body: try JSONEncoder().encode(SetSettingsBody(
                lobby: lobby,
                editPolicy: editPolicy,
                syncShaders: syncShaders,
                syncResourcePacks: syncResourcePacks
            )),
            session: session,
            prefer: nil
        )
    }

    public func setMemberCanEdit(lobby: String, user: String, can: Bool, session: EmberSession) async throws {
        _ = try await auth.perform(
            path: "rest/v1/rpc/set_member_can_edit",
            method: "POST",
            body: try JSONEncoder().encode(SetMemberCanEditBody(lobby: lobby, user: user, can: can)),
            session: session,
            prefer: nil
        )
    }

    public func reopen(lobby: String, session: EmberSession) async throws {
        _ = try await auth.perform(
            path: "rest/v1/rpc/reopen_lobby",
            method: "POST",
            body: try JSONEncoder().encode(LobbyBody(lobby: lobby)),
            session: session,
            prefer: nil
        )
    }

    // MARK: - Decoding helpers (public so tests can call them directly)

    /// Decodes a create_lobby response: an array with a single {lobby_id, code} row.
    public static func decodeCreate(_ data: Data) throws -> CreatedLobby {
        guard
            let rows = try? JSONDecoder().decode([CreatedLobby].self, from: data),
            let row = rows.first
        else {
            throw EmberAuthError.invalidResponse
        }
        return row
    }

    /// Decodes a join_lobby response: an array with a single {result, lobby} row.
    public static func decodeJoin(_ data: Data) throws -> LobbyJoinOutcome {
        struct Row: Decodable {
            let result: String
            let lobby: JoinedLobby?
        }

        guard
            let rows = try? JSONDecoder().decode([Row].self, from: data),
            let row = rows.first
        else {
            throw EmberAuthError.invalidResponse
        }

        switch row.result {
        case "ok":
            guard let lobby = row.lobby else { throw EmberAuthError.invalidResponse }
            return .ok(lobby)
        case "not_found":
            return .notFound
        case "closed":
            return .closed
        case "forbidden":
            return .forbidden
        case "full":
            return .full
        case "nick_taken":
            return .nickTaken
        case "not_ready":
            return .notReady
        default:
            throw EmberAuthError.invalidResponse
        }
    }

    /// Decodes a lobby_roster response.
    public static func decodeRoster(_ data: Data) throws -> [LobbyMember] {
        do {
            return try JSONDecoder().decode([LobbyMember].self, from: data)
        } catch {
            throw EmberAuthError.invalidResponse
        }
    }

    /// Decodes a visible_lobbies response.
    public static func decodeVisible(_ data: Data) throws -> [VisibleLobby] {
        do {
            return try JSONDecoder().decode([VisibleLobby].self, from: data)
        } catch {
            throw EmberAuthError.invalidResponse
        }
    }

    /// Decodes a lobby_tunnel_key response: a bare JSON string, or null when not allowed.
    public static func decodeTunnelKey(_ data: Data) throws -> String? {
        let decoded: String?
        do {
            decoded = try JSONDecoder().decode(String?.self, from: data)
        } catch {
            throw EmberAuthError.invalidResponse
        }
        guard let key = decoded, !key.isEmpty else {
            return nil
        }
        return key
    }

    /// Decodes a fetch_lobby_signals response.
    public static func decodeSignals(_ data: Data) throws -> [TunnelSignal] {
        do {
            return try JSONDecoder().decode([TunnelSignal].self, from: data)
        } catch {
            throw EmberAuthError.invalidResponse
        }
    }

    /// Decodes a lobby_info response: a jsonb object, or JSON null when not visible.
    public static func decodeInfo(_ data: Data) throws -> LobbyInfo? {
        do {
            return try JSONDecoder().decode(LobbyInfo?.self, from: data)
        } catch {
            throw EmberAuthError.invalidResponse
        }
    }

    /// Decodes a lobby_items_list response.
    public static func decodeItems(_ data: Data) throws -> [LobbyItem] {
        do {
            return try JSONDecoder().decode([LobbyItem].self, from: data)
        } catch {
            throw EmberAuthError.invalidResponse
        }
    }

    /// Decodes an add_lobby_item / remove_lobby_item response: a bare JSON string.
    public static func decodeItemResult(_ data: Data) throws -> LobbyItemResult {
        guard
            let raw = try? JSONDecoder().decode(String.self, from: data),
            let result = LobbyItemResult(rawValue: raw)
        else {
            throw EmberAuthError.invalidResponse
        }
        return result
    }
}

private struct LobbyBody: Encodable, Sendable {
    let lobby: String

    private enum CodingKeys: String, CodingKey {
        case lobby = "p_lobby"
    }
}

private struct SetAddressBody: Encodable, Sendable {
    let lobby: String
    let address: String

    private enum CodingKeys: String, CodingKey {
        case lobby = "p_lobby"
        case address = "p_address"
    }
}

private struct InviteBody: Encodable, Sendable {
    let lobby: String
    let user: String

    private enum CodingKeys: String, CodingKey {
        case lobby = "p_lobby"
        case user = "p_user"
    }
}

private struct JoinLobbyBody: Encodable, Sendable {
    let code: String?
    let lobby: String?
    let nick: String

    private enum CodingKeys: String, CodingKey {
        case code = "p_code"
        case lobby = "p_lobby"
        case nick = "p_nick"
    }

    // Encodes nil code/lobby as explicit JSON null rather than omitting the key.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let code {
            try container.encode(code, forKey: .code)
        } else {
            try container.encodeNil(forKey: .code)
        }
        if let lobby {
            try container.encode(lobby, forKey: .lobby)
        } else {
            try container.encodeNil(forKey: .lobby)
        }
        try container.encode(nick, forKey: .nick)
    }
}

private struct PostSignalBody: Encodable, Sendable {
    let lobby: String
    let to: String
    let payload: String

    private enum CodingKeys: String, CodingKey {
        case lobby = "p_lobby"
        case to = "p_to"
        case payload = "p_payload"
    }
}

private struct FetchSignalsBody: Encodable, Sendable {
    let lobby: String
    let after: Int

    private enum CodingKeys: String, CodingKey {
        case lobby = "p_lobby"
        case after = "p_after"
    }
}

private struct AddItemBody: Encodable, Sendable {
    let lobby: String
    let kind: LobbyItemKind
    let projectID: String?
    let versionID: String
    let title: String

    private enum CodingKeys: String, CodingKey {
        case lobby = "p_lobby"
        case kind = "p_kind"
        case projectID = "p_project"
        case versionID = "p_version"
        case title = "p_title"
    }

    // Encodes a nil project id as explicit JSON null rather than omitting the key.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lobby, forKey: .lobby)
        try container.encode(kind, forKey: .kind)
        if let projectID {
            try container.encode(projectID, forKey: .projectID)
        } else {
            try container.encodeNil(forKey: .projectID)
        }
        try container.encode(versionID, forKey: .versionID)
        try container.encode(title, forKey: .title)
    }
}

private struct RemoveItemBody: Encodable, Sendable {
    let lobby: String
    let item: String

    private enum CodingKeys: String, CodingKey {
        case lobby = "p_lobby"
        case item = "p_item"
    }
}

private struct SetSettingsBody: Encodable, Sendable {
    let lobby: String
    let editPolicy: LobbyEditPolicy
    let syncShaders: Bool
    let syncResourcePacks: Bool

    private enum CodingKeys: String, CodingKey {
        case lobby = "p_lobby"
        case editPolicy = "p_edit_policy"
        case syncShaders = "p_sync_shaders"
        case syncResourcePacks = "p_sync_resourcepacks"
    }
}

private struct SetMemberCanEditBody: Encodable, Sendable {
    let lobby: String
    let user: String
    let can: Bool

    private enum CodingKeys: String, CodingKey {
        case lobby = "p_lobby"
        case user = "p_user"
        case can = "p_can"
    }
}
