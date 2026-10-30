import AppKit
import SwiftUI
import LauncherCore

/// The Ember account (Supabase): session in the Keychain, profile row cached in memory.
/// Signing in is optional; without it the launcher works as before.
@MainActor
final class EmberAccountStore: ObservableObject {
    static let shared = EmberAccountStore()

    enum Phase: Equatable {
        case idle
        case working
        case notice(String)
        case failed(String)
    }

    private static let keychainKey = "ember.session"

    @Published private(set) var session: EmberSession?
    @Published private(set) var profile: EmberProfile?
    @Published private(set) var phase: Phase = .idle

    private let auth = EmberAuth()
    private var task: Task<Void, Never>?

    private init() {
        if let json = KeychainStore.read(Self.keychainKey), let data = json.data(using: .utf8) {
            session = try? JSONDecoder().decode(EmberSession.self, from: data)
        }
    }

    var isConfigured: Bool { EmberBackend.isConfigured }
    var isSignedIn: Bool { session != nil }

    // MARK: - Sign in and out

    func signIn(email: String, password: String) {
        run { [self] in
            let new = try await auth.signIn(email: email.trimmed, password: password)
            await finishSignIn(new)
        }
    }

    func signUp(email: String, password: String, tag: String, displayName: String) {
        run { [self] in
            let result = try await auth.signUp(email: email.trimmed, password: password, tag: tag.trimmed.lowercased(), displayName: displayName.trimmed)
            switch result {
            case .signedIn(let new): await finishSignIn(new)
            case .confirmationRequired: phase = .notice(L("Check your email and confirm the address, then sign in."))
            }
        }
    }

    func signIn(with provider: EmberOAuthProvider) {
        run { [self] in
            let (url, verifier) = try auth.oauthStart(provider: provider, redirectURI: OAuthLoopback.redirectURL)
            let waiting = Task { try await OAuthLoopback.waitForCode() }
            NSWorkspace.shared.open(url)
            let code = try await waiting.value
            await finishSignIn(try await auth.oauthFinish(code: code, verifier: verifier))
        }
    }

    func resetPassword(email: String) {
        run { [self] in
            try await auth.sendPasswordReset(email: email.trimmed)
            phase = .notice(L("If the address exists, a reset link is on its way."))
        }
    }

    func cancel() {
        task?.cancel()
        phase = .idle
    }

    func signOut() {
        if let current = session { Task { await auth.signOut(current) } }
        session = nil
        profile = nil
        KeychainStore.remove(Self.keychainKey)
        phase = .idle
    }

    func clearMessage() {
        if phase != .working { phase = .idle }
    }

    // MARK: - Profile

    func loadProfile() async {
        guard let current = await validSession() else { return }
        profile = try? await auth.fetchProfile(current)
    }

    func save(_ update: EmberProfileUpdate) {
        run { [self] in
            guard let current = await validSession() else { return }
            profile = try await auth.updateProfile(current, update)
            phase = .idle
        }
    }

    func isTagAvailable(_ tag: String) async -> Bool {
        (try? await auth.isTagAvailable(tag.trimmed.lowercased())) ?? false
    }

    // MARK: - Internals

    private func finishSignIn(_ new: EmberSession) async {
        store(new)
        profile = try? await auth.fetchProfile(new)
        phase = .idle
    }

    /// The session, refreshed when it is about to expire. A failed refresh signs out.
    private func validSession() async -> EmberSession? {
        guard var current = session else { return nil }
        if current.isExpired {
            do {
                current = try await auth.refresh(current)
                store(current)
            } catch {
                signOut()
                phase = .failed(L("Your Ember session expired. Sign in again."))
                return nil
            }
        }
        return current
    }

    private func store(_ value: EmberSession) {
        session = value
        if let data = try? JSONEncoder().encode(value), let json = String(data: data, encoding: .utf8) {
            KeychainStore.save(json, account: Self.keychainKey)
        }
    }

    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        guard phase != .working else { return }
        phase = .working
        task = Task {
            do {
                try await work()
                if phase == .working { phase = .idle }
            } catch is CancellationError {
                phase = .idle
            } catch EmberAuthError.cancelled {
                phase = .idle
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
