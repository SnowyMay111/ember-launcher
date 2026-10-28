import SwiftUI

/// Window-wide backdrop from the Ember design: two soft colour washes, two drifting ambient glows,
/// two aurora bands, faint dust and rising embers. Decorative only; it never takes input.
struct AmbientBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.backgroundAnimations) private var backgroundAnimations
    private var reduceMotion: Bool { systemReduceMotion || !backgroundAnimations }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Theme.bg
                washes(w: w, h: h)
                TickView(every: 6, paused: reduceMotion) { date in
                    let t = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate
                    ZStack {
                        ambientGlows(w: w, h: h, t: t)
                        auroraBands(w: w, h: h, t: t)
                    }
                }
                ParticleField(reduceMotion: reduceMotion)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Washes (.app-shell background)

    private func washes(w: CGFloat, h: CGFloat) -> some View {
        // `circle at 82% 26%, rgba(146,88,196,.10), transparent 28%`, sized to the farthest corner.
        let violet = Color(red: 146 / 255, green: 88 / 255, blue: 196 / 255)
        let amber = Color(red: 240 / 255, green: 160 / 255, blue: 98 / 255)

        return ZStack {
            RadialGradient(
                stops: [
                    .init(color: violet.opacity(0.10), location: 0),
                    .init(color: violet.opacity(0), location: 0.28),
                    .init(color: violet.opacity(0), location: 1)
                ],
                center: UnitPoint(x: 0.82, y: 0.26),
                startRadius: 0,
                endRadius: hypot(0.82 * w, 0.74 * h)
            )
            RadialGradient(
                stops: [
                    .init(color: amber.opacity(0.16), location: 0),
                    .init(color: amber.opacity(0), location: 0.24),
                    .init(color: amber.opacity(0), location: 1)
                ],
                center: UnitPoint(x: 0.70, y: 0.58),
                startRadius: 0,
                endRadius: hypot(0.70 * w, 0.58 * h)
            )
        }
    }

    // MARK: - Ambient glows (.ambient-one / .ambient-two)

    /// A blurred disc as a radial gradient: close to what `filter: blur(120px)` leaves of a 300 px circle, and cheap to move.
    private func glow(color: Color, peak: Double, radius: CGFloat) -> some View {
        RadialGradient(
            stops: [
                .init(color: color.opacity(peak), location: 0),
                .init(color: color.opacity(peak * 0.83), location: 0.25),
                .init(color: color.opacity(peak * 0.5), location: 0.5),
                .init(color: color.opacity(peak * 0.2), location: 0.75),
                .init(color: color.opacity(0), location: 1)
            ],
            center: .center,
            startRadius: 0,
            endRadius: radius
        )
        .frame(width: radius * 2, height: radius * 2)
    }

    private func ambientGlows(w: CGFloat, h: CGFloat, t: Double) -> some View {
        let accent = Color(red: 0xF0 / 255, green: 0xA0 / 255, blue: 0x62 / 255)
        let brown = Color(red: 0x70 / 255, green: 0x50 / 255, blue: 0x3A / 255)

        return ZStack {
            // 300 px, right -120 px, top 20%; to translate(-70, 65) scale(1.15), opacity .16 -> .10, 13 s
            let p1 = Self.phase(t, 13)
            glow(color: accent, peak: 0.086, radius: 400)
                .drawingGroup()
                .scaleEffect(1 + 0.15 * p1)
                .offset(x: -70 * p1, y: 65 * p1)
                .opacity(1 - 0.375 * p1)
                .position(x: w - 30, y: 0.2 * h + 150)

            // 220 px, left 18%, bottom -170 px; to translate(120, -45) scale(1.25), opacity .16 -> .22, 16 s
            let p2 = Self.phase(t, 16)
            glow(color: brown, peak: 0.055, radius: 400)
                .drawingGroup()
                .scaleEffect(1 + 0.25 * p2)
                .offset(x: 120 * p2, y: -45 * p2)
                .opacity(1 + 0.375 * p2)
                .position(x: 0.18 * w + 110, y: h + 60)
        }
    }

    // MARK: - Aurora (.aurora-field)

    private func auroraBands(w: CGFloat, h: CGFloat, t: Double) -> some View {
        let bandWidth = 0.62 * w
        let bandHeight = max(0.18 * w, 150)

        let first = LinearGradient(
            colors: [
                .clear,
                Color(red: 116 / 255, green: 72 / 255, blue: 145 / 255, opacity: 0.11),
                Color(red: 227 / 255, green: 133 / 255, blue: 82 / 255, opacity: 0.055),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        let second = LinearGradient(
            colors: [
                .clear,
                Color(red: 221 / 255, green: 124 / 255, blue: 76 / 255, opacity: 0.06),
                Color(red: 99 / 255, green: 63 / 255, blue: 126 / 255, opacity: 0.09),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        return ZStack {
            // right -12%, top 4%, rotate(-16deg); to translate(-9vw, 7vh) rotate(-9deg) scale(1.12), opacity .65, 18 s
            let q1 = Self.phase(t, 18)
            softBand(first, width: bandWidth, height: bandHeight)
                .drawingGroup()
                .rotationEffect(.degrees(-16 + 7 * q1))
                .scaleEffect(1 + 0.12 * q1)
                .offset(x: -0.09 * w * q1, y: 0.07 * h * q1)
                .opacity(1 - 0.35 * q1)
                .position(x: 1.12 * w - bandWidth / 2, y: 0.04 * h + bandHeight / 2)

            // left 8%, bottom -8%, rotate(-16deg); to translate(12vw, -6vh) rotate(-22deg) scale(.9), opacity .5, 23 s
            let q2 = Self.phase(t, 23)
            softBand(second, width: bandWidth, height: bandHeight)
                .drawingGroup()
                .rotationEffect(.degrees(-16 - 6 * q2))
                .scaleEffect(1 - 0.1 * q2)
                .offset(x: 0.12 * w * q2, y: -0.06 * h * q2)
                .opacity(1 - 0.5 * q2)
                .position(x: 0.08 * w + bandWidth / 2, y: 1.08 * h - bandHeight / 2)
        }
        .opacity(0.55)
    }

    /// A colour band with soft elliptical edges: what `blur(70px)` leaves of an ellipse, without a per-frame blur filter.
    private func softBand(_ fill: LinearGradient, width: CGFloat, height: CGFloat) -> some View {
        fill
            .mask(
                EllipticalGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black.opacity(0.9), location: 0.45),
                        .init(color: .black.opacity(0.5), location: 0.7),
                        .init(color: .black.opacity(0.12), location: 0.9),
                        .init(color: .clear, location: 1)
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.5
                )
            )
            .frame(width: width + 170, height: height + 170)
    }

    /// 0...1 position of a CSS `ease-in-out infinite alternate` animation of the given duration.
    private static func phase(_ t: Double, _ seconds: Double) -> Double {
        (1 - cos(t * .pi / seconds)) / 2
    }
}

/// Dust (`.app-shell::before`) and rising embers (`.ember-field`) in one canvas.
private struct ParticleField: View {
    let reduceMotion: Bool

    private struct Ember {
        let left: CGFloat
        let delay: Double
        let duration: Double
        let isPurple: Bool
    }

    // nth-child 1...10: left, animation-delay, animation-duration; every third one is the larger purple kind.
    private static let embers: [Ember] = [
        (0.12, -2, 17), (0.24, -10, 21), (0.39, -5, 18), (0.53, -13, 23), (0.68, -7, 19),
        (0.81, -15, 25), (0.91, -4, 20), (0.32, -17, 26), (0.73, -1, 22), (0.47, -20, 27)
    ].enumerated().map { index, item in
        Ember(left: item.0, delay: item.1, duration: item.2, isPurple: (index + 1) % 3 == 0)
    }

    /// Dust layers: tile size, dot position in the tile, colour, and how far the tile drifts in 24 s.
    private static let dust: [(tile: CGFloat, fx: CGFloat, fy: CGFloat, color: Color, dx: CGFloat, dy: CGFloat)] = [
        (190, 0.18, 0.24, Color(red: 241 / 255, green: 166 / 255, blue: 109 / 255, opacity: 0.35), 30, -70),
        (250, 0.72, 0.64, Color(red: 176 / 255, green: 116 / 255, blue: 205 / 255, opacity: 0.30), -45, -90),
        (310, 0.42, 0.82, Color(red: 241 / 255, green: 166 / 255, blue: 109 / 255, opacity: 0.22), 24, -55)
    ]

    var body: some View {
        TickView(every: 2, paused: reduceMotion) { date in
            let t = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                drawDust(&context, size: size, t: t)
                drawEmbers(&context, size: size, t: t)
            }
        }
    }

    private func drawDust(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        // The CSS loop restarts every 24 s with a jump; the dots are so faint that nobody sees it.
        let progress = CGFloat((t.truncatingRemainder(dividingBy: 24)) / 24)

        for layer in Self.dust {
            let ox = layer.dx * progress
            let oy = layer.dy * progress
            let columns = Int(size.width / layer.tile) + 2
            let rows = Int(size.height / layer.tile) + 2

            for row in -1..<rows {
                for column in -1..<columns {
                    let x = CGFloat(column) * layer.tile + layer.fx * layer.tile + ox.truncatingRemainder(dividingBy: layer.tile)
                    let y = CGFloat(row) * layer.tile + layer.fy * layer.tile + oy.truncatingRemainder(dividingBy: layer.tile)
                    let dot = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                    context.fill(Path(ellipseIn: dot), with: .color(layer.color.opacity(0.22)))
                }
            }
        }
    }

    private func drawEmbers(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        guard !reduceMotion else { return }

        for ember in Self.embers {
            let phase = ((t - ember.delay).truncatingRemainder(dividingBy: ember.duration)) / ember.duration
            let p = CGFloat(phase)

            // emberRise keyframes: transform at 0 / 55 / 100 %, opacity at 0 / 12 / 55 / 100 %
            let tx: CGFloat
            let ty: CGFloat
            let scale: CGFloat
            if p < 0.55 {
                let k = p / 0.55
                tx = 22 * k
                ty = -0.48 * size.height * k
                scale = 0.7 + 0.3 * k
            } else {
                let k = (p - 0.55) / 0.45
                tx = 22 - 36 * k
                ty = -0.48 * size.height - 0.57 * size.height * k
                scale = 1 - 0.6 * k
            }
            let opacity: CGFloat
            if p < 0.12 {
                opacity = 0.45 * p / 0.12
            } else if p < 0.55 {
                opacity = 0.45 - 0.17 * (p - 0.12) / 0.43
            } else {
                opacity = 0.28 * (1 - (p - 0.55) / 0.45)
            }

            let diameter: CGFloat = ember.isPurple ? 3 : 2
            let color = ember.isPurple
                ? Color(red: 164 / 255, green: 117 / 255, blue: 190 / 255)
                : Color(red: 234 / 255, green: 160 / 255, blue: 100 / 255)
            let cx = ember.left * size.width + tx
            // bottom: -12px, so the box starts 12 px below the window
            let cy = size.height + 12 - diameter / 2 + ty
            let radius = diameter / 2 * scale
            let glowRadius = radius + 4

            context.fill(
                Path(ellipseIn: CGRect(x: cx - glowRadius, y: cy - glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
                with: .color(color.opacity(opacity * 0.22))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(opacity))
            )
        }
    }
}
