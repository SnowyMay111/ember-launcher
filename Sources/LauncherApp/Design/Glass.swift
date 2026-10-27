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
    public var elevated: Bool

    public init(radius: CGFloat = Theme.radiusCard, elevated: Bool = false) {
        self.radius = radius
        self.elevated = elevated
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(elevated ? Theme.elevated : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.black.opacity(0.42), radius: 25, x: 0, y: 16)
    }
}

public struct TopBarBackgroundModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack(alignment: .bottom) {
                    Theme.surface
                    Theme.border
                        .frame(height: 1)
                }
            )
    }
}

extension View {
    public func glass(radius: CGFloat = Theme.radiusCard, elevated: Bool = false) -> some View {
        modifier(GlassModifier(radius: radius, elevated: elevated))
    }

    public func elevatedGlass(radius: CGFloat = Theme.radiusCard) -> some View {
        modifier(GlassModifier(radius: radius, elevated: true))
    }

    public func topBarBackground() -> some View {
        modifier(TopBarBackgroundModifier())
    }
}
