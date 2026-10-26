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

/// Soft white glow inside a card preview: position (0...1) and brightness.
struct PreviewGlow {
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
}

/// What the interface shows for one instance. Placeholder data for now; replaced by the real storage later.
struct LibraryInstance: Identifiable, Equatable {
    let id: UUID
    var name: String
    var minecraftVersion: String
    var loader: LoaderKind
    var modCount: Int
    var playtimeMinutes: Int
    var lastPlayedDaysAgo: Int
    var glow: PreviewGlow

    init(
        id: UUID = UUID(),
        name: String,
        minecraftVersion: String,
        loader: LoaderKind,
        modCount: Int,
        playtimeMinutes: Int,
        lastPlayedDaysAgo: Int,
        glow: PreviewGlow
    ) {
        self.id = id
        self.name = name
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.modCount = modCount
        self.playtimeMinutes = playtimeMinutes
        self.lastPlayedDaysAgo = lastPlayedDaysAgo
        self.glow = glow
    }

    static func == (lhs: LibraryInstance, rhs: LibraryInstance) -> Bool { lhs.id == rhs.id }

    /// "1.21.4 · Fabric"
    var versionLine: String { "\(minecraftVersion) · \(L(loader.rawValue))" }

    /// "2 days ago"
    var lastPlayedAgo: String {
        switch lastPlayedDaysAgo {
        case ..<1: return L("Today")
        case 1: return L("Yesterday")
        default: return L("%d days ago", lastPlayedDaysAgo)
        }
    }

    /// "18 h 24 min"
    var playtimeText: String { Self.duration(minutes: playtimeMinutes) }

    var modsText: String { L("%d mods", modCount) }

    static func duration(minutes: Int) -> String {
        L("%d h %d min", minutes / 60, minutes % 60)
    }
}
