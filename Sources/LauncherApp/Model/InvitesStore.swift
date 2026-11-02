import Combine
import Foundation
import LauncherCore

/// Lobby invitations derived from LobbyStore's visible list, with per-Mac "Later" and seen state.
@MainActor
final class InvitesStore: ObservableObject {
    static let shared = InvitesStore()

    @Published private(set) var invites: [VisibleLobby] = []
    @Published private(set) var unseenCount = 0
    @Published private(set) var latestNew: VisibleLobby?

    private static let dismissedKey = "ember.dismissedInvites"
    private static let seenKey = "ember.seenInvites"
    private static let limit = 100

    private var dismissed: [String]
    private var seen: [String]
    private var lastVisible: [VisibleLobby] = []
    private var previousIDs: Set<String> = []
    private var snapshots = 0
    private var cancellable: AnyCancellable?

    private init() {
        dismissed = UserDefaults.standard.stringArray(forKey: Self.dismissedKey) ?? []
        seen = UserDefaults.standard.stringArray(forKey: Self.seenKey) ?? []
        cancellable = LobbyStore.shared.$visible.sink { [weak self] visible in
            self?.apply(visible)
        }
    }

    /// "Later": hides the invite on this Mac. It returns only as a new lobby id.
    func dismiss(_ lobbyID: String) {
        dismissed = SocialLogic.trimmed(dismissed + [lobbyID], limit: Self.limit)
        UserDefaults.standard.set(dismissed, forKey: Self.dismissedKey)
        if latestNew?.lobbyID == lobbyID { latestNew = nil }
        recompute()
    }

    func markAllSeen() {
        seen = SocialLogic.trimmed(seen + invites.map(\.lobbyID), limit: Self.limit)
        UserDefaults.standard.set(seen, forKey: Self.seenKey)
        recompute()
    }

    func consumeLatestNew() {
        latestNew = nil
    }

    private func apply(_ visible: [VisibleLobby]) {
        snapshots += 1
        lastVisible = visible
        recompute()
        // The first snapshot after launch must not toast, so only react once a prior
        // snapshot already ran.
        if snapshots > 1 {
            let fresh = invites.first { !previousIDs.contains($0.lobbyID) }
            if let fresh { latestNew = fresh }
        }
        previousIDs = Set(invites.map(\.lobbyID))
    }

    private func recompute() {
        let dismissedSet = Set(dismissed)
        invites = lastVisible.filter { $0.invited && !dismissedSet.contains($0.lobbyID) }
        unseenCount = SocialLogic.unseenInvites(
            current: invites.map(\.lobbyID),
            seen: Set(seen),
            dismissed: dismissedSet
        ).count
    }
}
/*
=== END ===
*/
