import SwiftUI

public struct HeroScene: View {
    public enum Kind {
        case world
        case player
        case carousel
        case abstract
    }

    public let kind: Kind
    public let memoryIndex: Int
    public let skin: CGImage?

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.backgroundAnimations) private var backgroundAnimations
    private var reduceMotion: Bool { systemReduceMotion || !backgroundAnimations }
    @Local private var arrivalStart = Date()

    public init(kind: Kind = .world, memoryIndex: Int = 0, skin: CGImage? = nil) {
        self.kind = kind
        self.memoryIndex = memoryIndex
        self.skin = skin
    }

    public var body: some View {
        TickView(every: 2, paused: reduceMotion) { date in
            let elapsed = date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack(alignment: .topLeading) {
                    // Landscape background gradient
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0x2C / 255.0, green: 0x20 / 255.0, blue: 0x38 / 255.0), location: 0.0),
                            .init(color: Color(red: 0x28 / 255.0, green: 0x20 / 255.0, blue: 0x2D / 255.0), location: 0.34),
                            .init(color: Color(red: 0x2A / 255.0, green: 0x1D / 255.0, blue: 0x1B / 255.0), location: 0.64),
                            .init(color: Color(red: 0x15 / 255.0, green: 0x14 / 255.0, blue: 0x11 / 255.0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: w, height: h)

                    // Sun with breathe animation
                    // CSS `breathe 5s ease-in-out infinite`: 0 -> 50% (scale 1.05, brightness 1.08) -> 0
                    let breatheProgress = reduceMotion ? 0.0 : (1.0 - cos(elapsed * (2.0 * .pi / 5.0))) / 2.0
                    let sunScale = 1.0 + 0.05 * breatheProgress
                    let sunBrightness = 0.08 * breatheProgress

                    // box-shadow: 0 0 50px / 0 0 140px of rgba(240,160,98,.16), drawn as a radial falloff (a live blur costs far more)
                    RadialGradient(
                        stops: [
                            .init(color: Theme.ember.opacity(0.12), location: 43.0 / 183.0),
                            .init(color: Theme.ember.opacity(0.07), location: 68.0 / 183.0),
                            .init(color: Theme.ember.opacity(0.025), location: 113.0 / 183.0),
                            .init(color: Theme.ember.opacity(0), location: 1.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 183
                    )
                    .frame(width: 366, height: 366)
                    .scaleEffect(sunScale)
                    .position(x: w - (w * 0.18) - 43, y: (h * 0.17) + 43)

                    Circle()
                        .fill(Color(red: 0xF0 / 255.0, green: 0xA6 / 255.0, blue: 0x6D / 255.0))
                        .frame(width: 86, height: 86)
                        .scaleEffect(sunScale)
                        .brightness(sunBrightness)
                        .position(x: w - (w * 0.18) - 43, y: (h * 0.17) + 43)

                    // Mountains & Terrain group (dimmed in .abstract)
                    Group {
                        // Far mountain
                        // CSS `drift 12s ease-in-out infinite alternate`: translate(-8px, -5px) in the rotated frame
                        let driftOffset: CGFloat = reduceMotion ? 0.0 : CGFloat((1.0 - cos(elapsed * (2.0 * .pi / 24.0))) / 2.0)
                        Rectangle()
                            .fill(Color(red: 0x29 / 255.0, green: 0x22 / 255.0, blue: 0x1D / 255.0))
                            .frame(width: 430, height: 280)
                            .rotationEffect(.degrees(45))
                            .offset(x: driftOffset * -2.12, y: driftOffset * -9.19)
                            .opacity(0.7)
                            .position(
                                x: w - (w * 0.04) - 215,
                                y: h - (-155) - 140
                            )

                        // Near mountain
                        Rectangle()
                            .fill(Color(red: 0x18 / 255.0, green: 0x17 / 255.0, blue: 0x14 / 255.0))
                            .frame(width: 430, height: 280)
                            .rotationEffect(.degrees(45))
                            .position(
                                x: w - (w * -0.24) - 215,
                                y: h - (-90) - 140
                            )

                        // Terrain: `linear-gradient(164deg, transparent 20%, #161613 20%)` on a box 44% of the scene high
                        let terrainHeight = h * 0.44
                        let terrainLine = Self.cssGradientLine(angle: 164, width: w, height: terrainHeight)
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.20),
                                .init(color: Color(red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x13 / 255.0), location: 0.20)
                            ],
                            startPoint: terrainLine.start,
                            endPoint: terrainLine.end
                        )
                        .frame(width: w, height: terrainHeight)
                        .position(x: w / 2, y: h - terrainHeight / 2)

                        // Trees live inside the terrain box: `right` and `bottom` percentages are of that box
                        treeView(rightPct: 0.13, bottomPct: 0.22, scale: 1.2, delay: 0.0, elapsed: elapsed, w: w, terrainHeight: terrainHeight, h: h)
                        treeView(rightPct: 0.34, bottomPct: 0.15, scale: 0.72, delay: -1.0, elapsed: elapsed, w: w, terrainHeight: terrainHeight, h: h)
                        treeView(rightPct: 0.54, bottomPct: 0.08, scale: 0.95, delay: -2.5, elapsed: elapsed, w: w, terrainHeight: terrainHeight, h: h)
                        treeView(rightPct: 0.74, bottomPct: 0.02, scale: 0.60, delay: -3.0, elapsed: elapsed, w: w, terrainHeight: terrainHeight, h: h)
                    }
                    .opacity(kind == .abstract ? 0.18 : 1.0)

                    // Abstract cubes
                    if kind == .abstract {
                        abstractCubesView(elapsed: elapsed, w: w, h: h)
                    }

                    // Player figure (z-index 4, painted under the ::after overlay like in the design)
                    if kind == .player {
                        // CSS `playerArrival 2.2s cubic-bezier(.2,.8,.2,1)`: slides in from the right once, no idle float
                        let arrivalT: Double = reduceMotion ? 1.0 : min(1.0, max(0.0, date.timeIntervalSince(arrivalStart) / 2.2))
                        let arrivalEase = 1.0 - pow(1.0 - arrivalT, 4.0)

                        playerFigureView
                            .opacity(arrivalEase)
                            .offset(x: (1.0 - arrivalEase) * 90.0, y: (1.0 - arrivalEase) * 12.0)
                            .position(
                                x: w - (w * 0.25) - 39,
                                y: h - (h * 0.22) - 89
                            )
                    }

                    // Landscape ::after overlay gradients
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0x14 / 255.0, green: 0x13 / 255.0, blue: 0x11 / 255.0), location: 0.0),
                            .init(color: .clear, location: 0.34)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w, height: h)

                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0x09 / 255.0, green: 0x09 / 255.0, blue: 0x08 / 255.0, opacity: 0.55), location: 0.0),
                            .init(color: .clear, location: 0.50)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(width: w, height: h)

                    // Fireflies
                    // CSS `fireflies 4s ease-in-out infinite alternate`
                    let fireflyPhase = reduceMotion ? 0.0 : (1.0 - cos(elapsed * (2.0 * .pi / 8.0))) / 2.0
                    let fireflyY = -3.0 * fireflyPhase
                    let fireflyBrightness = 0.45 * fireflyPhase

                    Group {
                        Circle()
                            .fill(Color(red: 0xE9 / 255.0, green: 0xA3 / 255.0, blue: 0x60 / 255.0))
                            .frame(width: 4, height: 4)
                            .position(x: w * 0.78, y: h * 0.64)

                        Circle()
                            .fill(Color(red: 0xE9 / 255.0, green: 0xA3 / 255.0, blue: 0x60 / 255.0))
                            .frame(width: 2, height: 2)
                            .position(x: w * 0.61, y: h * 0.52)

                        Circle()
                            .fill(Color(red: 0xE9 / 255.0, green: 0xA3 / 255.0, blue: 0x60 / 255.0))
                            .frame(width: 2, height: 2)
                            .position(x: w * 0.88, y: h * 0.44)
                    }
                    .offset(y: fireflyY)
                    .brightness(fireflyBrightness)

                    // Carousel dots: right 8%, bottom 8% of the scene
                    if kind == .carousel {
                        HStack(spacing: 7) {
                            ForEach(0..<3) { idx in
                                let isActive = (memoryIndex % 3 + 3) % 3 == idx
                                RoundedRectangle(cornerRadius: isActive ? 5 : 2.5)
                                    .fill(isActive ? Theme.ember : Color.white.opacity(0.3))
                                    .frame(width: isActive ? 18 : 5, height: 5)
                            }
                        }
                        .padding(.trailing, w * 0.08)
                        .padding(.bottom, h * 0.08)
                        .frame(width: w, height: h, alignment: .bottomTrailing)
                    }
                }
                .frame(width: w, height: h)
                .clipped()
            }
        }
        .id(kind == .carousel ? memoryIndex : 0)
        .animation(.easeInOut(duration: 0.6), value: memoryIndex)
        .onChange(of: kind) { _, _ in arrivalStart = Date() }
        .accessibilityHidden(true)
    }

    // MARK: - Tree View

    @ViewBuilder
    private func treeView(
        rightPct: CGFloat,
        bottomPct: CGFloat,
        scale: CGFloat,
        delay: Double,
        elapsed: Double,
        w: CGFloat,
        terrainHeight: CGFloat,
        h: CGFloat
    ) -> some View {
        // CSS `sway 5s ease-in-out infinite alternate` to rotate(.8deg); a negative animation-delay starts it later in the cycle
        let swayPhase = reduceMotion ? 0.0 : (1.0 - cos((elapsed - delay) * (2.0 * .pi / 10.0))) / 2.0
        let swayAngle = Angle.degrees(0.8 * swayPhase)

        // Trunk 12x90; ::before 76x78 at top -37 and ::after 60x62 at top -11 of the trunk, centred on it.
        // The frame is 76 wide and 127 high (37 above the trunk), so its bottom centre is the trunk's bottom centre.
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(red: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x0F / 255.0))
                .frame(width: 12, height: 90)
                .offset(x: 32, y: 37)

            TreeTriangle()
                .fill(Color(red: 0x15 / 255.0, green: 0x16 / 255.0, blue: 0x12 / 255.0))
                .frame(width: 76, height: 78)

            TreeTriangle()
                .fill(Color(red: 0x15 / 255.0, green: 0x16 / 255.0, blue: 0x12 / 255.0))
                .frame(width: 60, height: 62)
                .offset(x: 8, y: 26)
        }
        .frame(width: 76, height: 127, alignment: .topLeading)
        .rotationEffect(swayAngle, anchor: .bottom)
        .scaleEffect(scale, anchor: .bottom)
        .position(
            x: w - (w * rightPct) - 6,
            y: h - (terrainHeight * bottomPct) - 63.5
        )
    }

    /// Start and end of the gradient line of a CSS `linear-gradient(<angle>deg, ...)` in a box, as unit points.
    static func cssGradientLine(angle: Double, width: CGFloat, height: CGFloat) -> (start: UnitPoint, end: UnitPoint) {
        let radians = angle * .pi / 180
        let dx = CGFloat(sin(radians))
        let dy = CGFloat(-cos(radians))
        let length = abs(width * dx) + abs(height * dy)
        let half = length / 2
        let cx = width / 2
        let cy = height / 2
        return (
            UnitPoint(x: (cx - dx * half) / width, y: (cy - dy * half) / height),
            UnitPoint(x: (cx + dx * half) / width, y: (cy + dy * half) / height)
        )
    }

    // MARK: - Abstract Cubes View

    @ViewBuilder
    private func abstractCubesView(elapsed: Double, w: CGFloat, h: CGFloat) -> some View {
        // The design's cubes are static: `transform: rotate(30deg) skew(-8deg)`
        let spinAngle = 30.0

        ZStack {
            abstractCube(angle: spinAngle)
                .position(x: w - (w * 0.16) - 42, y: (h * 0.22) + 42)

            abstractCube(angle: spinAngle)
                .scaleEffect(0.55)
                .position(x: w - (w * 0.42) - 42, y: (h * 0.52) + 42)

            abstractCube(angle: spinAngle)
                .scaleEffect(0.32)
                .position(x: w - (w * 0.04) - 42, y: (h * 0.62) + 42)
        }
    }

    @ViewBuilder
    private func abstractCube(angle: Double) -> some View {
        // box-shadow: inset 0 0 40px violet .08, 0 0 40px ember .06; skew first, then rotate, both about the centre
        let aboutCenter = CGAffineTransform(translationX: -42, y: -42)
            .concatenating(CGAffineTransform(a: 1.0, b: 0.0, c: tan(-8.0 * .pi / 180.0), d: 1.0, tx: 0.0, ty: 0.0))
            .concatenating(CGAffineTransform(translationX: 42, y: 42))

        ZStack {
            Rectangle()
                .fill(Color(red: 0xF0 / 255.0, green: 0xA0 / 255.0, blue: 0x62 / 255.0, opacity: 0.06))
                .blur(radius: 20)
            Rectangle()
                .stroke(Color(red: 0x96 / 255.0, green: 0x5A / 255.0, blue: 0xBE / 255.0, opacity: 0.08), lineWidth: 40)
                .blur(radius: 20)
                .clipShape(Rectangle())
            Rectangle()
                .stroke(Color(red: 0xEE / 255.0, green: 0xEA / 255.0, blue: 0xE3 / 255.0, opacity: 0.18), lineWidth: 1)
        }
        .frame(width: 84, height: 84)
        .transformEffect(aboutCenter)
        .rotationEffect(.degrees(angle))
    }

    // MARK: - Player Figure View

    private var playerFigureView: some View {
        ZStack(alignment: .topLeading) {
            // Player Head
            if let skin = skin, let headCrop = skin.cropping(to: CGRect(x: 8, y: 8, width: 8, height: 8)) {
                Image(decorative: headCrop, scale: 1.0)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 62, height: 62)
                    .offset(x: 8, y: 0)
            } else {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color(red: 0xB9 / 255.0, green: 0x7B / 255.0, blue: 0x58 / 255.0))
                        .frame(width: 62, height: 62)

                    // Highlights (inset 12px 0 rgba(255,255,255,.05)), under the hair like the first box-shadow wins
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 12, height: 62)

                    // Hair (inset 0 16px #2b1b24)
                    Rectangle()
                        .fill(Color(red: 0x2B / 255.0, green: 0x1B / 255.0, blue: 0x24 / 255.0))
                        .frame(width: 62, height: 16)

                    // Eyes (player-head::before)
                    Rectangle()
                        .fill(Color(red: 0x21 / 255.0, green: 0x17 / 255.0, blue: 0x1A / 255.0))
                        .frame(width: 8, height: 7)
                        .offset(x: 13, y: 31)

                    Rectangle()
                        .fill(Color(red: 0x21 / 255.0, green: 0x17 / 255.0, blue: 0x1A / 255.0))
                        .frame(width: 8, height: 7)
                        .offset(x: 13 + 27, y: 31)
                }
                .frame(width: 62, height: 62)
                .offset(x: 8, y: 0)
            }

            // Player Body
            if let skin = skin, let bodyCrop = skin.cropping(to: CGRect(x: 20, y: 20, width: 8, height: 12)) {
                Image(decorative: bodyCrop, scale: 1.0)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 70, height: 92)
                    .offset(x: 4, y: 62)
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0x6B / 255.0, green: 0x47 / 255.0, blue: 0x7F / 255.0),
                        Color(red: 0x33 / 255.0, green: 0x29 / 255.0, blue: 0x3A / 255.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 70, height: 92)
                .offset(x: 4, y: 62)
            }

            // Player Arm
            if let skin = skin, let armCrop = skin.cropping(to: CGRect(x: 44, y: 20, width: 4, height: 12)) {
                Image(decorative: armCrop, scale: 1.0)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 24, height: 88)
                    .rotationEffect(.degrees(-6))
                    .offset(x: 71, y: 66)
            } else {
                Rectangle()
                    .fill(Color(red: 0x9B / 255.0, green: 0x66 / 255.0, blue: 0x4E / 255.0))
                    .frame(width: 24, height: 88)
                    .rotationEffect(.degrees(-6))
                    .offset(x: 71, y: 66)
            }
        }
        .frame(width: 78, height: 178, alignment: .topLeading)
        .shadow(color: Color.black.opacity(0.55), radius: 10, x: 0, y: 18)
    }
}

// MARK: - Tree Canopy Shape

public struct TreeTriangle: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
