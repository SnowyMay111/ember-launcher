import SwiftUI
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

/// Downloads, downscales and persists remote images (memory + disk cache, deduplicated in-flight loads).
final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()

    private struct SendableImage: @unchecked Sendable { let image: CGImage }

    private let memory = NSCache<NSString, CGImage>()
    private let lock = NSLock()
    private var inFlight: [String: Task<SendableImage?, Never>] = [:]
    /// One session for every icon, so connections to the CDN are reused.
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()
    private var diskFolderURL: URL?

    private init() {
        memory.countLimit = 500
    }

    private func cacheKey(_ url: URL, maxPixel: Int) -> String {
        "\(maxPixel)|\(url.absoluteString)"
    }

    /// Synchronous memory-only lookup, safe to call from a view body.
    func cached(_ url: URL, maxPixel: Int) -> CGImage? {
        memory.object(forKey: cacheKey(url, maxPixel: maxPixel) as NSString)
    }

    func load(_ url: URL, maxPixel: Int) async -> CGImage? {
        let key = cacheKey(url, maxPixel: maxPixel)
        if let hit = memory.object(forKey: key as NSString) {
            return hit
        }
        let task = sharedTask(for: key) { [weak self] in
            Task<SendableImage?, Never> {
                let result = await self?.fetch(url: url, maxPixel: maxPixel, key: key)
                // Memory first, then the in-flight entry: a caller that comes in between finds one of the two.
                if let image = result?.image {
                    self?.memory.setObject(image, forKey: key as NSString)
                }
                self?.clearTask(for: key)
                return result
            }
        }
        return (await task.value)?.image
    }

    /// The running download for this key, or a new one. Checked and stored under one lock, so two rows that
    /// ask for the same icon at the same moment share a single download.
    private func sharedTask(
        for key: String, make: () -> Task<SendableImage?, Never>
    ) -> Task<SendableImage?, Never> {
        lock.lock(); defer { lock.unlock() }
        if let existing = inFlight[key] { return existing }
        let task = make()
        inFlight[key] = task
        return task
    }

    private func clearTask(for key: String) {
        lock.lock(); defer { lock.unlock() }
        inFlight.removeValue(forKey: key)
    }

    private func fetch(url: URL, maxPixel: Int, key: String) async -> SendableImage? {
        let fileURL = diskFileURL(for: key)
        if let fileURL, let cgImage = decodeThumbnail(at: fileURL, maxPixel: maxPixel) {
            return SendableImage(image: cgImage)
        }
        guard let data = await download(url: url) else { return nil }
        guard let thumbnail = makeThumbnail(from: data, maxPixel: maxPixel) else { return nil }
        if let fileURL {
            writePNG(thumbnail, to: fileURL)
        }
        return SendableImage(image: thumbnail)
    }

    private func download(url: URL) async -> Data? {
        guard let (data, response) = try? await session.data(from: url) else { return nil }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        guard data.count <= 5 * 1024 * 1024 else { return nil }
        return data
    }

    private func makeThumbnail(from data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func decodeThumbnail(at fileURL: URL, maxPixel: Int) -> CGImage? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func writePNG(_ image: CGImage, to fileURL: URL) {
        let tempURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("tmp")
        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: tempURL)
            return
        }
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.moveItem(at: tempURL, to: fileURL)
    }

    /// Once per launch: when the icon folder is over 150 MB, the icons that were written longest ago go
    /// until it is under 100 MB. Only this cache's own `.png` and leftover `.tmp` files are touched.
    private static func trim(_ folder: URL) {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        guard let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys) else { return }
        var files: [(url: URL, size: Int, date: Date)] = []
        for url in urls where ["png", "tmp"].contains(url.pathExtension) {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            files.append((url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast))
        }
        var total = files.reduce(0) { $0 + $1.size }
        guard total > 150 * 1024 * 1024 else { return }
        for file in files.sorted(by: { $0.date < $1.date }) where total > 100 * 1024 * 1024 {
            if (try? fm.removeItem(at: file.url)) != nil { total -= file.size }
        }
    }

    private func diskFileURL(for key: String) -> URL? {
        guard let folder = diskFolder() else { return nil }
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent(hex).appendingPathExtension("png")
    }

    private func diskFolder() -> URL? {
        lock.lock()
        if let diskFolderURL {
            lock.unlock()
            return diskFolderURL
        }
        lock.unlock()
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let base = urls.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("dev.mclauncher.voxel/icons", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Task.detached(priority: .background) { Self.trim(folder) }
        lock.lock()
        diskFolderURL = folder
        lock.unlock()
        return folder
    }
}

/// Shows a cached/downscaled remote image, or a placeholder while loading. Safe to reuse in scrolling lists.
struct CachedImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let maxPixel: Int
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @Local private var loaded: (url: URL, image: CGImage)?

    init(url: URL?, maxPixel: Int = 192, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.maxPixel = maxPixel
        self.content = content
        self.placeholder = placeholder
    }

    private var currentImage: CGImage? {
        if let loaded, loaded.url == url {
            return loaded.image
        }
        guard let url else { return nil }
        return ImageStore.shared.cached(url, maxPixel: maxPixel)
    }

    var body: some View {
        Group {
            if let cgImage = currentImage {
                content(Image(decorative: cgImage, scale: 1))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else {
                loaded = nil
                return
            }
            let image = await ImageStore.shared.load(url, maxPixel: maxPixel)
            // A newer task may already have started for a reused row; only apply if still relevant.
            guard !Task.isCancelled, let image else { return }
            loaded = (url: url, image: image)
        }
    }
}
