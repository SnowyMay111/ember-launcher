import SwiftUI

/// Card displaying a mod with icon, details and action buttons.
struct ModCard<Actions: View>: View {
    let iconURL: URL?
    let paletteIndex: Int
    let category: String
    let title: String
    let summary: String
    let footnote: String
    var note: (text: String, isWarning: Bool)? = nil
    var isDimmed = false
    var onOpen: (() -> Void)? = nil
    @ViewBuilder var actions: () -> Actions

    @Local private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var placeholderGradient: LinearGradient {
        let idx = abs(paletteIndex) % 4
        let palettes: [(Color, Color)] = [
            (Color(hex: 0x514161), Color(hex: 0x241d2a)),
            (Color(hex: 0x6d4634), Color(hex: 0x2b1e18)),
            (Color(hex: 0x465441), Color(hex: 0x1d251c)),
            (Color(hex: 0x66517b), Color(hex: 0x2b2432))
        ]
        let (c1, c2) = palettes[idx]
        return LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            iconView
                .frame(width: 55, height: 55)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: category)
                    .style(.init(size: 12, weight: .medium, color: Color(hex: 0xa9809c)))
                Text(verbatim: title)
                    .style(.init(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(verbatim: summary)
                    .style(.init(size: 13, color: Color(hex: 0x8d877f), lineSpacing: 4))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: footnote)
                    .style(.init(size: 12, color: Color(hex: 0x7a756e)))
                if let note = note {
                    Text(verbatim: note.text)
                        .style(.init(size: 12,
                                     color: note.isWarning ? Theme.danger.opacity(0.9) : Color(hex: 0x8f9d72)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .center, spacing: 7) {
                actions()
            }
            .frame(width: 100)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 170, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: 0x111110))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isHovered ? Color(hex: 0x3b342f) : Color(hex: 0x242321), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.2 : 0), radius: 20, y: 18)
        .offset(y: (isHovered && !reduceMotion) ? -2 : 0)
        .animation(.easeOut(duration: 0.25), value: isHovered)
        .opacity(isDimmed ? 0.55 : 1)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            if let open = onOpen {
                open()
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let url = iconURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty, .failure:
                    placeholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            placeholderGradient
            Rectangle()
                .fill(Color(hex: 0xb27bc4))
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(12))
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(height: 7)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                )
        }
    }
}

/// Single action button used in ``ModCard``.
struct ModActionButton: View {
    enum Kind { case normal, installed, text }

    let title: String
    var kind: Kind = .normal
    var isDisabled = false
    var action: () -> Void = {}

    @Local private var isHovered = false

    private var baseColor: Color {
        switch kind {
        case .normal: return Color(hex: 0xc0b8b0)
        case .installed: return Color(hex: 0x8f9d72)
        case .text: return Color(hex: 0x9a948c)
        }
    }

    private var borderColor: Color {
        switch kind {
        case .normal: return Color(hex: 0x3a3531)
        case .installed: return Color(hex: 0x343b2a)
        case .text: return .clear
        }
    }

    private var hoverBorder: Color {
        switch kind {
        case .normal: return Color(hex: 0x584236)
        case .installed: return Color(hex: 0x584236)
        case .text: return .clear
        }
    }

    private var hoverColor: Color {
        switch kind {
        case .normal, .installed: return Theme.ember
        case .text: return Color(hex: 0xb2aca4)
        }
    }

    var body: some View {
        Button(action: {
            if !isDisabled { action() }
        }) {
            Text(tr: title)
                .style(.init(size: 13, weight: .medium, color: isDisabled ? baseColor.opacity(0.5) : (isHovered ? hoverColor : baseColor)))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isHovered ? hoverBorder : borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .disabled(isDisabled)
        .onHover { isHovered = $0 }
        .accessibilityLabel(L(title))
    }

    @ViewBuilder
    private var backgroundColor: some View {
        switch kind {
        case .normal:
            Color(hex: 0x191715)
        case .installed:
            Color(hex: 0x171a13)
        case .text:
            Color.clear
        }
    }
}