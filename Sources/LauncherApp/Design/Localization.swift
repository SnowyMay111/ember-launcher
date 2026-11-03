import SwiftUI
import LauncherCore

nonisolated(unsafe) public let localizer = Localizer(
    directory: Bundle.module.url(forResource: "Languages", withExtension: nil),
    preferredLanguages: {
        switch UserDefaults.standard.string(forKey: SettingsStore.appLanguageKey) ?? "system" {
        case "en", "ru", "uk": return [UserDefaults.standard.string(forKey: SettingsStore.appLanguageKey)!]
        default: return Locale.preferredLanguages
        }
    }()
)

public func L(_ key: String) -> String {
    localizer.tr(key)
}

public func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: localizer.tr(key), arguments: args)
}

extension Text {
    public init(tr key: String) {
        self.init(verbatim: L(key))
    }
}
