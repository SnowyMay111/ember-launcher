import Foundation

public enum VersionCleanupError: LocalizedError, Sendable {
    case inUse([String])

    public var errorDescription: String? {
        switch self {
        case .inUse(let names):
            return "Version is in use by: \(names.joined(separator: ", "))"
        }
    }
}

private struct VersionInheritance: Decodable {
    let inheritsFrom: String?
}

extension InstanceStore {
    public func deleteMinecraftVersion(_ mc: String) throws {
        let inUse = names(usingMinecraftVersion: mc)
        guard inUse.isEmpty else {
            throw VersionCleanupError.inUse(inUse)
        }

        let fm = FileManager.default
        let versionsDir = paths.versions
        let mainDir = paths.versionDir(mc)

        // Never remove anything outside paths.versions.
        if mainDir.path.hasPrefix(versionsDir.path), fm.fileExists(atPath: mainDir.path) {
            try fm.removeItem(at: mainDir)
        }

        guard let entries = try? fm.contentsOfDirectory(
            at: versionsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for dir in entries {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            guard dir.path.hasPrefix(versionsDir.path) else { continue }
            let dirName = dir.lastPathComponent
            let jsonURL = dir.appendingPathComponent("\(dirName).json")
            guard let data = try? Data(contentsOf: jsonURL),
                  let versionInfo = try? JSONDecoder().decode(VersionInheritance.self, from: data) else {
                continue
            }
            if versionInfo.inheritsFrom == mc {
                try? fm.removeItem(at: dir)
            }
        }
    }
}
