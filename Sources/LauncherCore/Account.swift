import Foundation

public enum AccountError: Error, LocalizedError, Sendable {
    case invalidName(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let name):
            return "Invalid account name: '\(name)'. Name must be 3-16 characters matching [A-Za-z0-9_]."
        }
    }
}

public struct OfflineAccount: Codable, Sendable, Equatable {
    public let name: String
    public let uuid: String

    public init(name: String) throws {
        guard name.count >= 3 && name.count <= 16 else {
            throw AccountError.invalidName(name)
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        guard name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw AccountError.invalidName(name)
        }

        self.name = name

        let input = "OfflinePlayer:\(name)"
        let data = Data(input.utf8)
        var bytes = md5(data)

        bytes[6] = (bytes[6] & 0x0f) | 0x30
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        self.uuid = String(
            format: "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
    }

    public init(name: String, uuid: String) {
        self.name = name
        self.uuid = uuid
    }
}

/// What the game is launched with: an offline player (token "0") or a signed-in Microsoft account.
public struct MinecraftAccount: Sendable, Equatable {
    public let name: String
    public let uuid: String
    public let accessToken: String
    public let userType: String

    public init(name: String, uuid: String, accessToken: String, userType: String) {
        self.name = name
        self.uuid = uuid
        self.accessToken = accessToken
        self.userType = userType
    }

    public init(offline: OfflineAccount) {
        self.init(name: offline.name, uuid: offline.uuid, accessToken: "0", userType: "legacy")
    }

    public var isOnline: Bool { userType == "msa" }
}
