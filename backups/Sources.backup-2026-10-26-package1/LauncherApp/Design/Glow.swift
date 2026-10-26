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
            ZStack {
                switch style {
                case .play:
                    // 680pt circle centered, fades to transparent at 60% radius
                    Circle()
                        .fill(
                            RadialGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.16), location: 0.0),
                                    .init(color: Color.clear, location: 0.60),
                                    .init(color: Color.clear, location: 1.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 340
                            )
                        )
                        .frame(width: 680, height: 680)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                    // Wide faint ellipse at bottom edge
                    SoftEllipse(width: 920, height: 420, opacity: 0.10)
                        .position(x: proxy.size.width / 2, y: proxy.size.height)

                case .page:
                    // Ellipse 840x600 centered on top edge
                    SoftEllipse(width: 840, height: 600, opacity: 0.14)
                        .position(x: proxy.size.width / 2, y: 0)

                    // Faint bottom ellipse
                    SoftEllipse(width: 920, height: 420, opacity: 0.09)
                        .position(x: proxy.size.width / 2, y: proxy.size.height)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Radial glow squeezed into an ellipse; fades to clear at 60% of the half-width.
private struct SoftEllipse: View {
    var width: CGFloat
    var height: CGFloat
    var opacity: Double

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: Color.white.opacity(opacity), location: 0.0),
                        .init(color: Color.clear, location: 0.60),
                        .init(color: Color.clear, location: 1.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: width / 2
                )
            )
            .frame(width: width, height: width)
            .scaleEffect(x: 1, y: height / width)
            .frame(width: width, height: height)
    }
}
