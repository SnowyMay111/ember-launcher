import SwiftUI

public struct EmberDiamond: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let scale = rect.width / 64.0
        var path = Path()
        path.move(to: CGPoint(x: 32.0 * scale, y: 17.0 * scale))
        path.addLine(to: CGPoint(x: 47.0 * scale, y: 32.0 * scale))
        path.addLine(to: CGPoint(x: 32.0 * scale, y: 47.0 * scale))
        path.addLine(to: CGPoint(x: 17.0 * scale, y: 32.0 * scale))
        path.closeSubpath()
        return path
    }
}

public struct EmberLogo: View {
    public var size: CGFloat = 32

    public init(size: CGFloat = 32) {
        self.size = size
    }

    public var body: some View {
        let scale = size / 64.0

        ZStack {
            // Subtle warm glow behind
            RoundedRectangle(cornerRadius: 18.0 * scale)
                .fill(Theme.emberSoft)
                .frame(width: 54.0 * scale, height: 54.0 * scale)
                .blur(radius: max(1.0, size / 4.0))
                .opacity(0.35)

            // Dark outer tile border (rect 5..59, corner radius 18)
            RoundedRectangle(cornerRadius: 18.0 * scale)
                .fill(Color(red: 0x21 / 255.0, green: 0x1A / 255.0, blue: 0x20 / 255.0))
                .frame(width: 54.0 * scale, height: 54.0 * scale)

            // Inner rounded rect (rect 7..57, corner radius 16) with ember-tile gradient
            RoundedRectangle(cornerRadius: 16.0 * scale)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0x4A / 255.0, green: 0x30 / 255.0, blue: 0x48 / 255.0), location: 0.0),
                            .init(color: Color(red: 0x4A / 255.0, green: 0x2E / 255.0, blue: 0x27 / 255.0), location: 1.0)
                        ],
                        startPoint: UnitPoint(x: 12.0 / 64.0, y: 8.0 / 64.0),
                        endPoint: UnitPoint(x: 54.0 / 64.0, y: 58.0 / 64.0)
                    )
                )
                .frame(width: 50.0 * scale, height: 50.0 * scale)

            // Centered diamond gem with ember-gem gradient
            EmberDiamond()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0xC7 / 255.0, green: 0x7F / 255.0, blue: 0xE2 / 255.0), location: 0.0),
                            .init(color: Color(red: 0xD0 / 255.0, green: 0x98 / 255.0, blue: 0xAB / 255.0), location: 0.52),
                            .init(color: Color(red: 0xF2 / 255.0, green: 0xA1 / 255.0, blue: 0x64 / 255.0), location: 1.0)
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 17.0 / 64.0),
                        endPoint: UnitPoint(x: 0.5, y: 47.0 / 64.0)
                    )
                )
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Ember")
        .accessibilityAddTraits(.isImage)
    }
}
