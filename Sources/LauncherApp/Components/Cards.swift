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

/// Page header: eyebrow, h1, optional muted line.
struct PageHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 10) {
            Text(tr: eyebrow).style(.eyebrow)
            Text(tr: title).style(.pageTitle)
            if let subtitle {
                Text(tr: subtitle).style(.body16)
            }
        }
    }
}

/// Instance card: preview, name, version line, last played and play button.
struct InstanceCard: View {
    let instance: LibraryInstance
    var onOpen: () -> Void
    var onPlay: () -> Void = {}
    var onDelete: (() -> Void)? = nil

    @Local private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InstancePreview(glow: instance.glow)
                .frame(height: 80)

            Text(verbatim: instance.name)
                .style(.cardTitle)
                .lineLimit(1)
                .padding(.top, 14)
            Text(verbatim: instance.versionLine)
                .style(.secondary)
                .padding(.top, 3)

            HStack {
                Text(verbatim: instance.lastPlayedAgo)
                    .style(.init(size: 11, weight: .regular, mono: true, tracking: 0.14, color: Theme.muted, uppercase: true))
                    .lineLimit(1)
                Spacer(minLength: 8)
                RoundPlayButton(instanceName: instance.name, action: onPlay)
            }
            .padding(.top, 12)
        }
        .padding(14)
        .glass()
        .contentShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .onTapGesture(perform: onOpen)
        .overlay(alignment: .topTrailing) {
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(8)
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

/// Black preview tile with one soft white radial glow (to be replaced by the instance icon).
struct InstancePreview: View {
    let glow: PreviewGlow

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                RadialGradient(
                    stops: [
                        .init(color: Color.white.opacity(glow.opacity), location: 0),
                        .init(color: .clear, location: 1),
                    ],
                    center: UnitPoint(x: glow.x, y: glow.y),
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.55
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// Stat card: mono caption and a 24pt value.
struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr: label).style(.eyebrow)
            Text(verbatim: value).style(.statValue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .glass()
        .accessibilityElement(children: .combine)
    }
}

/// Settings row: name and description on the left, control on the right. The last row has no divider.
struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String
    var isLast = false
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tr: title).style(.row)
                Text(tr: detail).style(.secondary)
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 24)
        .overlay(alignment: .bottom) {
            if !isLast {
                Theme.line.frame(height: 1)
            }
        }
    }
}
