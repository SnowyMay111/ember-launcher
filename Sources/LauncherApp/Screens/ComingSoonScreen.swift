import SwiftUI

/// Mods and Skins: header as on Settings, nothing below yet.
struct ComingSoonScreen: View {
    let title: String

    var body: some View {
        VStack {
            PageHeader(eyebrow: title, title: title, subtitle: "Coming soon.")
                .padding(.top, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// Sample content of screens that are not wired up yet: dimmed, not clickable, marked "Coming soon".
private struct SoonPreview: ViewModifier {
    let badge: Bool

    func body(content: Content) -> some View {
        content
            .opacity(0.4)
            .allowsHitTesting(false)
            .overlay {
                if badge {
                    Text(verbatim: L("Coming soon.").replacingOccurrences(of: ".", with: ""))
                        .font(Theme.font(size: 12, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Theme.surface)
                        .cornerRadius(Theme.radiusCompact)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusCompact).stroke(Theme.border, lineWidth: 1))
                }
            }
    }
}

extension View {
    func soonPreview(badge: Bool = true) -> some View {
        modifier(SoonPreview(badge: badge))
    }
}
