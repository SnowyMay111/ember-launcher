import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

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

/// A URLSession-based client for Ember authentication and profiles.
public struct EmberAuth: @unchecked Sendable {
    private let urlSession: URLSession

    public init(session: URLSession = .shared) {
        self.urlSession = session
    }

    public func signUp(
        email: String,
        password: String,
        tag: String,
        displayName: String
    ) async throws -> EmberSignUpResult {
        let body = SignUpRequest(
            email: email,
            password: password,
            data: SignUpMetadata(
                tag: tag.lowercased(),
                displayName: displayName
            )
        )
        let data = try await perform(
            path: "auth/v1/signup",
            method: "POST",
            body: try encode(body),
            session: nil,
            prefer: nil
        )
        let payload = try decode(AuthPayload.self, from: data)

        if payload.accessToken != nil {
            return .signedIn(try makeSession(from: payload))
        }

        return .confirmationRequired
    }

    public func signIn(email: String, password: String) async throws -> EmberSession {
        let body = PasswordRequest(email: email, password: password)
        let data = try await perform(
            path: "auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: try encode(body),
            session: nil,
            prefer: nil
        )
        return try makeSession(from: decode(AuthPayload.self, from: data))
    }

    public func refresh(_ session: EmberSession) async throws -> EmberSession {
        let body = RefreshRequest(refreshToken: session.refreshToken)
        let data = try await perform(
            path: "auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: try encode(body),
            session: nil,
            prefer: nil
        )
        return try makeSession(from: decode(AuthPayload.self, from: data))
    }

    public func signOut(_ session: EmberSession) async {
        _ = try? await perform(
            path: "auth/v1/logout",
            method: "POST",
            body: nil,
            session: session,
            prefer: nil
        )
    }

    public func sendPasswordReset(email: String) async throws {
        let body = EmailRequest(email: email)
        _ = try await perform(
            path: "auth/v1/recover",
            method: "POST",
            body: try encode(body),
            session: nil,
            prefer: nil
        )
    }

    public func isTagAvailable(_ tag: String) async throws -> Bool {
        let body = TagAvailabilityRequest(tag: tag)
        let data = try await perform(
            path: "rest/v1/rpc/tag_available",
            method: "POST",
            body: try encode(body),
            session: nil,
            prefer: nil
        )
        return try decode(Bool.self, from: data)
    }

