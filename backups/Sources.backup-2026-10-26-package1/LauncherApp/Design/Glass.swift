import SwiftUI
import AppKit

/// Blur layer that lets every click through to the SwiftUI content above it.
final class PassthroughEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .underWindowBackground,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = PassthroughEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.appearance = NSAppearance(named: .darkAqua)
    }
}

public struct GlassModifier: ViewModifier {
    public var radius: CGFloat

    public init(radius: CGFloat = Theme.radiusCard) {
        self.radius = radius
    }

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // The material tints grey; keep only a hint of it so the fill reads as in the spec.
                    VisualEffectBlur(material: .underWindowBackground, blendingMode: .withinWindow, state: .active)
                        .opacity(0.3)

                    Theme.glassFill

                    // Inset 1px top highlight
                    VStack(spacing: 0) {
                        Color.white.opacity(0.16)
                            .frame(height: 1)
                        Spacer()
                    }

                    // 1px outer glass border
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Theme.glassBorder, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.black.opacity(0.5), radius: 25, x: 0, y: 20)
    }
}

public struct TopBarBackgroundModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack(alignment: .bottom) {
                    VisualEffectBlur(material: .underWindowBackground, blendingMode: .withinWindow, state: .active)
                    Color.black.opacity(0.55)
                    Theme.line
                        .frame(height: 1)
                }
            )
    }
}

extension View {
    public func glass(radius: CGFloat = Theme.radiusCard) -> some View {
        modifier(GlassModifier(radius: radius))
    }

    public func topBarBackground() -> some View {
        modifier(TopBarBackgroundModifier())
    }
}
