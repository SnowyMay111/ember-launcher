import LauncherCore
import SwiftUI

enum LoaderKind: String, CaseIterable, Identifiable {
    case vanilla = "Vanilla"
    case fabric = "Fabric"
    case forge = "Forge"

    var id: String { rawValue }
}

enum LoaderFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case vanilla = "Vanilla"
    case fabric = "Fabric"
    case forge = "Forge"

    var id: String { rawValue }

    func matches(_ loader: LoaderKind) -> Bool {
        switch self {
        case .all: return true
        case .vanilla: return loader == .vanilla
        case .fabric: return loader == .fabric
        case .forge: return loader == .forge
        }
    }
}

/// Library groups. An instance without a saved group lands in "Vanilla" or "Mods" by its loader.
enum GroupName {
    static let favorites = "Favorites"
    static let vanilla = "Vanilla"
    static let mods = "Mods"
    static let defaults = [favorites, vanilla, mods]

    static func automatic(for loader: LoaderKind) -> String {
        loader == .vanilla ? vanilla : mods
    }
}

/// Soft white glow inside a card preview: position (0...1) and brightness.
struct PreviewGlow: Equatable {
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
}

/// What the interface shows for one instance, built from the saved `LauncherCore.Instance`.
struct LibraryInstance: Identifiable, Equatable {
    let name: String
    let minecraftVersion: String
    let loader: LoaderKind
    let group: String
    let modCount: Int
    let playtimeSeconds: Int
    let lastPlayed: Date?
    let memoryMB: Int
    let javaArgs: [String]
    let glow: PreviewGlow

    /// The name is also the folder name, so it is unique.
    var id: String { name }

    init(_ instance: Instance, modCount: Int) {
        let loader = LoaderKind(rawValue: instance.loader.capitalized) ?? .vanilla
        name = instance.name
        minecraftVersion = instance.minecraftVersion
        self.loader = loader
        group = instance.group ?? GroupName.automatic(for: loader)
        self.modCount = modCount
        playtimeSeconds = instance.playtimeSeconds
        lastPlayed = instance.lastPlayed
        memoryMB = instance.memoryMB
        javaArgs = instance.extraJVMArgs
        glow = Self.glow(for: instance.name)
    }

    /// The same name always gets the same picture: hash it into a glow position and brightness.
    private static func glow(for name: String) -> PreviewGlow {
        var hash: UInt32 = 5381
        for byte in name.utf8 { hash = hash &* 33 &+ UInt32(byte) }
        let x = 0.20 + Double(hash % 61) / 100
        let y = 0.15 + Double((hash / 61) % 71) / 100
        let opacity = 0.10 + Double((hash / 4331) % 13) / 100
        return PreviewGlow(x: CGFloat(x), y: CGFloat(y), opacity: opacity)
    }

    /// "1.21.4 · Fabric"
    var versionLine: String { "\(minecraftVersion) · \(L(loader.rawValue))" }

    /// "2 days ago"
    var lastPlayedAgo: String {
        guard let lastPlayed else { return L("Never played") }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastPlayed), to: calendar.startOfDay(for: Date())).day ?? 0
        switch days {
        case ..<1: return L("Today")
        case 1: return L("Yesterday")
        default: return L("%d days ago", days)
        }
    }

    /// "18 h 24 min"
    var playtimeText: String { Self.duration(minutes: playtimeSeconds / 60) }

    var modsText: String { L("%d mods", modCount) }

    var memoryText: String { L("%d GB", memoryMB / 1024) }

    static func duration(minutes: Int) -> String {
        L("%d h %d min", minutes / 60, minutes % 60)
    }
}
