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

/// White pill, black text. In the hero it carries a small filled play triangle.
struct PrimaryPill: View {
    let title: String
    var showsPlay = false
    /// Fixed height (toolbar: 42). Without it the pill uses 13pt vertical padding (hero).
    var height: CGFloat? = nil
    var horizontalPadding: CGFloat = 30
    var isDisabled = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if showsPlay {
                    PlayTriangle()
                        .fill(Color.black)
                        .frame(width: 11, height: 11)
                        .accessibilityHidden(true)
                }
                pillLabel(title, color: .black)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, height == nil ? 13 : 0)
            .frame(height: height)
            .frame(minHeight: 36)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().strokeBorder(Color.white, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressDimStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

struct SecondaryPill: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            pillLabel(title, color: Theme.text)
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .frame(minHeight: 36)
                .background(Capsule().fill(Theme.black40))
                .overlay(Capsule().strokeBorder(Theme.lineStrong, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressDimStyle())
    }
}

/// Filter chip: white when active, outlined when not.
struct FilterChip: View {
    let title: String
    let isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tr: title)
                .style(.init(size: 14, weight: .medium, color: isActive ? .black : Theme.text))
                .padding(.horizontal, 16)
                .frame(height: 34)
                .frame(minWidth: 36, minHeight: 36)
                .background(Capsule().fill(isActive ? Color.white : Color.clear))
                .overlay(Capsule().strokeBorder(isActive ? Color.white : Theme.line, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressDimStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// 36×36 round play button on an instance card.
struct RoundPlayButton: View {
    let instanceName: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.black30)
                Circle().strokeBorder(Color.white, lineWidth: 1)
                PlayTriangle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(PressDimStyle())
        .accessibilityLabel(L("Play %@", instanceName))
    }
}

/// Mono badge, e.g. "Java 21".
struct MonoBadge: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .style(.init(size: 12, weight: .regular, mono: true, color: Theme.text))
            .padding(.horizontal, 14)
            .frame(height: 34)
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
    }
}

/// White account pill with a grey avatar circle.
struct AccountPill: View {
    let name: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(LinearGradient(colors: [Theme.muted, Theme.lineStrong], startPoint: .top, endPoint: .bottom))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text(verbatim: name).style(.init(size: 14, weight: .medium, color: .black))
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .frame(height: 36)
            .background(Capsule().fill(Color.white))
            .contentShape(Capsule())
        }
        .buttonStyle(PressDimStyle())
        .accessibilityLabel(L("Account: %@", name))
    }
}
