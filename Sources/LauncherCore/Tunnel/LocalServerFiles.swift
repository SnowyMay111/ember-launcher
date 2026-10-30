import Foundation

/// Errors that can occur while preparing a Minecraft dedicated-server directory.
public enum LocalServerFilesError: Error, LocalizedError, Sendable {
    case modsFolderInTheWay(URL)

    public var errorDescription: String? {
        switch self {
        case .modsFolderInTheWay(let url):
            return "Cannot link mods folder: '\(url.path)' already exists and is not a symlink. Move or remove it first."
        }
    }
}

/// Prepares the files a Minecraft dedicated server needs to host a lobby reached through the tunnel.
public enum LocalServerFiles {
    /// Writes eula.txt accepting the Minecraft EULA.
    public static func writeEula(in dir: URL) throws {
        let contents = "eula=true\n"
        try contents.write(to: dir.appendingPathComponent("eula.txt"), atomically: true, encoding: .utf8)
    }

    /// Writes server.properties configured for a loopback-only lobby reached through the tunnel.
    public static func writeServerProperties(in dir: URL, port: Int, maxPlayers: Int, motd: String) throws {
        let cleanMotd = motd
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        let lines = [
            "server-ip=127.0.0.1",
            "server-port=\(port)",
            "online-mode=false",
            "white-list=true",
            "enforce-whitelist=true",
            "max-players=\(maxPlayers)",
            "motd=\(cleanMotd)",
            "spawn-protection=0",
            "enable-query=false",
            "enable-rcon=false",
            "view-distance=10",
            "sync-chunk-writes=false",
        ]

        let contents = lines.joined(separator: "\n") + "\n"
        try contents.write(to: dir.appendingPathComponent("server.properties"), atomically: true, encoding: .utf8)
    }

    private struct WhitelistEntry: Codable {
        let uuid: String
        let name: String
    }

    /// Builds whitelist.json content for the given player names, skipping invalid names and de-duplicating case-insensitively.
    public static func whitelistJSON(names: [String]) -> Data {
        var seen = Set<String>()
        var entries: [WhitelistEntry] = []

        for name in names {
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            guard let account = try? OfflineAccount(name: name) else { continue }
            seen.insert(key)
            entries.append(WhitelistEntry(uuid: account.uuid, name: account.name))
        }

        entries.sort { $0.name.lowercased() < $1.name.lowercased() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(entries)) ?? Data("[]".utf8)
    }

    /// Writes whitelist.json atomically for the given player names.
    public static func writeWhitelist(in dir: URL, names: [String]) throws {
        let data = whitelistJSON(names: names)
        try data.write(to: dir.appendingPathComponent("whitelist.json"), options: .atomic)
    }

    /// Links serverDirectory/mods to modsDirectory, creating modsDirectory if needed and replacing an existing symlink.
    public static func linkMods(serverDirectory: URL, to modsDirectory: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: modsDirectory, withIntermediateDirectories: true)

        let modsLink = serverDirectory.appendingPathComponent("mods")

        if (try? fileManager.destinationOfSymbolicLink(atPath: modsLink.path)) != nil {
            try fileManager.removeItem(at: modsLink)
        } else if fileManager.fileExists(atPath: modsLink.path) {
            throw LocalServerFilesError.modsFolderInTheWay(modsLink)
        }

        try fileManager.createSymbolicLink(at: modsLink, withDestinationURL: modsDirectory)
    }
}
