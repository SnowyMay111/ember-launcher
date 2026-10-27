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
            let skin = SavedSkin(id: id, name: skinName, slim: false, addedAt: Date())

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
