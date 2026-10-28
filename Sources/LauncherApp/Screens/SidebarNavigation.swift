import SwiftUI

public struct SidebarNavigation: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Fixed slot for the traffic lights (window mode) or the empty strip they leave (fullscreen):
            // the logo sits at the same place in both and keeps clear of the lights and the first nav button.
            Color.clear
                .frame(height: 58)

            // App branding logo
            EmberLogo(size: 36)
                .padding(.bottom, 40)

            // Primary navigation destinations
            VStack(spacing: 10) {
                navButton(
                    screen: .play,
                    title: L("Play"),
                    systemName: "house",
                    shortcutKey: "1"
                )

                navButton(
                    screen: .library,
                    title: L("Library"),
                    systemName: "square.grid.2x2",
                    shortcutKey: "2"
                )

                navButton(
                    screen: .social,
                    title: L("Social"),
                    systemName: "person.2",
                    shortcutKey: "3"
                )

                navButton(
                    screen: .mods,
                    title: L("Explore"),
                    systemName: "arrow.down.to.line",
                    shortcutKey: "4"
                )

                navButton(
                    screen: .skins,
                    title: L("Skins"),
                    systemName: "tshirt",
                    shortcutKey: "5"
                )
            }

            Spacer()

            // Operational status indicator
            Circle()
                .fill(Theme.success)
                .frame(width: 8, height: 8)
                .help(L("All systems operational"))
                .accessibilityLabel(L("All systems operational"))
                .padding(.bottom, 14)

            // Pinned settings destination
            navButton(
                screen: .settings,
                title: L("Settings"),
                systemName: "gearshape",
                shortcutKey: "6"
            )
            .padding(.bottom, 18)
        }
        .frame(width: compact ? 64 : 84)
        .background(Color(red: 11 / 255, green: 11 / 255, blue: 11 / 255).opacity(0.88))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.border)
                .frame(width: 1)
        }
        .background(WindowDragArea())
    }

    private func navButton(
        screen: Screen,
        title: String,
        systemName: String,
        shortcutKey: KeyEquivalent
    ) -> some View {
        SidebarNavButton(
            title: title,
            systemName: systemName,
            shortcutKey: shortcutKey,
            isSelected: app.screen == screen
        ) {
            switchScreen(to: screen)
        }
    }

    private func switchScreen(to screen: Screen) {
        if reduceMotion {
            app.screen = screen
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                app.screen = screen
            }
        }
    }
}

private struct SidebarNavButton: View {
    let title: String
    let systemName: String
    let shortcutKey: KeyEquivalent
    let isSelected: Bool
    let action: () -> Void

    @Local private var isHovered: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(Theme.font(size: 18, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.ember, lineWidth: 2)
                        .padding(-2)
                        .opacity(isFocused ? 1 : 0)
                )
        }
        .buttonStyle(SidebarNavButtonStyle())
        .focused($isFocused)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(title)
        .accessibilityLabel(title)
        .keyboardShortcut(shortcutKey, modifiers: .command)
    }

    private var iconColor: Color {
        if isSelected {
            return Theme.ember
        } else if isHovered {
            return Theme.text
        } else {
            return Theme.textMuted
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Theme.ember.opacity(0.12)
        } else if isHovered {
            return Theme.surface.opacity(0.6)
        } else {
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Theme.ember.opacity(0.4)
        } else {
            return Color.clear
        }
    }
}

private struct SidebarNavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1.0)
    }
}