    public func oauthStart(
        provider: EmberOAuthProvider,
        redirectURI: URL
    ) throws -> (url: URL, verifier: String) {
        let verifier = makeVerifier()
        let challenge = makeChallenge(for: verifier)
        let url = try endpointURL(
            path: "auth/v1/authorize",
            queryItems: [
                URLQueryItem(name: "provider", value: provider.rawValue),
                URLQueryItem(name: "redirect_to", value: redirectURI.absoluteString),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "s256")
            ]
        )
        return (url, verifier)
    }

    public func oauthFinish(code: String, verifier: String) async throws -> EmberSession {
        let body = PKCERequest(authCode: code, codeVerifier: verifier)
        let data = try await perform(
            path: "auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "pkce")],
            body: try encode(body),
            session: nil,
            prefer: nil
        )
        return try makeSession(from: decode(AuthPayload.self, from: data))
    }

    public func fetchProfile(_ session: EmberSession) async throws -> EmberProfile? {
        let queryItems = [
            URLQueryItem(name: "id", value: "eq.\(session.userID)"),
            URLQueryItem(name: "select", value: "*")
        ]

        for attempt in 0..<3 {
            let data = try await perform(
                path: "rest/v1/profiles",
                method: "GET",
                queryItems: queryItems,
                body: nil,
                session: session,
                prefer: nil
            )
            let profiles = try decode([EmberProfile].self, from: data)

            if let profile = profiles.first {
                return profile
            }

            if attempt < 2 {
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch {
                    throw EmberAuthError.cancelled
                }
            }
        }

        return nil
    }

    public func updateProfile(
        _ session: EmberSession,
        _ update: EmberProfileUpdate
    ) async throws -> EmberProfile {
        let queryItems = [
            URLQueryItem(name: "id", value: "eq.\(session.userID)")
        ]
        let data = try await perform(
            path: "rest/v1/profiles",
            method: "PATCH",
            queryItems: queryItems,
            body: try encode(update),
            session: session,
            prefer: "return=representation"
        )
        let profiles = try decode([EmberProfile].self, from: data)

        guard let profile = profiles.first else {
            throw EmberAuthError.invalidResponse
        }

        return profile
    }

    private func perform(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data?,
        session: EmberSession?,
        prefer: String?
    ) async throws -> Data {
        let url = try endpointURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(EmberBackend.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LauncherInfo.userAgent, forHTTPHeaderField: "User-Agent")
        // A publishable key is not a JWT, so it goes in `apikey` only; Bearer is for a signed-in user's token.
        if let token = session?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EmberAuthError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw makeError(status: httpResponse.statusCode, data: data)
            }

            return data
        } catch is CancellationError {
            throw EmberAuthError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw EmberAuthError.cancelled
        }
    }

    private func endpointURL(
        path: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        guard EmberBackend.isConfigured, let baseURL = EmberBackend.baseURL else {
            throw EmberAuthError.notConfigured
        }

        let pathURL = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(
            url: pathURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw EmberAuthError.invalidResponse
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw EmberAuthError.invalidResponse
        }

        return url
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw EmberAuthError.invalidResponse
        }
    }

    private func makeSession(from payload: AuthPayload) throws -> EmberSession {
        guard
            let accessToken = payload.accessToken,
            !accessToken.isEmpty,
            let refreshToken = payload.refreshToken,
            let user = payload.user,
            !user.id.isEmpty
        else {
            throw EmberAuthError.invalidResponse
        }

        let expiresAt: Date
        if let timestamp = payload.expiresAt {
            expiresAt = Date(timeIntervalSince1970: timestamp)
        } else if let seconds = payload.expiresIn {
            expiresAt = Date().addingTimeInterval(seconds)
        } else {
            throw EmberAuthError.invalidResponse
        }

        return EmberSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            userID: user.id,
            email: user.email
        )
    }

    private func makeError(status: Int, data: Data) -> EmberAuthError {
        let payload = try? JSONDecoder().decode(ErrorPayload.self, from: data)
        let errorCode = payload?.errorCode?.lowercased()
        let postgresCode = payload?.code?.lowercased()
        let message = payload?.message
            ?? payload?.msg
            ?? payload?.errorDescription
            ?? payload?.error
            ?? "Request failed."

        if status == 429
            || errorCode == "over_request_rate_limit"
            || errorCode == "over_email_send_rate_limit" {
            return .rateLimited
        }

        if status == 409 || postgresCode == "23505" {
            return .tagTaken
        }

        switch errorCode {
        case "invalid_credentials":
            return .invalidCredentials
        case "email_not_confirmed":
            return .emailNotConfirmed
        case "user_already_exists", "email_exists":
            return .emailTaken
        case "weak_password":
            return .weakPassword(message)
        default:
            return .http(status, message)
        }
    }

    private func makeVerifier() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_" .utf8)
        var generator = SystemRandomNumberGenerator()
        var bytes = [UInt8]()
        bytes.reserveCapacity(64)

        for _ in 0..<64 {
            let index = Int.random(in: 0..<alphabet.count, using: &generator)
            bytes.append(alphabet[index])
        }

        return String(decoding: bytes, as: UTF8.self)
    }

    private func makeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)

        #if canImport(CryptoKit)
        let digest = Data(SHA256.hash(data: data))
        #else
        let digest = Data(fallbackSHA256(data))
        #endif

        return digest
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct SignUpRequest: Encodable, Sendable {
    let email: String
    let password: String
    let data: SignUpMetadata
}

private struct SignUpMetadata: Encodable, Sendable {
    let tag: String
    let displayName: String

    private enum CodingKeys: String, CodingKey {
        case tag
        case displayName = "display_name"
    }
}

private struct PasswordRequest: Encodable, Sendable {
    let email: String
    let password: String
}

private struct RefreshRequest: Encodable, Sendable {
    let refreshToken: String

