import Foundation

enum SampleData {
    static let instances: [LibraryInstance] = [
        LibraryInstance(name: "Survival", minecraftVersion: "1.21.4", loader: .fabric, modCount: 42, playtimeMinutes: 18 * 60 + 24, lastPlayedDaysAgo: 2, glow: PreviewGlow(x: 0.30, y: 0.20, opacity: 0.22)),
        LibraryInstance(name: "Creative", minecraftVersion: "1.21.1", loader: .vanilla, modCount: 0, playtimeMinutes: 6 * 60 + 5, lastPlayedDaysAgo: 5, glow: PreviewGlow(x: 0.70, y: 0.30, opacity: 0.14)),
        LibraryInstance(name: "Skyblock", minecraftVersion: "1.20.1", loader: .fabric, modCount: 18, playtimeMinutes: 9 * 60 + 40, lastPlayedDaysAgo: 8, glow: PreviewGlow(x: 0.50, y: 0.80, opacity: 0.18)),
        LibraryInstance(name: "Tech", minecraftVersion: "1.20.1", loader: .forge, modCount: 96, playtimeMinutes: 41 * 60 + 12, lastPlayedDaysAgo: 1, glow: PreviewGlow(x: 0.20, y: 0.70, opacity: 0.12)),
        LibraryInstance(name: "Hardcore", minecraftVersion: "1.21.4", loader: .vanilla, modCount: 0, playtimeMinutes: 3 * 60 + 30, lastPlayedDaysAgo: 14, glow: PreviewGlow(x: 0.80, y: 0.60, opacity: 0.20)),
        LibraryInstance(name: "Friends SMP", minecraftVersion: "1.21.1", loader: .fabric, modCount: 27, playtimeMinutes: 22 * 60 + 50, lastPlayedDaysAgo: 3, glow: PreviewGlow(x: 0.40, y: 0.40, opacity: 0.10)),
        LibraryInstance(name: "Speedrun", minecraftVersion: "1.16.5", loader: .vanilla, modCount: 0, playtimeMinutes: 12 * 60 + 15, lastPlayedDaysAgo: 21, glow: PreviewGlow(x: 0.60, y: 0.15, opacity: 0.16)),
        LibraryInstance(name: "Old Realm", minecraftVersion: "1.12.2", loader: .forge, modCount: 64, playtimeMinutes: 55 * 60, lastPlayedDaysAgo: 40, glow: PreviewGlow(x: 0.25, y: 0.55, opacity: 0.20)),
    ]
}
