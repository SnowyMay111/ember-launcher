import Foundation

public struct DownloadItem: Sendable {
    public let url: URL
    public let dest: URL
    public let sha1: String?
    public let size: Int?

    public init(url: URL, dest: URL, sha1: String? = nil, size: Int? = nil) {
        self.url = url
        self.dest = dest
        self.sha1 = sha1
        self.size = size
    }
}

public struct DownloadProgress: Sendable {
    public let completedFiles: Int
    public let totalFiles: Int
    public let completedBytes: Int64

    public init(completedFiles: Int, totalFiles: Int, completedBytes: Int64) {
        self.completedFiles = completedFiles
        self.totalFiles = totalFiles
        self.completedBytes = completedBytes
    }
}

public enum DownloaderError: Error, Sendable {
    case invalidHTTPResponse(statusCode: Int, url: URL)
    case checksumMismatch(expected: String, actual: String, url: URL)
    case downloadFailed(underlying: String)
}

private actor ProgressTracker {
    private let totalFiles: Int
    private var completedFiles: Int = 0
    private var completedBytes: Int64 = 0
    private let onProgress: @Sendable (DownloadProgress) -> Void

    init(totalFiles: Int, onProgress: @escaping @Sendable (DownloadProgress) -> Void) {
        self.totalFiles = totalFiles
        self.onProgress = onProgress
    }

    func fileCompleted(bytes: Int64) {
        completedFiles += 1
        completedBytes += bytes
        let progress = DownloadProgress(
            completedFiles: completedFiles,
            totalFiles: totalFiles,
            completedBytes: completedBytes
        )
        onProgress(progress)
    }
}

public final class Downloader: Sendable {
    public let session: URLSession

    public init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.httpMaximumConnectionsPerHost = 8
            config.httpAdditionalHeaders = [
                "User-Agent": "mc-launcher/0.1"
            ]
            self.session = URLSession(configuration: config)
        }
    }

    public func fetchData(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw DownloaderError.invalidHTTPResponse(statusCode: httpResponse.statusCode, url: url)
        }
        return data
    }

    public func fetchJSON<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let data = try await fetchData(url)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    public func download(url: URL, to dest: URL, sha1: String?, size: Int?) async throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: dest.path) {
            if let expectedSha1 = sha1, !expectedSha1.isEmpty {
                if let actualSha1 = try? sha1Hex(of: dest),
                   actualSha1.caseInsensitiveCompare(expectedSha1) == .orderedSame {
                    return
                }
            } else if let expectedSize = size {
                if let attrs = try? fileManager.attributesOfItem(atPath: dest.path),
                   let fileSize = attrs[.size] as? Int,
                   fileSize == expectedSize {
                    return
                }
            }
        }

        let parentDir = dest.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)

        var lastError: Error?
        let maxAttempts = 3

        for attempt in 1...maxAttempts {
            do {
                let (tempLocalURL, response) = try await session.download(from: url)
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    try? fileManager.removeItem(at: tempLocalURL)
                    throw DownloaderError.invalidHTTPResponse(statusCode: httpResponse.statusCode, url: url)
                }

                if let expectedSha1 = sha1, !expectedSha1.isEmpty {
                    let actualSha1 = try sha1Hex(of: tempLocalURL)
                    if actualSha1.caseInsensitiveCompare(expectedSha1) != .orderedSame {
                        try? fileManager.removeItem(at: tempLocalURL)
                        throw DownloaderError.checksumMismatch(expected: expectedSha1, actual: actualSha1, url: url)
                    }
                }

                let targetTempURL = parentDir.appendingPathComponent("\(dest.lastPathComponent).tmp.\(UUID().uuidString)")
                if fileManager.fileExists(atPath: targetTempURL.path) {
                    try? fileManager.removeItem(at: targetTempURL)
                }
                try fileManager.moveItem(at: tempLocalURL, to: targetTempURL)

                if fileManager.fileExists(atPath: dest.path) {
                    try fileManager.removeItem(at: dest)
                }
                try fileManager.moveItem(at: targetTempURL, to: dest)
                return
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    let backoffNanos = UInt64(attempt * 150_000_000)
                    try await Task.sleep(nanoseconds: backoffNanos)
                }
            }
        }

        throw lastError ?? DownloaderError.downloadFailed(underlying: "Failed downloading \(url.absoluteString)")
    }

    public func downloadAll(
        _ items: [DownloadItem],
        maxConcurrent: Int = 16,
        progress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws {
        guard !items.isEmpty else {
            progress(DownloadProgress(completedFiles: 0, totalFiles: 0, completedBytes: 0))
            return
        }

        let tracker = ProgressTracker(totalFiles: items.count, onProgress: progress)
        let concurrencyLimit = max(1, maxConcurrent)

        try await withThrowingTaskGroup(of: Void.self) { group in
            var submitted = 0
            var iterator = items.makeIterator()

            while submitted < concurrencyLimit, let item = iterator.next() {
                submitted += 1
                group.addTask {
                    try await self.download(url: item.url, to: item.dest, sha1: item.sha1, size: item.size)
                    let bytes = Int64(item.size ?? 0)
                    await tracker.fileCompleted(bytes: bytes)
                }
            }

            while try await group.next() != nil {
                if let nextItem = iterator.next() {
                    group.addTask {
                        try await self.download(url: nextItem.url, to: nextItem.dest, sha1: nextItem.sha1, size: nextItem.size)
                        let bytes = Int64(nextItem.size ?? 0)
                        await tracker.fileCompleted(bytes: bytes)
                    }
                }
            }
        }
    }
}
