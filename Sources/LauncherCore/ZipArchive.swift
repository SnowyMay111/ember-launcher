import Foundation

public enum ZipArchiveError: Error, LocalizedError, Sendable {
    case unsupportedPlatform
    case toolFailed(String)
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "Zip operations are not supported on this platform"
        case .toolFailed(let message):
            return "Zip tool failed: \(message)"
        case .unreadable(let message):
            return "Unreadable archive: \(message)"
        }
    }
}

public enum ZipArchive: Sendable {
    /// Returns file entries inside an archive using `unzip -Z1`.
    public static func entries(of archive: URL) throws -> [String] {
        #if os(macOS)
        let output = try run(executable: "/usr/bin/unzip", arguments: ["-Z1", archive.path]).stdout
        return output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #else
        throw ZipArchiveError.unsupportedPlatform
        #endif
    }

    /// Parses uncompressed size in bytes from the summary line of `unzip -Zt`.
    public static func uncompressedSize(of archive: URL) throws -> Int64 {
        #if os(macOS)
        let output = try run(executable: "/usr/bin/unzip", arguments: ["-Zt", archive.path]).stdout
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let lastLine = lines.last else {
            throw ZipArchiveError.unreadable("No output from unzip")
        }
        if let range = lastLine.range(of: " bytes uncompressed") {
            let prefix = lastLine[..<range.lowerBound]
            if let token = prefix.split(whereSeparator: { $0 == " " || $0 == "," }).last,
               let size = Int64(token) {
                return size
            }
        }
        throw ZipArchiveError.unreadable("Failed to parse uncompressed size from: \(lastLine)")
        #else
        throw ZipArchiveError.unsupportedPlatform
        #endif
    }

    /// Extracts an archive into the destination directory.
    public static func extract(_ archive: URL, to directory: URL) throws {
        #if os(macOS)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        _ = try run(executable: "/usr/bin/unzip", arguments: ["-q", "-o", archive.path, "-d", directory.path])
        // Ensure extracted items are owner-readable and owner-writable (e.g. Windows archives with 0000 mode).
        if let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        ) {
            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { continue }
                if values.isSymbolicLink == true { continue }
                let minMode = values.isDirectory == true ? 0o700 : 0o600
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let currentMode = (attrs?[.posixPermissions] as? NSNumber)?.intValue ?? 0
                try? FileManager.default.setAttributes([.posixPermissions: currentMode | minMode], ofItemAtPath: url.path)
            }
        }
        #else
        throw ZipArchiveError.unsupportedPlatform
        #endif
    }

    /// Creates a zip archive containing the given entries relative to `directory`.
    public static func create(_ archive: URL, from directory: URL, entries: [String]) throws {
        #if os(macOS)
        if FileManager.default.fileExists(atPath: archive.path) {
            try? FileManager.default.removeItem(at: archive)
        }
        let arguments = ["-q", "-r", "-X", archive.path] + entries
        _ = try run(executable: "/usr/bin/zip", arguments: arguments, currentDirectoryURL: directory)
        #else
        throw ZipArchiveError.unsupportedPlatform
        #endif
    }

    #if os(macOS)
    @discardableResult
    private static func run(
        executable: String,
        arguments: [String],
        currentDirectoryURL: URL? = nil
    ) throws -> (stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectoryURL = currentDirectoryURL {
            process.currentDirectoryURL = currentDirectoryURL
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdoutData = Data()
        var stderrData = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        do {
            try process.run()
        } catch {
            throw ZipArchiveError.toolFailed("Failed to run \(executable): \(error.localizedDescription)")
        }

        process.waitUntilExit()
        group.wait()

        if process.terminationStatus != 0 {
            var errText = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if errText.isEmpty {
                errText = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
            let trimmed = String(errText.prefix(300))
            throw ZipArchiveError.toolFailed(trimmed)
        }

        let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
        return (stdoutText, stderrText)
    }
    #endif
}
