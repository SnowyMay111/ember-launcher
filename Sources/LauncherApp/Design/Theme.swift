import SwiftUI

public enum Theme {
    // Spec color tokens
    public static let bg = Color(red: 8/255, green: 8/255, blue: 8/255)
    public static let surface = Color(red: 17/255, green: 17/255, blue: 16/255)
    public static let elevated = Color(red: 23/255, green: 21/255, blue: 23/255)
    public static let border = Color(red: 36/255, green: 35/255, blue: 33/255)
    public static let line = Color(red: 36/255, green: 35/255, blue: 33/255)
    public static let lineStrong = Color(red: 52/255, green: 49/255, blue: 46/255)
    public static let ink = Color(red: 238/255, green: 234/255, blue: 227/255)
    public static let text = Color(red: 238/255, green: 234/255, blue: 227/255)
    public static let textSecondary = Color(red: 129/255, green: 122/255, blue: 115/255)
    public static let muted = Color(red: 129/255, green: 122/255, blue: 115/255)
    public static let textMuted = Color(red: 95/255, green: 90/255, blue: 85/255)
    public static let ember = Color(red: 240/255, green: 160/255, blue: 98/255)
    public static let emberDeep = Color(red: 217/255, green: 123/255, blue: 72/255)
    public static let violet = Color(red: 168/255, green: 117/255, blue: 184/255)
    public static let success = Color(red: 148/255, green: 169/255, blue: 120/255)
    public static let danger = Color(red: 169/255, green: 107/255, blue: 104/255)

    // Accents and Gradients
    public static let emberSoft = ember.opacity(0.28)
    public static let emberGradient = LinearGradient(
        colors: [ember, emberDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // White opacities
    public static let white02 = Color.white.opacity(0.02)
    public static let white04 = Color.white.opacity(0.04)
    public static let white09 = Color.white.opacity(0.09)
    public static let white10 = Color.white.opacity(0.10)
    public static let white11 = Color.white.opacity(0.11)
    public static let white14 = Color.white.opacity(0.14)
    public static let white16 = Color.white.opacity(0.16)
    public static let white22 = Color.white.opacity(0.22)
    public static let white40 = Color.white.opacity(0.40)
    public static let black30 = Color.black.opacity(0.30)
    public static let black40 = Color.black.opacity(0.40)
    public static let black45 = Color.black.opacity(0.45)

    // Radii
    public static let radiusHero: CGFloat = 20
    public static let radiusCard: CGFloat = 16
    public static let radiusInput: CGFloat = 12
    public static let radiusCompact: CGFloat = 9
    public static let radiusPill: CGFloat = 999

    // Spacing
    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let page: CGFloat = 48
    }

    // Glass tokens
    public static let glassFill = LinearGradient(
        colors: [surface, surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let glassBorder = border

    // Typography
    public struct TextStyle {
        public var size: CGFloat
        public var weight: Font.Weight
        public var mono: Bool
        public var tracking: CGFloat // in em
        public var color: Color
        public var uppercase: Bool
        public var lineSpacing: CGFloat?

        public init(
            size: CGFloat,
            weight: Font.Weight = .regular,
            mono: Bool = false,
            tracking: CGFloat = -0.01,
            color: Color = Theme.text,
            uppercase: Bool = false,
            lineSpacing: CGFloat? = nil
        ) {
            self.size = size
            self.weight = weight
            self.mono = mono
            self.tracking = tracking
            self.color = color
            self.uppercase = uppercase
            self.lineSpacing = lineSpacing
        }

        public static let hero = TextStyle(
            size: 60,
            weight: .semibold,
            tracking: -0.04,
            color: Theme.ink,
            lineSpacing: 60 * (1.08 - 1.0)
        )
        public static let pageTitle = TextStyle(
            size: 40,
            weight: .semibold,
            tracking: -0.04,
            color: Theme.ink
        )
        public static let cardTitle = TextStyle(
            size: 17,
            weight: .semibold,
            tracking: -0.01,
            color: Theme.ink
        )
        public static let statValue = TextStyle(
            size: 24,
            weight: .semibold,
            tracking: -0.01,
            color: Theme.ink
        )
        public static let row = TextStyle(
            size: 15,
            weight: .medium,
            tracking: -0.01,
            color: Theme.text
        )
        public static let secondary = TextStyle(
            size: 13,
            weight: .regular,
            tracking: -0.01,
            color: Theme.muted
        )
        public static let eyebrow = TextStyle(
            size: 11,
            weight: .regular,
            mono: true,
            tracking: 0.14,
            color: Theme.muted,
            uppercase: true
        )
        public static let body16 = TextStyle(
            size: 16,
            weight: .regular,
            tracking: -0.01,
            color: Theme.muted
        )
    }
}

extension Text {
    @ViewBuilder
    public func style(_ style: Theme.TextStyle) -> some View {
        let font = Theme.font(size: style.size, weight: style.weight, mono: style.mono)
        let trackingPt = style.tracking * style.size

        let styledText = self
            .font(font)
            .tracking(trackingPt)
            .foregroundColor(style.color)

        if let lineSpacing = style.lineSpacing {
            styledText
                .textCase(style.uppercase ? .uppercase : nil)
                .lineSpacing(lineSpacing)
        } else {
            styledText
                .textCase(style.uppercase ? .uppercase : nil)
        }
    }
}
