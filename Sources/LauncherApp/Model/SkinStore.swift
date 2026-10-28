import Foundation
import AppKit
import LauncherCore

/// Model representing a saved Minecraft player skin.
struct SavedSkin: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var slim: Bool
    var addedAt: Date
}

/// Local storage and management for imported Minecraft skins.
@MainActor
final class SkinStore: ObservableObject {
    @Published var skins: [SavedSkin] = []
    @Published var equippedID: UUID?
    @Published var message: String?

    private let skinsDirectory: URL
    private let indexURL: URL
    private var imageCache: [UUID: CGImage] = [:]

    init() {
        let root = LauncherPaths().root
        let dir = root.appendingPathComponent("skins", isDirectory: true)
        self.skinsDirectory = dir
        self.indexURL = dir.appendingPathComponent("index.json")

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            self.message = error.localizedDescription
        }

        load()
    }

    /// Loads skins metadata from disk and reads the equipped skin ID from UserDefaults.
    func load() {
        do {
            if FileManager.default.fileExists(atPath: indexURL.path) {
                let data = try Data(contentsOf: indexURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                skins = try decoder.decode([SavedSkin].self, from: data)
            } else {
                skins = []
            }
        } catch {
            message = error.localizedDescription
        }

        if let savedEquipped = UserDefaults.standard.string(forKey: "equippedSkinID"),
           let uuid = UUID(uuidString: savedEquipped) {
            equippedID = uuid
        }

        if skins.isEmpty {
            if let emberData = loadPresetData(named: "ember") {
                _ = importSkinData(emberData, name: "Ember", isSlim: false)
            }
            if let steveData = loadPresetData(named: "steve") {
                _ = importSkinData(steveData, name: "Classic Steve", isSlim: false)
            }
            if let first = skins.first {
                equippedID = first.id
                UserDefaults.standard.set(first.id.uuidString, forKey: "equippedSkinID")
            }
        } else {
            // Auto-detect slim model for skins that have 3px arms
            for i in 0..<skins.count {
                if !skins[i].slim, let img = image(for: skins[i].id), Skin3DView.detectIsSlim(image: img) {
                    skins[i].slim = true
                }
            }
        }
    }

    private func loadPresetData(named name: String) -> Data? {
        if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources/Skins") ??
                     Bundle.module.url(forResource: name, withExtension: "png") {
            if let data = try? Data(contentsOf: url) {
                return data
            }
        }
        let fallbackPaths = [
            "/Users/may/Projects/mc-launcher/Sources/LauncherApp/Resources/Skins/\(name).png",
            "/tmp/\(name).png"
        ]
        for path in fallbackPaths {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                return data
            }
        }
        return nil
    }

    /// Imports a PNG skin from a file URL, validating its pixel dimensions (64x64 or 64x32).
    func importSkin(from url: URL) {
        do {
            guard url.pathExtension.lowercased() == "png" else {
                message = "That file is not a Minecraft skin (64×64 or 64×32 PNG)."
                return
            }

            let data = try Data(contentsOf: url)
            guard let rep = NSBitmapImageRep(data: data) else {
                message = "That file is not a Minecraft skin (64×64 or 64×32 PNG)."
                return
            }

            let w = rep.pixelsWide
            let h = rep.pixelsHigh
            guard w == 64 && (h == 64 || h == 32) else {
                message = "That file is not a Minecraft skin (64×64 or 64×32 PNG)."
                return
            }

            let id = UUID()
            let destURL = skinsDirectory.appendingPathComponent("\(id.uuidString).png")
            try data.write(to: destURL, options: .atomic)

            let baseName = url.deletingPathExtension().lastPathComponent
            let skinName = baseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Skin" : baseName
            let isSlim = rep.cgImage.map { Skin3DView.detectIsSlim(image: $0) } ?? false
            let skin = SavedSkin(id: id, name: skinName, slim: isSlim, addedAt: Date())

            if let cg = rep.cgImage {
                imageCache[id] = cg
            }

            skins.append(skin)
            saveIndex()
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    /// Imports skin data directly (e.g. from the skin catalog or an online URL).
    @discardableResult
    func importSkinData(_ data: Data, name: String, isSlim: Bool = false) -> SavedSkin? {
        guard let rep = NSBitmapImageRep(data: data) else {
            message = "Invalid image data."
            return nil
        }
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        guard w == 64 && (h == 64 || h == 32) else {
            message = "That file is not a Minecraft skin (64×64 or 64×32 PNG)."
            return nil
        }
        let id = UUID()
        let destURL = skinsDirectory.appendingPathComponent("\(id.uuidString).png")
        do {
            try data.write(to: destURL, options: .atomic)
            let skin = SavedSkin(id: id, name: name, slim: isSlim, addedAt: Date())
            if let cg = rep.cgImage {
                imageCache[id] = cg
            }
            skins.append(skin)
            saveIndex()
            message = nil
            return skin
        } catch {
            message = error.localizedDescription
            return nil
        }
    }

    /// Opens an NSOpenPanel to let the user select a single PNG skin to import.
    func pickAndImport() {
        let panel = NSOpenPanel()
        panel.title = "Import Skin"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["png"]

        if panel.runModal() == .OK, let selectedURL = panel.url {
            importSkin(from: selectedURL)
        }
    }

    /// Renames a skin and persists the change to the index.
    func rename(id: UUID, to newName: String) {
        guard let index = skins.firstIndex(where: { $0.id == id }) else { return }
        skins[index].name = newName
        saveIndex()
    }

    /// Toggles the slim arm geometry model for a skin.
    func setSlim(id: UUID, _ slim: Bool) {
        guard let index = skins.firstIndex(where: { $0.id == id }) else { return }
        skins[index].slim = slim
        saveIndex()
    }

    /// Equips a skin locally and persists the ID in UserDefaults.
    func equip(id: UUID) {
        guard skins.contains(where: { $0.id == id }) else { return }
        equippedID = id
        UserDefaults.standard.set(id.uuidString, forKey: "equippedSkinID")
    }

    /// Removes a skin from the library and deletes its file on disk.
    func remove(id: UUID) {
        skins.removeAll(where: { $0.id == id })
        imageCache.removeValue(forKey: id)

        if equippedID == id {
            equippedID = nil
            UserDefaults.standard.removeObject(forKey: "equippedSkinID")
        }

        let fileURL = skinsDirectory.appendingPathComponent("\(id.uuidString).png")
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            message = error.localizedDescription
        }

        saveIndex()
    }

    /// Returns the cached CGImage for a skin ID, or loads it from disk if not yet in cache.
    func image(for id: UUID) -> CGImage? {
        if let cached = imageCache[id] {
            return cached
        }

        let fileURL = skinsDirectory.appendingPathComponent("\(id.uuidString).png")
        guard let data = try? Data(contentsOf: fileURL),
              let rep = NSBitmapImageRep(data: data),
              let cg = rep.cgImage else {
            return nil
        }

        imageCache[id] = cg
        return cg
    }

    private func saveIndex() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(skins)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            message = error.localizedDescription
        }
    }
}
