import Foundation

/// Tunnel signaling for one lobby, backed by the Ember lobby RPCs.
public struct EmberLobbySignaling: TunnelSignaling {
    private let lobbies: EmberLobbies
    private let lobby: String
    private let sessionProvider: @Sendable () async -> EmberSession?

    public init(
        lobby: String,
        lobbies: EmberLobbies = EmberLobbies(),
        sessionProvider: @escaping @Sendable () async -> EmberSession?
    ) {
        self.lobby = lobby
        self.lobbies = lobbies
        self.sessionProvider = sessionProvider
    }

    public func post(to user: String, payload: String) async throws {
        guard let session = await sessionProvider() else { throw TunnelError.closed }
        try await lobbies.postSignal(lobby: lobby, to: user, payload: payload, session: session)
    }

    public func fetch(after: Int) async throws -> [TunnelSignalMessage] {
        guard let session = await sessionProvider() else { throw TunnelError.closed }
        let signals = try await lobbies.fetchSignals(lobby: lobby, after: after, session: session)
        return signals.map { TunnelSignalMessage(id: $0.id, from: $0.from, payload: $0.payload) }
    }
}
