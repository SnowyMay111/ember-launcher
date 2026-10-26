import Foundation

extension InstanceStore {
    public static func sanitizedName(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "/", with: "-")
        s = s.replacingOccurrences(of: ":", with: "-")
        s = s.replacingOccurrences(of: "\0", with: "-")
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        while s.hasPrefix(".") {
            s.removeFirst()
        }
        if s.count > 60 {
            s = String(s.prefix(60))
        }
        return s
    }

    public func exists(name: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: paths.instances.path),
              let entries = try? fm.contentsOfDirectory(atPath: paths.instances.path) else {
            return false
        }
        for entry in entries {
            if entry.caseInsensitiveCompare(name) == .orderedSame {
                let jsonURL = instanceJSON(for: entry)
                if fm.fileExists(atPath: jsonURL.path) {
                    return true
                }
            }
        }
        return false
    }

    public func uniqueName(base: String) -> String {
        var candidate = Self.sanitizedName(base)
        if candidate.isEmpty {
            candidate = "Instance"
        }
        if !exists(name: candidate) {
            return candidate
        }
        var index = 2
        while true {
            let nextCandidate = "\(candidate) \(index)"
            if !exists(name: nextCandidate) {
                return nextCandidate
            }
            index += 1
        }
    }

    public func rename(_ name: String, to newName: String) throws -> Instance {
        let sanitized = Self.sanitizedName(newName)
        guard !sanitized.isEmpty else {
            throw InstanceStoreError.invalidName
        }
        let isCaseOnly = name.caseInsensitiveCompare(sanitized) == .orderedSame
        if !isCaseOnly && exists(name: sanitized) {
            throw InstanceStoreError.nameTaken(sanitized)
        }
        var instance = try load(name: name)
        let oldDir = instanceDirectory(for: name)
        let newDir = instanceDirectory(for: sanitized)
        if name != sanitized {
            let fm = FileManager.default
            if isCaseOnly {
                let tempURL = paths.instances.appendingPathComponent(UUID().uuidString)
                try fm.moveItem(at: oldDir, to: tempURL)
                try fm.moveItem(at: tempURL, to: newDir)
            } else {
                try fm.moveItem(at: oldDir, to: newDir)
            }
        }
        instance.name = sanitized
        try save(instance)
        return instance
    }

    public func duplicate(_ name: String, as newName: String) throws -> Instance {
        let sanitized = Self.sanitizedName(newName)
        guard !sanitized.isEmpty else {
            throw InstanceStoreError.invalidName
        }
        if exists(name: sanitized) {
            throw InstanceStoreError.nameTaken(sanitized)
        }
        var instance = try load(name: name)
        let src = instanceDirectory(for: name)
        let dst = instanceDirectory(for: sanitized)
        // Version-change backups belong to the original, so they stay out of the copy.
        let fm = FileManager.default
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)
        for item in try fm.contentsOfDirectory(at: src, includingPropertiesForKeys: nil) where item.lastPathComponent != "backups" {
            try fm.copyItem(at: item, to: dst.appendingPathComponent(item.lastPathComponent))
        }
        instance.name = sanitized
        instance.lastPlayed = nil
        instance.playtimeSeconds = 0
        try save(instance)
        return instance
    }

    public func moveToTrash(_ name: String) throws {
        #if os(macOS)
        try FileManager.default.trashItem(at: instanceDirectory(for: name), resultingItemURL: nil)
        #else
        throw InstanceStoreError.trashUnsupported
        #endif
    }

    public func deleteForever(_ name: String) throws {
        try FileManager.default.removeItem(at: instanceDirectory(for: name))
    }

    public func names(usingMinecraftVersion mc: String) -> [String] {
        let all = (try? list()) ?? []
        return all.compactMap { $0.minecraftVersion == mc ? $0.name : nil }
    }

    public func modCount(for name: String) -> Int {
        let modsDir = gameDirectory(for: name).appendingPathComponent("mods", isDirectory: true)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: modsDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var count = 0
        for url in contents {
            if url.pathExtension.lowercased() == "jar" {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
                    count += 1
                }
            }
        }
        return count
    }

    public func recordPlay(name: String, seconds: Int, at date: Date) throws {
        var instance = try load(name: name)
        instance.playtimeSeconds += max(0, seconds)
        instance.lastPlayed = date
        try save(instance)
    }
}
