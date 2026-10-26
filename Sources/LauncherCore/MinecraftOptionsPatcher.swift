import Foundation

public struct OptionChange: Sendable, Equatable {
    public var key: String
    public var old: String?
    public var new: String

    public init(key: String, old: String?, new: String) {
        self.key = key
        self.old = old
        self.new = new
    }
}

public struct OptionsPatchReport: Sendable, Equatable {
    public var changes: [OptionChange]
    public var wroteFile: Bool

    public init(changes: [OptionChange] = [], wroteFile: Bool = false) {
        self.changes = changes
        self.wroteFile = wroteFile
    }
}

public enum MinecraftOptionsPatcher {
    public static func hasEnabledVoxy(modsDirectory: URL) -> Bool {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: modsDirectory.path) else {
            return false
        }
        for entry in entries {
            let lower = entry.lowercased()
            if lower.hasPrefix("voxy") && lower.hasSuffix(".jar") && !lower.hasSuffix(".jar.disabled") {
                return true
            }
        }
        return false
    }

    public static func patch(
        instanceDirectory: URL,
        modsDirectory: URL,
        lockFpsToMonitor: Bool,
        displayRefreshRate: Int?,
        renderDistanceCap: Int? = nil
    ) throws -> OptionsPatchReport {
        let fm = FileManager.default

        // Detect enabled Voxy jar
        let hasVoxy = hasEnabledVoxy(modsDirectory: modsDirectory)

        // Determine options.txt location
        let directOptions = instanceDirectory.appendingPathComponent("options.txt")
        let subOptions = instanceDirectory.appendingPathComponent("minecraft").appendingPathComponent("options.txt")
        let optionsURL: URL
        if fm.fileExists(atPath: subOptions.path) {
            optionsURL = subOptions
        } else if fm.fileExists(atPath: directOptions.path) {
            optionsURL = directOptions
        } else if fm.fileExists(atPath: instanceDirectory.appendingPathComponent("minecraft").path) {
            optionsURL = subOptions
        } else {
            optionsURL = directOptions
        }

        var lines: [String] = []
        var fileExists = false
        if fm.fileExists(atPath: optionsURL.path),
           let raw = try? String(contentsOf: optionsURL, encoding: .utf8) {
            lines = raw.components(separatedBy: "\n")
            fileExists = true
        }

        var targetValues: [String: String] = [:]

        // Rule (a): Voxy render distance <= 6 or configured cap
        var currentRenderDistance: Int? = nil
        for line in lines {
            if let colon = line.firstIndex(of: ":") {
                let k = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                if k == "renderDistance" {
                    let v = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    currentRenderDistance = Int(v)
                    break
                }
            }
        }

        if hasVoxy {
            if let current = currentRenderDistance {
                if current > 6 {
                    targetValues["renderDistance"] = "6"
                }
            } else {
                targetValues["renderDistance"] = "6"
            }
        } else if let cap = renderDistanceCap {
            if let current = currentRenderDistance {
                if current > cap {
                    targetValues["renderDistance"] = String(cap)
                }
            } else {
                targetValues["renderDistance"] = String(cap)
            }
        }

        // Rule (b): Lock FPS to display refresh rate clamped to 10...240
        if lockFpsToMonitor {
            let baseRate = displayRefreshRate ?? 60
            let clamped = min(max(baseRate, 10), 240)
            targetValues["maxFps"] = String(clamped)
        }

        if targetValues.isEmpty {
            return OptionsPatchReport(changes: [], wroteFile: false)
        }

        var changes: [OptionChange] = []
        var handledKeys = Set<String>()
        var updatedLines: [String] = []

        for line in lines {
            guard let colon = line.firstIndex(of: ":") else {
                updatedLines.append(line)
                continue
            }
            let key = String(line[..<colon])
            let val = String(line[line.index(after: colon)...])

            if let targetVal = targetValues[key] {
                handledKeys.insert(key)
                if val != targetVal {
                    changes.append(OptionChange(key: key, old: val, new: targetVal))
                    updatedLines.append("\(key):\(targetVal)")
                } else {
                    updatedLines.append(line)
                }
            } else {
                updatedLines.append(line)
            }
        }

        for (key, targetVal) in targetValues where !handledKeys.contains(key) {
            changes.append(OptionChange(key: key, old: nil, new: targetVal))
            if updatedLines.last?.isEmpty == true {
                updatedLines.insert("\(key):\(targetVal)", at: updatedLines.count - 1)
            } else {
                updatedLines.append("\(key):\(targetVal)")
            }
        }

        if changes.isEmpty && fileExists {
            return OptionsPatchReport(changes: [], wroteFile: false)
        }

        let parentDir = optionsURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
        }

        var finalContent = updatedLines.joined(separator: "\n")
        if !finalContent.hasSuffix("\n") {
            finalContent.append("\n")
        }

        let tempURL = parentDir.appendingPathComponent("options.txt.\(UUID().uuidString).tmp")
        try finalContent.write(to: tempURL, atomically: true, encoding: .utf8)
        if fm.fileExists(atPath: optionsURL.path) {
            _ = try fm.replaceItemAt(optionsURL, withItemAt: tempURL)
        } else {
            try fm.moveItem(at: tempURL, to: optionsURL)
        }

        return OptionsPatchReport(changes: changes, wroteFile: true)
    }
}
