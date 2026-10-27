import SwiftUI

/// Text with a gradient fill (hero second line).
struct GradientText: View {
    let text: String
    let style: Theme.TextStyle
    let gradient: LinearGradient

    var body: some View {
        Text(verbatim: text)
            .style(style)
            .hidden()
            .overlay(gradient.mask(Text(verbatim: text).style(style)))
    }
}

extension Color {
    /// 0xRRGGBB, for colours copied straight from the Ember prototype.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

private struct WindowWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 1426 }

extension EnvironmentValues {
    /// Width of the whole window, like the prototype's `vw` (its clamp() sizes follow the viewport).
    var windowWidth: CGFloat {
        get { self[WindowWidthKey.self] }
        set { self[WindowWidthKey.self] = newValue }
    }
}

/// Page header (prototype `.page-intro`): mono eyebrow, big tight-tracked title, copy, optional trailing primary action.
struct PageHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var alignment: HorizontalAlignment = .center
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.windowWidth) private var windowWidth

    /// clamp(34px, 5vw, 58px)
    private var titleSize: CGFloat { min(max(34, 0.05 * windowWidth), 58) }

    init(
        eyebrow: String,
        title: String,
        subtitle: String? = nil,
        alignment: HorizontalAlignment = .center,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.alignment = alignment
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Space.l) {
            VStack(alignment: alignment, spacing: 0) {
                Text(tr: eyebrow)
                    .style(.init(size: 10, weight: .medium, mono: true, tracking: 0.2, color: Color(hex: 0x7b7771), uppercase: true))
                    .padding(.bottom, 7)
                Text(tr: title)
                    .style(.init(size: titleSize, weight: .bold, tracking: -0.055, color: Theme.text))
                    .lineLimit(1)
                    // Negative tracking shortens the layout width; keep room so the last letter is not cut.
                    .padding(.trailing, titleSize * 0.06)
                    .frame(height: titleSize)
                if let subtitle {
                    Text(tr: subtitle)
                        .style(.init(size: 12, weight: .regular, color: Color(hex: 0x7f7a73)))
                        .padding(.top, 12)
                }
            }
            if let actionTitle, let action {
                Spacer(minLength: Theme.Space.m)
                Button(action: action) {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(tr: actionTitle)
                            .style(.init(size: 14, weight: .semibold, color: Color(hex: 0x1b110a)))
                    }
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundColor(Color(hex: 0x1b110a))
                    .padding(.horizontal, 22)
                    .frame(height: 40)
                    .background(Capsule().fill(Theme.emberGradient))
                    .overlay(Capsule().strokeBorder(Theme.ember, lineWidth: 1))
                    .shadow(color: Theme.emberSoft, radius: 8, y: 2)
                }
                .buttonStyle(PressDimStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center))
    }
}

/// The four instance artworks of the prototype (`.instance-art`): the same dusk scene in different palettes.
enum PreviewVariant {
    case dusk, violet, gold, void

    fileprivate var palette: (Color, Color, Color) {
        switch self {
        case .dusk: (Color(hex: 0x31233b), Color(hex: 0x34211b), Color(hex: 0x151512))
        case .violet: (Color(hex: 0x281e38), Color(hex: 0x4a2941), Color(hex: 0x121311))
        case .gold: (Color(hex: 0x56434a), Color(hex: 0x7b4d2d), Color(hex: 0x1b1913))
        case .void: (Color(hex: 0x19151f), Color(hex: 0x2c1a39), Color(hex: 0x0c0c0d))
        }
    }
}

extension LibraryInstance {
    var previewVariant: PreviewVariant {
        if minecraftVersion.range(of: #"^\d+\.\d+(\.\d+)?$"#, options: .regularExpression) == nil { return .void }
        switch loader {
        case .vanilla: return .dusk
        case .fabric: return .violet
        default: return .gold
        }
    }
}

private struct PreviewTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A pixel tree: 8×55 trunk with a 45×48 crown whose top sits 23 pt above the trunk top.
private struct PreviewTree: View {
    let scale: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color(hex: 0x10110e))
            .frame(width: 8, height: 55)
            .overlay(alignment: .top) {
                PreviewTriangle().fill(Color(hex: 0x141610)).frame(width: 45, height: 48).offset(y: -23)
            }
            .scaleEffect(scale)
    }
}

/// Instance artwork: hard-horizon gradient, sun and three trees, as in the prototype.
struct InstancePreview: View {
    let variant: PreviewVariant

