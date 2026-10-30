import Foundation

/// Errors that can occur while signing a Microsoft account in to Minecraft Java.
public enum MicrosoftAuthError: Error, LocalizedError, Sendable {
    case cancelled
    case expired
    case declined
    case xboxNoAccount
    case xboxCountry
    case notOwned
    case notApproved
    case http(Int, String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign-in was cancelled."
        case .expired:
            return "The device code expired before sign-in completed."
        case .declined:
            return "Sign-in was declined."
        case .xboxNoAccount:
            return "This Microsoft account has no Xbox profile."
        case .xboxCountry:
            return "Xbox Live is not available for this account's country, or it is a child account."
        case .notOwned:
            return "This account does not own Minecraft Java Edition."
        case .notApproved:
            return "This app has not yet been approved by Mojang."
        case .http(let code, let body):
            return "HTTP \(code): \(body)"
        case .invalidResponse:
            return "Received an invalid response from the server."
        }
    }
}

/// A device code the user must enter at a verification URL to complete sign-in.
public struct DeviceCodePrompt: Sendable {
    public let userCode: String
    public let verificationURL: URL
    public let expiresIn: Int

    public init(userCode: String, verificationURL: URL, expiresIn: Int) {
        self.userCode = userCode
        self.verificationURL = verificationURL
        self.expiresIn = expiresIn
    }
}

/// A completed Microsoft sign-in: the Minecraft profile plus the tokens needed to keep it alive.
public struct MicrosoftSession: Codable, Sendable, Equatable {
    public let name: String
    public let uuid: String
    public let minecraftToken: String
    public let minecraftExpiry: Date
    public let refreshToken: String

    public init(name: String, uuid: String, minecraftToken: String, minecraftExpiry: Date, refreshToken: String) {
        self.name = name
        self.uuid = uuid
        self.minecraftToken = minecraftToken
        self.minecraftExpiry = minecraftExpiry
        self.refreshToken = refreshToken
    }

    /// The account this session launches the game as.
    public var account: MinecraftAccount {
        MinecraftAccount(name: name, uuid: uuid, accessToken: minecraftToken, userType: "msa")
    }

    /// True once the Minecraft token is within 60 seconds of expiring.
    public var isExpired: Bool {
        minecraftExpiry.timeIntervalSinceNow < 60
    }
}

