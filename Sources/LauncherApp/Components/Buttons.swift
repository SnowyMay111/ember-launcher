import SwiftUI

/// Dims a little while pressed; the pill itself draws everything else.
struct PressDimStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private func pillLabel(_ key: String, color: Color) -> some View {
    Text(tr: key).style(.init(size: 15, weight: .medium, color: color))
}

/// Ember pill with dark warm text, ember gradient, inner top highlight, and soft glow.
struct PrimaryPill: View {
    let title: String
    var showsPlay = false
    /// Fixed height (toolbar: 42). Without it the pill uses 13pt vertical padding (hero).
    var height: CGFloat? = nil
    var horizontalPadding: CGFloat = 30
    var isDisabled = false
    var action: () -> Void = {}

    @Local private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let darkWarmText = Color(red: 27 / 255.0, green: 17 / 255.0, blue: 10 / 255.0)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if showsPlay {
                    PlayTriangle()
                        .fill(darkWarmText)
                        .frame(width: 11, height: 11)
                        .accessibilityHidden(true)
                }
                pillLabel(title, color: darkWarmText)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, height == nil ? 13 : 0)
            .frame(height: height)
            .frame(minHeight: 40)
            .background(Capsule().fill(Theme.emberGradient))
            .overlay(
                Capsule()
                    .strokeBorder(Theme.ember, lineWidth: 1)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(Theme.ember.opacity(0.8), lineWidth: 2)
                    .padding(-3)
                    .opacity(isFocused ? 1 : 0)
            )
            .shadow(color: Theme.emberSoft, radius: isHovered ? 14 : 8, y: isHovered ? 4 : 2)
            .offset(y: (isHovered && !isDisabled && !reduceMotion) ? -2 : 0)
            .contentShape(Capsule())
        }
        .buttonStyle(PressDimStyle())
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
    }
}

/// Elevated surface pill with border stroke and hover brightening.
struct SecondaryPill: View {
    let title: String
    /// Fixed height (e.g. 36 next to a PrimaryPill). Without it the pill uses 13pt vertical padding.
    var height: CGFloat? = nil
    /// Stretch to the proposed width, so two pills in a row share it equally.
    var fillsWidth = false
    var action: () -> Void = {}

    @Local private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            pillLabel(title, color: Theme.text)
                .padding(.horizontal, 22)
                .padding(.vertical, height == nil ? 13 : 0)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(minHeight: height ?? 36)
                .frame(height: height)
                .background(Capsule().fill(Theme.elevated))
                .overlay(
                    Capsule().strokeBorder(isHovered ? Theme.lineStrong : Theme.border, lineWidth: 1)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Theme.ember.opacity(0.6), lineWidth: 1.5)
                        .padding(-2)
                        .opacity(isFocused ? 1 : 0)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PressDimStyle())
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .opacity(isEnabled ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
    }
}

/// Filter chip: elevated when unselected, ember-tinted when active.
struct FilterChip: View {
    let title: String
    let isActive: Bool
    var isDisabled = false
    /// Toolbar look of the prototype's `.filter-row button`: 10 pt text, no fill until active.
    var compact = false
    /// Compact chip that stays a visible button when not active (own fill and border, 12 pt text).
    var outlined = false
    var action: () -> Void

    @Local private var isHovered = false
    @FocusState private var isFocused: Bool

    private var textColor: Color {
        if outlined { return isActive ? Theme.ember : (isHovered ? Theme.text : Theme.textSecondary) }
        if compact { return isActive ? Color(hex: 0xe8e2db) : (isHovered ? Color(hex: 0xb2aca4) : Color(hex: 0x68645e)) }
        return isActive ? Theme.ember : (isHovered ? Theme.text : Theme.textSecondary)
    }

    private var fillColor: Color {
        if outlined { return isActive ? Theme.ember.opacity(0.14) : (isHovered ? Theme.elevated : Theme.elevated.opacity(0.6)) }
        if compact { return isActive ? Color(hex: 0x171513) : .clear }
        return isActive ? Theme.ember.opacity(0.14) : Theme.elevated
    }

    private var strokeColor: Color {
        if outlined { return isActive ? Theme.ember.opacity(0.45) : (isHovered ? Theme.lineStrong : Theme.border) }
        if compact { return isActive ? Color(hex: 0x37322f) : .clear }
        return isActive ? Theme.ember.opacity(0.4) : (isHovered ? Theme.lineStrong : Theme.border)
    }

