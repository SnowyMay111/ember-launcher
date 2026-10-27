import Foundation

/// Handles automatic activation of installed resource packs and shader packs.
public enum PackActivation {
    /// Enables a resource pack in options.txt without modifying user ordering.
    public static func enableResourcePack(fileName: String, gameDirectory: URL) throws {
        let optionsURL = gameDirectory.appendingPathComponent("options.txt")
        let targetEntry = "file/\(fileName)"
        let defaultLine = "resourcePacks:[\"vanilla\",\"\(targetEntry)\"]"

        let fm = FileManager.default
        if !fm.fileExists(atPath: optionsURL.path) {
            if !fm.fileExists(atPath: gameDirectory.path) {
                try fm.createDirectory(at: gameDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            let initialContent = defaultLine + "\n"
            try initialContent.write(to: optionsURL, atomically: true, encoding: .utf8)
            return
        }

        let content = try String(contentsOf: optionsURL, encoding: .utf8)
        let hadTrailingNewline = content.hasSuffix("\n")
        var lines = content.isEmpty ? [] : content.components(separatedBy: "\n")
        if hadTrailingNewline && lines.last == "" {
            lines.removeLast()
        }

        if let index = lines.firstIndex(where: { $0.hasPrefix("resourcePacks:") }) {
            let line = lines[index]
            let jsonString = String(line.dropFirst("resourcePacks:".count))
            guard let data = jsonString.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                  let array = jsonObject as? [String] else {
                return
            }

            var updated = array
            if !updated.contains(targetEntry) {
                updated.append(targetEntry)
            }

            let formatted = "[" + updated.map { str in
                let escaped = str
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                return "\"\(escaped)\""
            }.joined(separator: ",") + "]"

            lines[index] = "resourcePacks:\(formatted)"
        } else {
            lines.append(defaultLine)
        }

        var newContent = lines.joined(separator: "\n")
        if hadTrailingNewline {
            newContent.append("\n")
        }
        try newContent.write(to: optionsURL, atomically: true, encoding: .utf8)
    }

    /// Enables a shader pack in config/iris.properties without overwriting user selections.
    public static func enableShaderPack(fileName: String, gameDirectory: URL) throws {
        let configDir = gameDirectory.appendingPathComponent("config", isDirectory: true)
        let irisURL = configDir.appendingPathComponent("iris.properties")
        let fm = FileManager.default

        if !fm.fileExists(atPath: configDir.path) {
            try fm.createDirectory(at: configDir, withIntermediateDirectories: true, attributes: nil)
        }

        if !fm.fileExists(atPath: irisURL.path) {
            let initialContent = "shaderPack=\(fileName)\nenableShaders=true\n"
            try initialContent.write(to: irisURL, atomically: true, encoding: .utf8)
            return
        }

        let content = try String(contentsOf: irisURL, encoding: .utf8)
        let hadTrailingNewline = content.hasSuffix("\n")
        var lines = content.isEmpty ? [] : content.components(separatedBy: "\n")
        if hadTrailingNewline && lines.last == "" {
            lines.removeLast()
        }

        if let index = lines.firstIndex(where: { $0.hasPrefix("shaderPack=") }) {
            let existingValue = lines[index].dropFirst("shaderPack=".count).trimmingCharacters(in: .whitespaces)
            if !existingValue.isEmpty {
                return
            }
            lines[index] = "shaderPack=\(fileName)"
            var newContent = lines.joined(separator: "\n")
            if hadTrailingNewline {
                newContent.append("\n")
            }
            try newContent.write(to: irisURL, atomically: true, encoding: .utf8)
        } else {
            var newContent = content
            if !newContent.isEmpty && !newContent.hasSuffix("\n") {
                newContent.append("\n")
            }
            newContent.append("shaderPack=\(fileName)\n")
            try newContent.write(to: irisURL, atomically: true, encoding: .utf8)
        }
    }
}
