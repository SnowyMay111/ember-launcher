import Foundation

public enum ServerPropertiesError: Error, Sendable {
    case keyContainsNewline
}

/// Reads and updates Minecraft server.properties files, preserving comments and ordering.
public enum ServerProperties {
    /// Parses java .properties style text into an ordered list of key/value pairs, skipping blank and comment lines.
    public static func parse(_ text: String) -> [(key: String, value: String)] {
        var result: [(key: String, value: String)] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(rawLine)
            if line.hasSuffix("\r") {
                line.removeLast()
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                  let equalsIndex = line.firstIndex(of: "=") else {
                continue
            }

            let key = String(line[..<equalsIndex])
            let value = String(line[line.index(after: equalsIndex)...])
            result.append((key: key, value: value))
        }

        return result
    }

    /// Reads dir/server.properties into a dictionary, returning an empty dictionary if the file does not exist.
    public static func read(in dir: URL) -> [String: String] {
        let url = dir.appendingPathComponent("server.properties")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }

        var result: [String: String] = [:]
        for entry in parse(text) {
            result[entry.key] = entry.value
        }
        return result
    }

    /// Rewrites dir/server.properties atomically, keeping every existing line, comment and order untouched,
    /// replacing the value of keys present in `values`, and appending missing keys at the end.
    public static func update(in dir: URL, values: [String: String]) throws {
        for key in values.keys where key.contains("\r") || key.contains("\n") {
            throw ServerPropertiesError.keyContainsNewline
        }

        let url = dir.appendingPathComponent("server.properties")
        let existingText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let hasTrailingNewline = existingText.hasSuffix("\n")

        func clean(_ value: String) -> String {
            value
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
        }

        var rawLines: [String]
        if existingText.isEmpty {
            rawLines = []
        } else {
            rawLines = existingText
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)

            if hasTrailingNewline {
                rawLines.removeLast()
            }
        }

        var updatedKeys = Set<String>()
        var outputLines: [String] = []

        for rawLine in rawLines {
            let lineEnding = rawLine.hasSuffix("\r") ? "\r" : ""
            let line = lineEnding.isEmpty ? rawLine : String(rawLine.dropLast())
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                  let equalsIndex = line.firstIndex(of: "=") else {
                outputLines.append(rawLine)
                continue
            }

            let key = String(line[..<equalsIndex])
            guard let value = values[key] else {
                outputLines.append(rawLine)
                continue
            }

            let prefix = String(line[...equalsIndex])
            outputLines.append("\(prefix)\(clean(value))\(lineEnding)")
            updatedKeys.insert(key)
        }

        for key in values.keys.sorted() where !updatedKeys.contains(key) {
            outputLines.append("\(key)=\(clean(values[key] ?? ""))")
        }

        var contents = outputLines.joined(separator: "\n")
        if !outputLines.isEmpty && (hasTrailingNewline || existingText.isEmpty) {
            contents.append("\n")
        }

        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
