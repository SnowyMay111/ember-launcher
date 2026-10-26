import SwiftUI

/// Top bar on every screen: native window buttons on the left, brand, navigation, Java badge and account.
struct TopBar: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Room for the native traffic lights.
            Color.clear.frame(width: 86, height: 1)

            HStack(spacing: 10) {
                CubeIcon()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text(tr: "Voxel").style(.init(size: 15, weight: .semibold, color: Theme.ink))
            }

            HStack(spacing: 22) {
                ForEach(Screen.allCases) { screen in
                    NavItem(screen: screen, isActive: app.screen == screen) { app.screen = screen }
                }
            }
            .padding(.leading, 36)

            Spacer(minLength: 16)

            HStack(spacing: 12) {
                MonoBadge(text: "Java 21")
                AccountPill(name: "Nickname")
            }
            .padding(.trailing, 20)
        }
        .frame(height: 56)
        .topBarBackground()
    }
}

private struct NavItem: View {
    let screen: Screen
    let isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tr: screen.rawValue)
                .style(.init(size: 14, weight: .regular, color: isActive ? Theme.ink : Theme.muted))
                .frame(minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
