import SwiftUI

public struct Glow: View {
    public enum Style {
        case play
        case page
    }

    public var style: Style

    public init(_ style: Style) {
        self.style = style
    }

    public var body: some View {
        GeometryReader { proxy in
            let violetOpacity = style == .play ? 0.14 : 0.10
            let emberOpacity = style == .play ? 0.08 : 0.05
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Theme.bg

                // Subtle violet radial glow at upper-left
                RadialGradient(
                    stops: [
                        .init(color: Theme.violet.opacity(violetOpacity), location: 0.0),
                        .init(color: Color.clear, location: 0.70)
                    ],
                    center: UnitPoint(x: 0.15, y: 0.15),
                    startRadius: 0,
                    endRadius: max(width, height) * 0.70
                )

                // Warm orange radial glow near the bottom
                RadialGradient(
                    stops: [
                        .init(color: Theme.ember.opacity(emberOpacity), location: 0.0),
                        .init(color: Color.clear, location: 0.65)
                    ],
                    center: UnitPoint(x: 0.50, y: 0.95),
                    startRadius: 0,
                    endRadius: max(width, height) * 0.75
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