    var body: some View {
        Button(action: action) {
            Text(tr: title)
                .style(.init(size: outlined ? 12 : (compact ? 10 : 14), weight: .medium, color: textColor))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, compact ? 13 : 16)
                .frame(height: compact ? 32 : 34)
                .frame(minWidth: 36, minHeight: compact ? 32 : 36)
                .background(Capsule().fill(fillColor))
                .overlay(Capsule().strokeBorder(strokeColor, lineWidth: 1))
                .overlay(
                    Capsule()
                        .strokeBorder(Theme.ember.opacity(0.6), lineWidth: 1.5)
                        .padding(-2)
                        .opacity(isFocused ? 1 : 0)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PressDimStyle())
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Ember gradient round play button with 40x40 min hit target.
struct RoundPlayButton: View {
    let instanceName: String
    var action: () -> Void = {}

    @Local private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    private let darkWarmText = Color(red: 27 / 255.0, green: 17 / 255.0, blue: 10 / 255.0)

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.emberGradient)
                Circle().strokeBorder(Theme.ember, lineWidth: 1)
                PlayTriangle()
                    .fill(darkWarmText)
                    .frame(width: 12, height: 12)
            }
            .frame(width: 36, height: 36)
            .shadow(color: Theme.emberSoft, radius: isHovered ? 8 : 4, y: 1)
            .overlay(
                Circle()
                    .strokeBorder(Theme.ember.opacity(0.8), lineWidth: 2)
                    .padding(-3)
                    .opacity(isFocused ? 1 : 0)
            )
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(PressDimStyle())
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .opacity(isEnabled ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .accessibilityLabel(L("Play %@", instanceName))
    }
}

/// Mono badge with uppercase caption, elevated fill, and border.
struct MonoBadge: View {
    let text: String

    var body: some View {
        Text(verbatim: text.uppercased())
            .style(.init(size: 11, weight: .medium, mono: true, color: Theme.textSecondary))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(Theme.elevated))
            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }
}

/// Square pixel face used as the account avatar (Steve-like: skin tone, dark eyes and mouth, darker chin band).
struct PixelAvatar: View {
    var size: CGFloat = 38
    var isHovered: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Helper to create colors from hex components.
    private func hex(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0)
    }

    // Cubic‑bezier helper for the eye blink easing.
    private static func bezier(_ t: Double, _ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double) -> Double {
        let u = 1 - t
        return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3
    }

    private static func ease(_ x: Double) -> Double {
        // Solve for t where x(t) = x using bisection (20 iterations).
        var lower = 0.0, upper = 1.0, t = 0.5
        for _ in 0..<20 {
            t = (lower + upper) / 2
            let xb = bezier(t, 0, 0.42, 0.58, 1)
            if xb < x {
                lower = t
            } else {
                upper = t
            }
        }
        // y(t) for the same t (control points y1=0, y2=1).
        return bezier(t, 0, 0, 1, 1)
    }

    private static func blinkClosedness(at elapsed: Double) -> Double {
        let phase = (elapsed.truncatingRemainder(dividingBy: 1.8)) / 1.8
        if phase < 0.45 {
            return 0
        } else if phase < 0.52 {
            return ease((phase - 0.45) / 0.07)
        } else if phase < 0.56 {
            return 1
        } else if phase < 0.62 {
            return 1 - ease((phase - 0.56) / 0.06)
        } else {
            return 0
        }
    }

    @Local private var blinkStart = Date()

    /// CSS "ease" for face geometry; none with Reduce Motion.
    private func geometry(_ seconds: Double) -> Animation? {
        reduceMotion ? nil : .timingCurve(0.25, 0.1, 0.25, 1, duration: seconds)
    }

    var body: some View {
        let k = size / 38
        let on = isHovered
        let move = on && !reduceMotion
        let colorAnim: Animation? = reduceMotion ? .easeOut(duration: 0.12) : geometry(0.3)
        let face = hex(0x17, 0x12, 0x0f)
        let mouth = hex(0x59, 0x3a, 0x2c)

        ZStack(alignment: .topLeading) {
            // Head square: warmer colour and a soft shadow on hover (shadow only on the head, not the face parts).
            Rectangle()
                .fill(on ? hex(0xc6, 0x8a, 0x5b) : hex(0xbb, 0x81, 0x53))
                .shadow(color: Color(red: 221 / 255, green: 139 / 255, blue: 82 / 255).opacity(on ? 0.16 : 0),
                        radius: 8 * k, x: 0, y: 6 * k)
                .animation(colorAnim, value: isHovered)

            // Chin band
            Rectangle()
                .fill(on ? hex(0x70, 0x47, 0x2f) : hex(0x6c, 0x45, 0x2d))
                .frame(height: 7 * k)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .animation(colorAnim, value: isHovered)

            // Left eye: 4x4 -> 6x2, shifted by (-1, +1)
            Rectangle()
                .fill(face)
                .frame(width: (on ? 6 : 4) * k, height: (on ? 2 : 4) * k)
                .offset(x: (on ? 7 : 8) * k, y: (on ? 13 : 12) * k)
                .animation(geometry(0.2), value: isHovered)

            // Right eye: blinks (1.8 s cycle) only while hovered; paused otherwise and with Reduce Motion
            TimelineView(.animation(paused: !on || reduceMotion)) { timeline in
                let closed = on && !reduceMotion
                    ? Self.blinkClosedness(at: timeline.date.timeIntervalSince(blinkStart))
                    : 0
                Rectangle()
                    .fill(face)
                    .frame(width: 4 * k, height: (4 - 3 * closed) * k)
                    .offset(x: size - 12 * k, y: (12 + 2 * closed) * k)
            }
            .frame(width: size, height: size, alignment: .topLeading)

            // Mouth: straight line -> smile (shorter centre 8x3 lowered by 2, two 3x3 corners 3 above it)
            Rectangle()
                .fill(mouth)
                .frame(width: (on ? 8 : 12) * k, height: 3 * k)
                .offset(x: (on ? 15 : 13) * k, y: (on ? 25 : 23) * k)
                .animation(geometry(0.22), value: isHovered)
            Rectangle()
                .fill(mouth)
                .frame(width: 3 * k, height: 3 * k)
                .offset(x: (on ? 12 : 10) * k, y: (on ? 22 : 23) * k)
                .opacity(on ? 1 : 0)
                .animation(geometry(0.22), value: isHovered)
                .animation(colorAnim, value: on)
            Rectangle()
                .fill(mouth)
                .frame(width: 3 * k, height: 3 * k)
                .offset(x: (on ? 23 : 25) * k, y: (on ? 22 : 23) * k)
                .opacity(on ? 1 : 0)
                .animation(geometry(0.22), value: isHovered)
                .animation(colorAnim, value: on)
        }
        .frame(width: size, height: size)
        // Whole avatar lifts, tilts and grows a little (layout size stays the same)
        .scaleEffect(move ? 1.04 : 1)
        .rotationEffect(.degrees(move ? -3 : 0))
        .offset(y: move ? -2 * k : 0)
        .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3), value: isHovered)
        .onChange(of: isHovered) { _, hovered in
            if hovered { blinkStart = Date() }
        }
        .accessibilityHidden(true)
    }
}