/// Signs a Microsoft account in to Minecraft Java using the OAuth2 device code flow,
/// then exchanges the Microsoft token for Xbox Live, XSTS and Minecraft tokens.
public struct MicrosoftAuth: Sendable {
    public static let clientID = "072a67cc-fcc2-45e6-be86-a62dd8893891"

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Starts the device code flow, calling `onPrompt` once the user needs to enter a code,
    /// then polls until sign-in completes, is declined, or the code expires.
    public func signIn(onPrompt: @escaping @Sendable (DeviceCodePrompt) -> Void) async throws -> MicrosoftSession {
        let deviceCode = try await requestDeviceCode()

        onPrompt(DeviceCodePrompt(
            userCode: deviceCode.userCode,
            verificationURL: deviceCode.url,
            expiresIn: deviceCode.expiresIn
        ))

        var interval = deviceCode.interval
        let deadline = Date().addingTimeInterval(TimeInterval(deviceCode.expiresIn))

        while true {
            if Task.isCancelled {
                throw MicrosoftAuthError.cancelled
            }
            if Date() >= deadline {
                throw MicrosoftAuthError.expired
            }

            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)

            if Task.isCancelled {
                throw MicrosoftAuthError.cancelled
            }

            switch try await pollDeviceCode(deviceCode.deviceCode) {
            case .success(let accessToken, let refreshToken):
                return try await chain(msaAccessToken: accessToken, refreshToken: refreshToken)
            case .pending:
                continue
            case .slowDown:
                interval += 5
            case .declined:
                throw MicrosoftAuthError.declined
            case .expired:
                throw MicrosoftAuthError.expired
            }
        }
    }

    /// Exchanges a stored refresh token for a fresh Minecraft session without user interaction.
    public func refresh(_ previous: MicrosoftSession) async throws -> MicrosoftSession {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "refresh_token", value: previous.refreshToken),
            URLQueryItem(name: "scope", value: "XboxLive.signin offline_access"),
        ]

        let response: TokenResponse = try await postForm(
            url: try endpoint("https://login.microsoftonline.com/consumers/oauth2/v2.0/token"),
            body: components.percentEncodedQuery ?? ""
        )

        return try await chain(msaAccessToken: response.accessToken, refreshToken: response.refreshToken)
    }

    // MARK: - Device code flow

    private struct DeviceCodeInfo {
        let deviceCode: String
        let userCode: String
        let url: URL
        let expiresIn: Int
        let interval: Int
    }

    private struct DeviceCodeResponse: Codable {
        let deviceCode: String
        let userCode: String
        let verificationUri: String
        let expiresIn: Int
        let interval: Int

        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationUri = "verification_uri"
            case expiresIn = "expires_in"
            case interval = "interval"
        }
    }

    /// Step 1: requests a device code and user code the user enters at a Microsoft verification page.
    private func requestDeviceCode() async throws -> DeviceCodeInfo {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "scope", value: "XboxLive.signin offline_access"),
        ]

        let response: DeviceCodeResponse = try await postForm(
            url: try endpoint("https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode"),
            body: components.percentEncodedQuery ?? ""
        )

        guard let url = URL(string: response.verificationUri) else {
            throw MicrosoftAuthError.invalidResponse
        }

        return DeviceCodeInfo(
            deviceCode: response.deviceCode,
            userCode: response.userCode,
            url: url,
            expiresIn: response.expiresIn,
            interval: response.interval
        )
    }

    private enum PollResult {
        case success(accessToken: String, refreshToken: String)
        case pending
        case slowDown
        case declined
        case expired
    }

    private struct TokenResponse: Codable {
        let accessToken: String
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
        }
    }

    private struct TokenErrorResponse: Codable {
        let error: String
    }

    /// Step 2: polls the token endpoint until the user approves, declines, or the code expires.
    private func pollDeviceCode(_ deviceCode: String) async throws -> PollResult {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:device_code"),
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "device_code", value: deviceCode),
        ]

        var request = URLRequest(url: try endpoint("https://login.microsoftonline.com/consumers/oauth2/v2.0/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Ember-Launcher", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MicrosoftAuthError.invalidResponse
        }

        if http.statusCode == 200 {
            let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
            return .success(accessToken: decoded.accessToken, refreshToken: decoded.refreshToken)
        }

        guard let errorResponse = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) else {
            throw MicrosoftAuthError.invalidResponse
        }

        switch errorResponse.error {
        case "authorization_pending":
            return .pending
        case "slow_down":
            return .slowDown
        case "authorization_declined":
            return .declined
        case "expired_token":
            return .expired
        default:
            throw MicrosoftAuthError.http(http.statusCode, errorResponse.error)
        }
    }

    // MARK: - Xbox / XSTS / Minecraft chain

    private struct XboxAuthResponse: Codable {
        let token: String
        let displayClaims: DisplayClaims

        struct DisplayClaims: Codable {
            let xui: [XuiEntry]
        }

        struct XuiEntry: Codable {
            let uhs: String
        }

        enum CodingKeys: String, CodingKey {
            case token = "Token"
            case displayClaims = "DisplayClaims"
        }
    }

    private struct XstsErrorResponse: Codable {
        let xErr: Int

        enum CodingKeys: String, CodingKey {
            case xErr = "XErr"
        }
    }

    private struct MinecraftLoginResponse: Codable {
        let accessToken: String
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
        }
    }

    private struct EntitlementsResponse: Codable {
        let items: [Item]

        struct Item: Codable {}
    }

    private struct ProfileResponse: Codable {
        let id: String
        let name: String
    }

    /// Exchanges a Microsoft access token for Xbox Live, then XSTS, then a Minecraft session,
    /// checking ownership and fetching the profile along the way.
    private func chain(msaAccessToken: String, refreshToken: String) async throws -> MicrosoftSession {
        // a. Xbox Live user authentication.
        let xblBody: [String: Any] = [
            "Properties": [
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": "d=\(msaAccessToken)",
            ],
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT",
        ]
        let xbl: XboxAuthResponse = try await postJSON(
            url: try endpoint("https://user.auth.xboxlive.com/user/authenticate"),
            json: xblBody
        )
        guard let uhs = xbl.displayClaims.xui.first?.uhs else {
            throw MicrosoftAuthError.invalidResponse
        }

        // b. XSTS authorization.
        let xstsBody: [String: Any] = [
            "Properties": [
                "SandboxId": "RETAIL",
                "UserTokens": [xbl.token],
            ],
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT",
        ]
        let xsts = try await requestXSTS(body: xstsBody)

        // c. Minecraft login via Xbox.
        let identityToken = "XBL3.0 x=\(uhs);\(xsts.token)"
        let minecraft: MinecraftLoginResponse
        do {
            minecraft = try await postJSON(
                url: try endpoint("https://api.minecraftservices.com/authentication/login_with_xbox"),
                json: ["identityToken": identityToken]
            )
        } catch MicrosoftAuthError.http(403, _) {
            throw MicrosoftAuthError.notApproved
        }

        // d. Ownership check.
        let entitlements: EntitlementsResponse = try await getJSON(
            url: try endpoint("https://api.minecraftservices.com/entitlements/mcstore"),
            bearer: minecraft.accessToken
        )
        guard !entitlements.items.isEmpty else {
            throw MicrosoftAuthError.notOwned
        }

        // e. Profile lookup.
        let profile: ProfileResponse
        do {
            profile = try await getJSON(
                url: try endpoint("https://api.minecraftservices.com/minecraft/profile"),
                bearer: minecraft.accessToken
            )
        } catch MicrosoftAuthError.http(404, _) {
            throw MicrosoftAuthError.notOwned
        }

        return MicrosoftSession(
            name: profile.name,
            uuid: Self.dashedUUID(profile.id),
            minecraftToken: minecraft.accessToken,
            minecraftExpiry: Date().addingTimeInterval(TimeInterval(minecraft.expiresIn)),
            refreshToken: refreshToken
        )
    }

    private func requestXSTS(body: [String: Any]) async throws -> XboxAuthResponse {
        do {
            return try await postJSON(url: try endpoint("https://xsts.auth.xboxlive.com/xsts/authorize"), json: body)
        } catch MicrosoftAuthError.http(401, let bodyText) {
            guard let data = bodyText.data(using: .utf8),
                  let errorResponse = try? JSONDecoder().decode(XstsErrorResponse.self, from: data) else {
                throw MicrosoftAuthError.invalidResponse
            }
            switch errorResponse.xErr {
            case 2148916233:
                throw MicrosoftAuthError.xboxNoAccount
            case 2148916238, 2148916235:
                throw MicrosoftAuthError.xboxCountry
            default:
                throw MicrosoftAuthError.http(401, bodyText)
            }
        }
    }

    // MARK: - HTTP helpers

    private func endpoint(_ string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw MicrosoftAuthError.invalidResponse
        }
        return url
    }

    private func postForm<T: Decodable>(url: URL, body: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Ember-Launcher", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data(body.utf8)

        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func postJSON<T: Decodable>(url: URL, json: [String: Any]) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Ember-Launcher", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)

        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func getJSON<T: Decodable>(url: URL, bearer: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Ember-Launcher", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MicrosoftAuthError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw MicrosoftAuthError.http(http.statusCode, bodyText)
        }
    }

    /// Converts a 32-character hex profile id into the dashed UUID form (8-4-4-4-12).
    private static func dashedUUID(_ hex: String) -> String {
        guard hex.count == 32 else { return hex }
        var result = hex
        for position in [20, 16, 12, 8] {
            let index = result.index(result.startIndex, offsetBy: position)
            result.insert("-", at: index)
        }
        return result
    }
}
