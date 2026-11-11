import Foundation

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

    public func rosterTags(lobby: String, session: EmberSession) async throws -> [LobbyMemberTag] {
        let data = try await auth.perform(
            path: "rest/v1/rpc/lobby_roster_tags",
            method: "POST",
            body: try JSONEncoder().encode(LobbyBody(lobby: lobby)),
            session: session,
            prefer: nil
        )
        return try Self.decodeRosterTags(data)
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
        case "rate_limited":
            return .rateLimited
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

    /// Decodes a lobby_roster_tags response.
    public static func decodeRosterTags(_ data: Data) throws -> [LobbyMemberTag] {
        do {
            return try JSONDecoder().decode([LobbyMemberTag].self, from: data)
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
