import SwiftUI

public enum Theme {
    // Spec color tokens
    public static let bg = Color(red: 0, green: 0, blue: 0)
    public static let surface = Color(red: 10/255, green: 10/255, blue: 10/255)
    public static let ink = Color(red: 1, green: 1, blue: 1)
    public static let text = Color(red: 237/255, green: 237/255, blue: 237/255)
    public static let muted = Color(red: 139/255, green: 139/255, blue: 139/255)
    public static let line = Color(red: 38/255, green: 38/255, blue: 38/255)
    public static let lineStrong = Color(red: 58/255, green: 58/255, blue: 58/255)

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
    public static let radiusCard: CGFloat = 18
    public static let radiusInput: CGFloat = 12
    public static let radiusPill: CGFloat = 999

    // Glass tokens
    public static let glassFill = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.09), location: 0.0),
            .init(color: Color.white.opacity(0.02), location: 0.45),
            .init(color: Color.white.opacity(0.04), location: 1.0)
        ],
        startPoint: UnitPoint(x: 0.33, y: 0.0),
        endPoint: UnitPoint(x: 0.67, y: 1.0)
    )
    public static let glassBorder = Color.white.opacity(0.11)

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
        let fontName: String = {
            let isBoldOrSemibold = style.weight == .semibold || style.weight == .bold || style.weight == .heavy || style.weight == .black
            let isMedium = style.weight == .medium
            if style.mono {
                return (isBoldOrSemibold || isMedium) ? "GeistMono-Medium" : "GeistMono-Regular"
            } else {
                if isBoldOrSemibold {
                    return "Geist-SemiBold"
                } else if isMedium {
                    return "Geist-Medium"
                } else {
                    return "Geist-Regular"
                }
            }
        }()
        let trackingPt = style.tracking * style.size

        let styledText = self
            .font(.custom(fontName, size: style.size))
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
