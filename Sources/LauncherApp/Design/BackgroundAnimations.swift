import SwiftUI

private struct BackgroundAnimationsKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False when the user turned off decorative background animations in Settings.
    var backgroundAnimations: Bool {
        get { self[BackgroundAnimationsKey.self] }
        set { self[BackgroundAnimationsKey.self] = newValue }
    }
}
