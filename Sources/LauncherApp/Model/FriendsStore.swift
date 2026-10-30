import Foundation
import LauncherCore

/// Friends list, requests and presence heartbeat, backed by the Ember friends service.
@MainActor
final class FriendsStore: ObservableObject {
    static let shared = FriendsStore()

    @Published private(set) var entries: [FriendEntry] = []
    @Published private(set) var isLoading = false
    @Published var message: String?

    private let friends = EmberFriends()
    private var loop: Task<Void, Never>?

    private init() {}

    // MARK: - Derived lists

    /// Friends sorted online-first, then alphabetically by display name.
    var friendsList: [FriendEntry] {
        entries
            .filter { $0.relation == .friend }
            .sorted { lhs, rhs in
                if lhs.online != rhs.online { return lhs.online }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    var incoming: [FriendEntry] {
        entries.filter { $0.relation == .incoming }
    }

    var outgoing: [FriendEntry] {
        entries.filter { $0.relation == .outgoing }
    }

    var onlineCount: Int {
        entries.filter { $0.relation == .friend && $0.online }.count
    }

    // MARK: - Lifecycle

    /// Starts the presence/refresh loop. Calling this again while it is running has no effect.
    func start(activity: @escaping @MainActor () -> String?) {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                var pause = 5
                if let session = await EmberAccountStore.shared.validSession() {
                    try? await self.friends.heartbeat(activity: activity(), session: session)
                    await self.loadOverview(session: session)
                    pause = 30
                } else if !self.entries.isEmpty {
                    self.entries = []
                }

                try? await Task.sleep(for: .seconds(pause))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        entries = []
    }

    /// Manual, one-off reload (e.g. after opening the friends panel).
    func refresh() async {
        guard let session = await EmberAccountStore.shared.validSession() else {
            entries = []
            return
        }
        await loadOverview(session: session)
    }

    // MARK: - Actions

    func sendRequest(tag: String) {
        let cleaned = tag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .removingLeadingAt()
            .lowercased()

        Task {
            guard let session = await EmberAccountStore.shared.validSession() else { return }
            do {
                let result = try await friends.sendRequest(tag: cleaned, session: session)
                message = Self.message(for: result)
            } catch {
                message = L("Could not reach the friends service.")
            }
            await refresh()
        }
    }

    func accept(_ entry: FriendEntry) {
        Task {
            guard let session = await EmberAccountStore.shared.validSession() else { return }
            do {
                _ = try await friends.respond(userID: entry.userID, accept: true, session: session)
            } catch {
                message = L("Could not reach the friends service.")
            }
            await refresh()
        }
    }

    func decline(_ entry: FriendEntry) {
        Task {
            guard let session = await EmberAccountStore.shared.validSession() else { return }
            do {
                _ = try await friends.respond(userID: entry.userID, accept: false, session: session)
            } catch {
                message = L("Could not reach the friends service.")
            }
            await refresh()
        }
    }

    /// Removes a friend, or cancels an outgoing request.
    func remove(_ entry: FriendEntry) {
        Task {
            guard let session = await EmberAccountStore.shared.validSession() else { return }
            do {
                try await friends.remove(userID: entry.userID, session: session)
            } catch {
                message = L("Could not reach the friends service.")
            }
            await refresh()
        }
    }

    // MARK: - Internals

    private func loadOverview(session: EmberSession) async {
        isLoading = true
        do {
            entries = try await friends.overview(session: session)
        } catch {
            message = L("Could not reach the friends service.")
        }
        isLoading = false
    }

    private static func message(for result: FriendRequestResult) -> String {
        switch result {
        case .sent: return L("Request sent.")
        case .accepted: return L("You are now friends.")
        case .notFound: return L("No Ember user with that tag.")
        case .closed: return L("This user does not accept requests.")
        case .exists: return L("You already have a request or friendship with this user.")
        case .selfRequest: return L("That is your own tag.")
        case .limit: return L("Too many pending requests.")
        }
    }
}

private extension String {
    /// Strips a single leading "@" if the tag was typed like a handle.
    func removingLeadingAt() -> String {
        hasPrefix("@") ? String(dropFirst()) : self
    }
}
