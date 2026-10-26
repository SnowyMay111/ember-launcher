import Foundation

public final class LogFollower: @unchecked Sendable {
    public let url: URL
    private let lock = NSLock()
    private var offset: UInt64 = 0

    public init(url: URL) {
        self.url = url
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        offset = 0
    }

    public func poll() -> String {
        lock.lock()
        defer { lock.unlock() }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ""
        }
        defer { try? handle.close() }

        let fileSize: UInt64
        do {
            fileSize = try handle.seekToEnd()
        } catch {
            return ""
        }

        if fileSize < offset {
            offset = 0
        }

        do {
            try handle.seek(toOffset: offset)
        } catch {
            offset = 0
            return ""
        }

        let length = Int(fileSize - offset)
        guard length > 0 else {
            return ""
        }

        let data = handle.readData(ofLength: length)
        offset += UInt64(data.count)

        return String(decoding: data, as: UTF8.self)
    }
}

public enum GameLog {
    public static func tail(of url: URL, maxBytes: Int = 200_000) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ""
        }
        defer { try? handle.close() }

        let fileSize: UInt64
        do {
            fileSize = try handle.seekToEnd()
        } catch {
            return ""
        }

        guard fileSize > 0 else { return "" }

        let bytesToRead = min(UInt64(maxBytes), fileSize)
        let startOffset = fileSize - bytesToRead

        do {
            try handle.seek(toOffset: startOffset)
        } catch {
            return ""
        }

        let data = handle.readData(ofLength: Int(bytesToRead))
        var text = String(decoding: data, as: UTF8.self)

        if startOffset > 0, let firstNewline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: firstNewline)...])
        }

        return text
    }

    public static func latestCrashFile(gameDirectory: URL, since: Date) -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []

        let crashReportsDir = gameDirectory.appendingPathComponent("crash-reports", isDirectory: true)
        if let reports = try? fm.contentsOfDirectory(
            at: crashReportsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for file in reports {
                let name = file.lastPathComponent
                if name.hasPrefix("crash-") && name.hasSuffix(".txt") {
                    candidates.append(file)
                }
            }
        }

        if let rootFiles = try? fm.contentsOfDirectory(
            at: gameDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for file in rootFiles {
                let name = file.lastPathComponent
                if name.hasPrefix("hs_err_pid") && name.hasSuffix(".log") {
                    candidates.append(file)
                }
            }
        }

        var newestFile: URL?
        var newestDate: Date?

        for file in candidates {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = values.contentModificationDate,
                  modDate >= since else { continue }
            if let best = newestDate {
                if modDate > best {
                    newestFile = file
                    newestDate = modDate
                }
            } else {
                newestFile = file
                newestDate = modDate
            }
        }

        return newestFile
    }
}
