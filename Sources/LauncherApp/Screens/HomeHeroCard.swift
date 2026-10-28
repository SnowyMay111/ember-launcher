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
    var viewport: CGFloat = 1426

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .bottomLeading) {
                // Full bleed landscape background
                ZStack {
                    // Hero Scene elements (sky, mountains, trees, sun, animated elements)
                    HeroScene(kind: kind, memoryIndex: memoryIndex, skin: skin)
                        .frame(width: w, height: h)
                        .accessibilityHidden(true)

                    // Subtle technical grid overlay
                    gridLayer
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0.0),
                                    .init(color: .white, location: 0.5),
                                    .init(color: .clear, location: 0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Subtle gradient overlay on bottom-left for text legibility
                LinearGradient(
                    colors: [Color.black.opacity(0.65), Color.black.opacity(0.15), Color.clear],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )

                // Frosted hero card container in bottom-left
                VStack(alignment: .leading, spacing: 14) {
                    // World Title in elegant Serif
                    Text(instance.isEmpty ? title : instance)
                        .font(.system(size: min(max(38, w * 0.05), 58), weight: .regular, design: .serif))
                        .tracking(-1.2)
                        .foregroundColor(Color(red: 238/255, green: 229/255, blue: 217/255))
                        .lineLimit(1)
                        .shadow(color: Color.black.opacity(0.5), radius: 8, y: 3)

                    // Editorial Metadata Strip
                    HStack(spacing: 12) {
                        // Glowing ember dot
                        Circle()
                            .fill(Theme.ember)
                            .frame(width: 6, height: 6)
                            .shadow(color: Theme.ember, radius: 6)

                        // Last played
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(verbatim: "LAST PLAYED")
                                .font(Theme.font(size: 8, weight: .medium, mono: true))
                                .tracking(1.2)
                                .foregroundColor(Color(red: 118/255, green: 111/255, blue: 104/255))

                            Text(eyebrow.replacingOccurrences(of: "Last played · ", with: ""))
                                .font(Theme.font(size: 11, weight: .medium, mono: true))
                                .foregroundColor(Color(red: 178/255, green: 170/255, blue: 161/255))
                        }

                        // Divider
                        Rectangle()
                            .fill(Color(red: 58/255, green: 52/255, blue: 46/255))
                            .frame(width: 1, height: 16)

                        // Loader
                        Text(loader)
                            .font(Theme.font(size: 11, weight: .regular, mono: true))
                            .foregroundColor(Color(red: 165/255, green: 158/255, blue: 149/255))

                        if !playtime.isEmpty && playtime != "0 h 0 min" {
                            Rectangle()
                                .fill(Color(red: 58/255, green: 52/255, blue: 46/255))
                                .frame(width: 1, height: 16)

                            Text(playtime)
                                .font(Theme.font(size: 11, weight: .regular, mono: true))
                                .foregroundColor(Color(red: 165/255, green: 158/255, blue: 149/255))
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 17/255, green: 15/255, blue: 13/255).opacity(0.88))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 58/255, green: 51/255, blue: 45/255), lineWidth: 1)
                        )
                )
                .padding(28)
            }
            .frame(minHeight: 460)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(red: 39/255, green: 37/255, blue: 34/255), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.48), radius: 50, y: 28)
        }
        .frame(minHeight: 460)
    }

    private var gridLayer: some View {
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
}