/// Account button in the top bar: pixel avatar, name with status line, chevron. Flat until hovered.
struct AccountPill: View {
    let name: String
    /// A Microsoft or Ember account is signed in; otherwise the player is on an offline nickname and is not "online" anywhere.
    var isSignedIn: Bool = false
    var action: () -> Void = {}

    @Local private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PixelAvatar(isHovered: isHovered)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: name).style(.init(size: 13, weight: .semibold, color: Theme.text))
                    Text(tr: isSignedIn ? "Online" : "Offline nickname").style(.init(size: 9, weight: .regular, mono: true, color: Color(red: 0x81/255, green: 0x7d/255, blue: 0x76/255)))
                }
                .frame(minWidth: 72, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 17, height: 17)
                    .accessibilityHidden(true)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? Color(red: 0x14/255, green: 0x14/255, blue: 0x13/255) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.ember.opacity(0.6), lineWidth: 1.5)
                    .opacity(isFocused ? 1 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressDimStyle())
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .opacity(isEnabled ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .accessibilityLabel(L("Account: %@", name))
    }
}

/// 40x40 icon button with elevated fill, border, and full interaction states.
struct IconButton: View {
    let systemName: String?
    let custom: AnyView?
    let label: String
    let help: String?
    let action: () -> Void

    @Local private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    init(
        systemName: String? = nil,
        custom: AnyView? = nil,
        label: String,
        help: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.custom = custom
        self.label = label
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if let custom = custom {
                    custom
                } else if let systemName = systemName {
                    Image(systemName: systemName)
                        .font(Theme.font(size: 15, weight: .medium))
                        .foregroundColor(isHovered ? Theme.text : Theme.textSecondary)
                }
            }
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .fill(isHovered ? Theme.surface : Theme.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .strokeBorder(isHovered ? Theme.lineStrong : Theme.border, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .strokeBorder(Theme.ember.opacity(0.6), lineWidth: 1.5)
                    .padding(-2)
                    .opacity(isFocused ? 1 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous))
        }
        .buttonStyle(PressDimStyle())
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .accessibilityLabel(label)
        .help(help ?? label)
    }
}

/// Compact status badge with mono uppercase caption and redundant icon.
struct StatusBadge: View {
    enum Kind {
        case success, warning, danger, info, neutral
    }

    let text: String
    let kind: Kind
    let systemImage: String?

    init(_ text: String, kind: Kind = .neutral, systemImage: String? = nil) {
        self.text = text
        self.kind = kind
        self.systemImage = systemImage
    }

    private var color: Color {
        switch kind {
        case .success:
            return Theme.success
        case .warning:
            return Theme.ember
        case .danger:
            return Theme.danger
        case .info:
            return Theme.violet
        case .neutral:
            return Theme.textSecondary
        }
    }

    private var defaultIcon: String {
        switch kind {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .danger:
            return "xmark.octagon.fill"
        case .info:
            return "info.circle.fill"
        case .neutral:
            return "circle"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Image(systemName: systemImage ?? defaultIcon)
                .font(Theme.font(size: 10, weight: .semibold))
                .foregroundColor(color)
                .accessibilityHidden(true)
            Text(verbatim: text.uppercased())
                .style(.init(size: 10, weight: .medium, mono: true, color: color))
        }
        .padding(.horizontal, Theme.Space.s)
        .padding(.vertical, Theme.Space.xs)
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
    }
}
