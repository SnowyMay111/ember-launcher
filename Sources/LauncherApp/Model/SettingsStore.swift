import SwiftUI

/// Launcher-wide settings, saved to UserDefaults.
final class SettingsStore: ObservableObject {
    static let memoryRange: ClosedRange<Double> = 1...16

    private let defaults: UserDefaults

    @Published var nickname: String { didSet { defaults.set(nickname, forKey: "nickname") } }
    @Published var memoryGB: Double { didSet { defaults.set(memoryGB, forKey: "memoryGB") } }
    @Published var java: String { didSet { defaults.set(java, forKey: "java") } }
    @Published var windowWidth: String { didSet { defaults.set(windowWidth, forKey: "windowWidth") } }
    @Published var windowHeight: String { didSet { defaults.set(windowHeight, forKey: "windowHeight") } }
    @Published var closeOnStart: Bool { didSet { defaults.set(closeOnStart, forKey: "closeOnStart") } }
    @Published var showSnapshots: Bool { didSet { defaults.set(showSnapshots, forKey: "showSnapshots") } }
    @Published var autoUpdate: Bool { didSet { defaults.set(autoUpdate, forKey: "autoUpdate") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        nickname = defaults.string(forKey: "nickname") ?? "Player"
        memoryGB = defaults.object(forKey: "memoryGB") as? Double ?? 4
        java = defaults.string(forKey: "java") ?? "Bundled · Java 21"
        windowWidth = defaults.string(forKey: "windowWidth") ?? "1920"
        windowHeight = defaults.string(forKey: "windowHeight") ?? "1080"
        closeOnStart = defaults.object(forKey: "closeOnStart") as? Bool ?? true
        showSnapshots = defaults.object(forKey: "showSnapshots") as? Bool ?? false
        autoUpdate = defaults.object(forKey: "autoUpdate") as? Bool ?? true
    }

    var memoryText: String { L("%d GB", Int(memoryGB)) }
}