    private enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct EmailRequest: Encodable, Sendable {
    let email: String
}

private struct TagAvailabilityRequest: Encodable, Sendable {
    let tag: String

    private enum CodingKeys: String, CodingKey {
        case tag = "t"
    }
}

private struct PKCERequest: Encodable, Sendable {
    let authCode: String
    let codeVerifier: String

    private enum CodingKeys: String, CodingKey {
        case authCode = "auth_code"
        case codeVerifier = "code_verifier"
    }
}

private struct AuthPayload: Decodable, Sendable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Double?
    let expiresAt: Double?
    let user: AuthUser?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case user
    }
}

private struct AuthUser: Decodable, Sendable {
    let id: String
    let email: String?
}

private struct ErrorPayload: Decodable, Sendable {
    let errorCode: String?
    let msg: String?
    let message: String?
    let errorDescription: String?
    let error: String?
    let code: String?

    private enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case msg
        case message
        case errorDescription = "error_description"
        case error
        case code
    }
}

#if !canImport(CryptoKit)
private func fallbackSHA256(_ data: Data) -> [UInt8] {
    let constants: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]

    var bytes = Array(data)
    let bitLength = UInt64(bytes.count) * 8
    bytes.append(0x80)

    while bytes.count % 64 != 56 {
        bytes.append(0)
    }

    for shift in stride(from: 56, through: 0, by: -8) {
        bytes.append(UInt8((bitLength >> UInt64(shift)) & 0xff))
    }

    var hash: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]

    for chunkStart in stride(from: 0, to: bytes.count, by: 64) {
        var words = Array(repeating: UInt32(0), count: 64)

        for index in 0..<16 {
            let offset = chunkStart + index * 4
            words[index] =
                UInt32(bytes[offset]) << 24
                | UInt32(bytes[offset + 1]) << 16
                | UInt32(bytes[offset + 2]) << 8
                | UInt32(bytes[offset + 3])
        }

        for index in 16..<64 {
            let value1 = rotateRight(words[index - 15], by: 7)
                ^ rotateRight(words[index - 15], by: 18)
                ^ (words[index - 15] >> 3)
            let value2 = rotateRight(words[index - 2], by: 17)
                ^ rotateRight(words[index - 2], by: 19)
                ^ (words[index - 2] >> 10)
            words[index] = words[index - 16]
                &+ value1
                &+ words[index - 7]
                &+ value2
        }

        var a = hash[0]
        var b = hash[1]
        var c = hash[2]
        var d = hash[3]
        var e = hash[4]
        var f = hash[5]
        var g = hash[6]
        var h = hash[7]

        for index in 0..<64 {
            let sum1 = rotateRight(e, by: 6)
                ^ rotateRight(e, by: 11)
                ^ rotateRight(e, by: 25)
            let choice = (e & f) ^ ((~e) & g)
            let temporary1 = h &+ sum1 &+ choice &+ constants[index] &+ words[index]
            let sum2 = rotateRight(a, by: 2)
                ^ rotateRight(a, by: 13)
                ^ rotateRight(a, by: 22)
            let majority = (a & b) ^ (a & c) ^ (b & c)
            let temporary2 = sum2 &+ majority

            h = g
            g = f
            f = e
            e = d &+ temporary1
            d = c
            c = b
            b = a
            a = temporary1 &+ temporary2
        }

        hash[0] = hash[0] &+ a
        hash[1] = hash[1] &+ b
        hash[2] = hash[2] &+ c
        hash[3] = hash[3] &+ d
        hash[4] = hash[4] &+ e
        hash[5] = hash[5] &+ f
        hash[6] = hash[6] &+ g
        hash[7] = hash[7] &+ h
    }

    var result = [UInt8]()
    result.reserveCapacity(32)

    for value in hash {
        result.append(UInt8((value >> 24) & 0xff))
        result.append(UInt8((value >> 16) & 0xff))
        result.append(UInt8((value >> 8) & 0xff))
        result.append(UInt8(value & 0xff))
    }

    return result
}

private func rotateRight(_ value: UInt32, by amount: UInt32) -> UInt32 {
    (value >> amount) | (value << (32 - amount))
}
#endif
