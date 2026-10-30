import SwiftUI
import LauncherCore

/// Launcher-wide settings, saved to UserDefaults.
final class SettingsStore: ObservableObject {
    static let memoryRange: ClosedRange<Double> = 1...Double(max(2, JVMArgumentsBuilder.memoryRecommendation(isModded: false).overAllocationWarningThresholdMB / 1024))

    private let defaults: UserDefaults

    @Published var nickname: String { didSet { defaults.set(nickname, forKey: "nickname") } }
    @Published var memoryGB: Double { didSet { defaults.set(memoryGB, forKey: "memoryGB") } }
    @Published var windowWidth: String { didSet { defaults.set(windowWidth, forKey: "windowWidth") } }
    @Published var windowHeight: String { didSet { defaults.set(windowHeight, forKey: "windowHeight") } }
    @Published var closeOnStart: Bool { didSet { defaults.set(closeOnStart, forKey: "closeOnStart") } }
    @Published var showSnapshots: Bool { didSet { defaults.set(showSnapshots, forKey: "showSnapshots") } }
    @Published var autoUpdate: Bool { didSet { defaults.set(autoUpdate, forKey: "autoUpdate") } }
    @Published var backgroundAnimations: Bool { didSet { defaults.set(backgroundAnimations, forKey: "backgroundAnimations") } }
    @Published var aiProvider: AIProviderKind {
        didSet {
            defaults.set(aiProvider.rawValue, forKey: "aiProvider")
            hasAIKey = KeychainStore.exists(aiProvider.rawValue)
            aiModel = defaults.string(forKey: SettingsStore.aiModelKey(aiProvider)) ?? ""
        }
    }
    /// The chosen model is remembered per provider, so switching providers never sends a Claude id to Gemini.
    @Published var aiModel: String { didSet { defaults.set(aiModel, forKey: SettingsStore.aiModelKey(aiProvider)) } }
    /// Whether a key for the chosen provider is in the Keychain. The key itself is read only when it is used.
    @Published private(set) var hasAIKey: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        nickname = defaults.string(forKey: "nickname") ?? "Player"
        let loadedMemory = defaults.object(forKey: "memoryGB") as? Double ?? 4
        let clampedMemory = min(max(loadedMemory, SettingsStore.memoryRange.lowerBound), SettingsStore.memoryRange.upperBound)
        memoryGB = clampedMemory
        defaults.set(clampedMemory, forKey: "memoryGB")
        windowWidth = defaults.string(forKey: "windowWidth") ?? "1920"
        windowHeight = defaults.string(forKey: "windowHeight") ?? "1080"
        closeOnStart = defaults.object(forKey: "closeOnStart") as? Bool ?? true
        showSnapshots = defaults.object(forKey: "showSnapshots") as? Bool ?? false
        autoUpdate = defaults.object(forKey: "autoUpdate") as? Bool ?? true
        backgroundAnimations = defaults.object(forKey: "backgroundAnimations") as? Bool ?? true
        let provider = AIProviderKind(rawValue: defaults.string(forKey: "aiProvider") ?? "") ?? .claude
        aiProvider = provider
        // "aiModel" is the pre-per-provider key; it belonged to whichever provider was chosen then.
        aiModel = defaults.string(forKey: SettingsStore.aiModelKey(provider)) ?? defaults.string(forKey: "aiModel") ?? ""
        hasAIKey = KeychainStore.exists(provider.rawValue)
    }

    private static func aiModelKey(_ provider: AIProviderKind) -> String { "aiModel.\(provider.rawValue)" }

    func saveAIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainStore.save(trimmed, account: aiProvider.rawValue)
        hasAIKey = KeychainStore.exists(aiProvider.rawValue)
    }

    func removeAIKey() {
        KeychainStore.remove(aiProvider.rawValue)
        hasAIKey = false
    }

    func aiAPIKey() -> String? { KeychainStore.read(aiProvider.rawValue) }

    var memoryText: String { L("%d GB", Int(memoryGB)) }
}
