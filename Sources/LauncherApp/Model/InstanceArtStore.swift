import AppKit
import ImageIO
import LauncherCore
import SwiftUI
import UniformTypeIdentifiers

/// Pictures that belong to one instance. They live in the instance folder, so they are renamed, duplicated
/// and moved to the Trash together with it: `cover.jpg` is chosen by the player, `icon.png` comes from the
/// modpack the instance was made from.
@MainActor
final class InstanceArtStore: ObservableObject {
    static let shared = InstanceArtStore()

    enum Kind: String, CaseIterable, Sendable {
        case cover = "cover.jpg"
        case icon = "icon.png"

        var maxPixel: Int { self == .cover ? 1280 : 256 }
    }

    enum ArtError: LocalizedError {
        case unreadable

        var errorDescription: String? { L("Couldn't read that picture.") }
    }

    private struct Picture: @unchecked Sendable { let image: CGImage }

    private struct Entry {
        let picture: Picture
        let modified: Date
    }

    private enum ReadResult: Sendable {
        case unchanged
        case missing
        case loaded(Picture, Date)
    }

    @Published private var entries: [String: Entry] = [:]
    /// True while a chosen cover is being shrunk and written; the cover buttons wait for it.
    @Published private(set) var isSavingCover = false
    /// Counts the reads started for each picture, so only the latest one is applied.
    private var generation: [String: Int] = [:]

    private init() {}

    private func key(_ kind: Kind, _ name: String) -> String { "\(kind.rawValue)|\(name)" }

    nonisolated private static func fileURL(_ kind: Kind, instance name: String, store: InstanceStore) -> URL {
        store.instanceDirectory(for: name).appendingPathComponent(kind.rawValue)
    }

    /// Memory only, safe in a view body. `refresh` fills it.
    func picture(_ kind: Kind, instance name: String) -> CGImage? {
        entries[key(kind, name)]?.picture.image
    }

    /// Reads both pictures off the main thread. A file that did not change since the last read is not decoded
    /// again, and a file that is gone (the instance was deleted and made anew) drops out of memory.
    func refresh(instance name: String, store: InstanceStore) async {
        for kind in Kind.allCases {
            let key = key(kind, name)
            let url = Self.fileURL(kind, instance: name, store: store)
            let known = entries[key]?.modified
            let maxPixel = kind.maxPixel
            let mine = generation[key, default: 0] + 1
            generation[key] = mine
            let result = await Task.detached(priority: .utility) {
                Self.read(url, known: known, maxPixel: maxPixel)
            }.value
            // A read that started later is on its way or already applied: an older answer must not replace it.
            guard generation[key] == mine else { continue }
            switch result {
            case .unchanged:
                break
            case .missing:
                if entries[key] != nil { entries[key] = nil }
            case .loaded(let picture, let modified):
                entries[key] = Entry(picture: picture, modified: modified)
            }
        }
    }

    /// Keeps a shrunk copy of the chosen picture in the instance folder. The player's own file is only read.
    func setCover(from source: URL, instance name: String, store: InstanceStore) async throws {
        guard !isSavingCover else { return }
        isSavingCover = true
        defer { isSavingCover = false }
        let target = Self.fileURL(.cover, instance: name, store: store)
        let saved = await Task.detached(priority: .userInitiated) { () -> Bool in
            guard let picture = Self.thumbnail(at: source, maxPixel: Kind.cover.maxPixel) else { return false }
            return Self.write(picture, to: target, type: .jpeg)
        }.value
        guard saved else { throw ArtError.unreadable }
        await refresh(instance: name, store: store)
    }

    /// The cover goes to the Trash, so it can be put back.
    func removeCover(instance name: String, store: InstanceStore) async throws {
        guard !isSavingCover else { return }
        let url = Self.fileURL(.cover, instance: name, store: store)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        await refresh(instance: name, store: store)
    }

    /// Best effort: without the icon the instance simply keeps the drawn scene.
    func savePackIcon(from remote: URL?, instance name: String, store: InstanceStore) async {
        guard let remote, remote.scheme == "https" else { return }
        guard let image = await ImageStore.shared.load(remote, maxPixel: Kind.icon.maxPixel) else { return }
        let target = Self.fileURL(.icon, instance: name, store: store)
        guard FileManager.default.fileExists(atPath: target.deletingLastPathComponent().path) else { return }
        let picture = Picture(image: image)
        let saved = await Task.detached(priority: .utility) { Self.write(picture, to: target, type: .png) }.value
        if saved {
            await refresh(instance: name, store: store)
        }
    }

    nonisolated private static func read(_ url: URL, known: Date?, maxPixel: Int) -> ReadResult {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date else { return .missing }
        if modified == known { return .unchanged }
        guard let picture = thumbnail(at: url, maxPixel: maxPixel) else { return .missing }
        return .loaded(picture, modified)
    }

    nonisolated private static func thumbnail(at url: URL, maxPixel: Int) -> Picture? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return Picture(image: image)
    }

    /// Writes beside the target first, so a failed write never leaves half a picture in its place.
    /// Only Ember's own `cover.jpg` / `icon.png` in the instance folder is ever replaced.
    nonisolated private static func write(_ picture: Picture, to target: URL, type: UTType) -> Bool {
        let files = FileManager.default
        let temp = target.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).tmp")
        guard let destination = CGImageDestinationCreateWithURL(temp as CFURL, type.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, picture.image, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? files.removeItem(at: temp)
            return false
        }
        do {
            if files.fileExists(atPath: target.path) {
                _ = try files.replaceItemAt(target, withItemAt: temp)
            } else {
                try files.moveItem(at: temp, to: target)
            }
            return true
        } catch {
            try? files.removeItem(at: temp)
            return false
        }
    }
}
