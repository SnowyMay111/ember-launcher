import SwiftUI
import LauncherCore

/// Microsoft sign-in state. The session (with its refresh token) lives in the Keychain only.
/// Without a session the launcher plays offline with the nickname from settings.
@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    enum Phase: Equatable {
        case idle
        case waitingForCode(userCode: String, url: URL)
        case failed(String)
    }

    private static let keychainKey = "microsoft.session"

    @Published private(set) var session: MicrosoftSession?
    @Published private(set) var phase: Phase = .idle

    private let auth = MicrosoftAuth()
    private var signInTask: Task<Void, Never>?

    private init() {
        if let json = KeychainStore.read(Self.keychainKey), let data = json.data(using: .utf8) {
            session = try? JSONDecoder().decode(MicrosoftSession.self, from: data)
        }
    }

    var isSignedIn: Bool { session != nil }

    func signIn() {
        guard signInTask == nil else { return }
        phase = .idle
        signInTask = Task {
            defer { signInTask = nil }
            do {
                let result = try await auth.signIn { [weak self] prompt in
                    Task { @MainActor in self?.phase = .waitingForCode(userCode: prompt.userCode, url: prompt.verificationURL) }
                }
                store(result)
                phase = .idle
            } catch MicrosoftAuthError.cancelled {
                phase = .idle
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
        phase = .idle
    }

    func signOut() {
        session = nil
        KeychainStore.remove(Self.keychainKey)
        phase = .idle
    }

    /// The account to launch with: the Microsoft one (refreshed when it is about to expire), else the offline nickname.
    /// A failed refresh falls back to offline and tells the caller why in `warning`.
    func launchAccount(offlineName: String) async throws -> (account: MinecraftAccount, warning: String?) {
        guard var current = session else {
            return (MinecraftAccount(offline: try OfflineAccount(name: offlineName)), nil)
        }
        if current.isExpired {
            do {
                current = try await auth.refresh(current)
                store(current)
            } catch {
                let offline = MinecraftAccount(offline: try OfflineAccount(name: offlineName))
                return (offline, L("Microsoft sign-in expired: %@. Playing offline.", error.localizedDescription))
            }
        }
        return (current.account, nil)
    }

    private func store(_ value: MicrosoftSession) {
        session = value
        if let data = try? JSONEncoder().encode(value), let json = String(data: data, encoding: .utf8) {
            KeychainStore.save(json, account: Self.keychainKey)
        }
    }
}
