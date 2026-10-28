import SwiftUI

struct HomeHeroCard: View {
    let kind: HeroScene.Kind
    let memoryIndex: Int
    let skin: CGImage?
    let eyebrow: String
    let title: String
    let copy: String
    let instance: String
    let loader: String
    let playtime: String
    /// Window width: the prototype's clamp() sizes follow the viewport, not the card.
    var viewport: CGFloat = 1426

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let p = min(max(34, 0.06 * viewport), 76)
            let titleSize = min(max(35, 0.05 * viewport), 67)
            let statGap = min(max(22, 0.03 * viewport), 46)

            ZStack(alignment: .leading) {
                // Background gradient
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0x17/255, green: 0x13/255, blue: 0x12/255), location: 0.0),
                        .init(color: Color(red: 0x13/255, green: 0x11/255, blue: 0x12/255), location: 0.53),
                        .init(color: Color(red: 0x20/255, green: 0x16/255, blue: 0x24/255), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Grid
                gridLayer
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0.0),
                                .init(color: .white, location: 0.6),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // Hero Scene (Right side)
                HeroScene(kind: kind, memoryIndex: memoryIndex, skin: skin)
                    .frame(width: w * 0.55, height: geo.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .accessibilityHidden(true)

                // Text Content (Left side)
                textColumn(
                    padding: p,
                    titleSize: titleSize,
                    statGap: statGap
                )
                .frame(maxHeight: .infinity, alignment: .center)
                .frame(width: w * 0.52, alignment: .leading)
            }
            .frame(minHeight: 430)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(red: 0x27/255, green: 0x25/255, blue: 0x22/255), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.42), radius: 45, y: 30)
            .accessibilityElement(children: .combine)
        }
        .frame(minHeight: 430)
    }
}

// MARK: - Parts

private extension HomeHeroCard {
    var gridLayer: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0, through: size.width, by: 32) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: 32) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Color.white.opacity(0.018)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    func textColumn(padding: CGFloat, titleSize: CGFloat, statGap: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.ember)
                    .frame(width: 5, height: 5)
                    .shadow(color: Theme.ember, radius: 5)
                Text(verbatim: eyebrow)
                    .font(Theme.font(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0x93/255, green: 0x8d/255, blue: 0x84/255))
            }
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(title.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line)
                        .font(Theme.font(size: titleSize, weight: .semibold, mono: false))
                        .tracking(-0.03 * titleSize)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(height: 0.92 * titleSize, alignment: .leading)
                }
            }
            .foregroundColor(Color(red: 0xf1/255, green: 0xed/255, blue: 0xe6/255))

            Text(verbatim: copy)
                .font(Theme.font(size: 13, weight: .regular, mono: false))
                .foregroundColor(Color(red: 0x92/255, green: 0x8d/255, blue: 0x85/255))
                .padding(.top, 22)
                .padding(.bottom, 40)

            HStack(alignment: .top, spacing: statGap) {
                statRow(label: L("Instance"), value: instance)
                statRow(label: L("Loader"), value: loader)
                statRow(label: L("Playtime"), value: playtime)
            }
        }
        .padding(padding)
    }

    func statRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: label)
                .font(Theme.font(size: 12, weight: .medium))
                .foregroundColor(Color(red: 0x65/255, green: 0x61/255, blue: 0x5c/255))
            Text(verbatim: value)
                .font(Theme.font(size: 12, weight: .semibold, mono: false))
                .foregroundColor(Color(red: 0xb6/255, green: 0xb0/255, blue: 0xa8/255))
        }
        .accessibilityElement(children: .combine)
    }
}