    var body: some View {
        let (top, mid, ground) = variant.palette
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: top, location: 0),
                        .init(color: mid, location: 0.58),
                        .init(color: ground, location: 0.59),
                        .init(color: ground, location: 1)
                    ],
                    startPoint: UnitPoint(x: 0.454, y: -0.223),
                    endPoint: UnitPoint(x: 0.546, y: 1.223)
                )
                Circle()
                    .fill(Color(hex: 0xe99a61))
                    .frame(width: 35, height: 35)
                    .shadow(color: Color(hex: 0xe99a61, opacity: 0.5), radius: 15)
                    .position(x: w - 0.16 * w - 17.5, y: 0.22 * h + 17.5)
                PreviewTree(scale: 1).position(x: w - 0.12 * w - 4, y: h - 27.5)
                PreviewTree(scale: 0.75).position(x: w - 0.33 * w - 4, y: h - 27.5)
                PreviewTree(scale: 0.55).position(x: 0.20 * w + 4, y: h - 27.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Small round play button of an instance card (prototype `.instance-info button`).
private struct CardPlayButton: View {
    let instanceName: String
    let action: () -> Void

    @Local private var isHovered = false

    var body: some View {
        Button(action: action) {
            PlayTriangle()
                .fill(isHovered ? Color(hex: 0x1b110a) : Theme.ember)
                .frame(width: 11, height: 11)
                .frame(width: 35, height: 35)
                .background(Circle().fill(isHovered ? Theme.ember : Color(hex: 0x171615)))
                .overlay(Circle().strokeBorder(Color(hex: 0x3a3733), lineWidth: 1))
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(PressDimStyle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .accessibilityLabel(L("Play %@", instanceName))
    }
}

/// Instance card (prototype `.instance-card`): artwork, name and version line, play button, last played / Manage / playtime.
struct InstanceCard: View {
    let instance: LibraryInstance
    var onOpen: () -> Void
    var onPlay: () -> Void = {}
    var onDelete: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Local private var isHovered = false
    @Local private var manageHovered = false

    private var detail: String {
        instance.versionLine + (instance.modCount > 0 ? " · \(instance.modCount) mods" : "")
    }

    private let metaColor = Color(hex: 0x5d5954)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InstancePreview(variant: instance.previewVariant)
                .frame(height: 126)
                .padding(10)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: instance.name)
                        .style(.init(size: 14, weight: .bold, color: Theme.text))
                        .lineLimit(1)
                    Text(verbatim: detail)
                        .style(.init(size: 9, weight: .regular, color: Color(hex: 0x6f6a64)))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                CardPlayButton(instanceName: instance.name, action: onPlay)
                    .padding(.trailing, -2.5)
            }
            .padding(.horizontal, 17)
            .padding(.top, 4)
            .padding(.bottom, 15)

            Color(hex: 0x201f1d).frame(height: 1)

            HStack(spacing: 0) {
                Text(verbatim: instance.lastPlayedAgo)
                    .style(.init(size: 8, weight: .medium, mono: true, color: metaColor, uppercase: true))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button(action: onOpen) {
                    Text(tr: "Manage")
                        .style(.init(size: 8, weight: .medium, mono: true, color: manageHovered ? Theme.ember : Color(hex: 0x776d67)))
                }
                .buttonStyle(.plain)
                .onHover { manageHovered = $0 }
                .padding(.trailing, 14)
                Text(verbatim: instance.playtimeText)
                    .style(.init(size: 8, weight: .medium, mono: true, color: Color(hex: 0x88827a)))
                    .lineLimit(1)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 12)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(isHovered ? Color(hex: 0x3b342f) : Color(hex: 0x242321), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.2 : 0), radius: 20, y: 18)
        .offset(y: (isHovered && !reduceMotion) ? -2 : 0)
        .animation(.easeOut(duration: 0.25), value: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .onTapGesture(perform: onOpen)
        .overlay(alignment: .topTrailing) {
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(Theme.font(size: 12))
                        .foregroundColor(Color(hex: 0xd8d2ca))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(16)
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .allowsHitTesting(isHovered)
                .accessibilityLabel(L("Delete"))
                .accessibilityAction(named: L("Delete"), onDelete)
            }
        }
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(instance.name)
        .accessibilityAction(named: L("Open"), onOpen)
    }
}

/// Stat card: surface/elevated look, mono uppercase labels, hairline borders.
struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(tr: label)
                .style(.init(size: 10, weight: .medium, mono: true, tracking: 0.14, color: Theme.textMuted, uppercase: true))
            Text(verbatim: value)
                .style(.statValue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Settings row: surface/elevated look, Manrope title with a quiet description, hairline borders.
struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String
    var isLast = false
    @ViewBuilder var control: () -> Control

    @Local private var isHovered = false

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr: title)
                    .style(.row)
                Text(tr: detail)
                    .style(.init(size: 12.5, weight: .regular, tracking: -0.005, color: Theme.textSecondary))
            }
            Spacer(minLength: Theme.Space.m)
            control()
        }
        .frame(minHeight: 68)
        .padding(.horizontal, 24)
        .background(isHovered ? Color.white.opacity(0.015) : Theme.surface)
        .overlay(alignment: .bottom) {
            if !isLast {
                Theme.border.frame(height: 1)
            }
        }
        .onHover { isHovered = $0 }
    }
}
