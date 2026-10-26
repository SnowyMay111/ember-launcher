import SwiftUI

/// Top bar on every screen: native window buttons on the left, brand, navigation, Java badge and account.
struct TopBar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

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
                UpdatePill()
                MonoBadge(text: "Java 21")
                AccountPill(name: settings.nickname)
            }
            .padding(.trailing, 20)
        }
        .frame(height: 56)
        .topBarBackground()
    }
}

/// Shown while a newer launcher is known: offers it, shows the download, then offers the restart.
private struct UpdatePill: View {
    @EnvironmentObject var updates: UpdateController

    private var content: (title: String, isDisabled: Bool)? {
        switch updates.state {
        case .idle:
            return nil
        case .available, .failed:
            guard let info = updates.info else { return nil }
            return (L("Update to %@", info.version), false)
        case .downloading(let fraction):
            return (L("Updating… %d%%", Int(fraction * 100)), true)
        case .ready:
            return updates.isWaitingForGame ? (L("Update after you close the game"), true) : (L("Restart to update"), false)
        }
    }

    var body: some View {
        if let content {
            PrimaryPill(title: content.title, height: 32, horizontalPadding: 16, isDisabled: content.isDisabled) {
                updates.pillAction()
            }
        }
    }
}

/// Why the last update failed, floating under the top bar until it is dismissed or tried again.
struct UpdateNotice: View {
    @EnvironmentObject var updates: UpdateController

    var body: some View {
        if case .failed(let message) = updates.state {
            HStack(spacing: 12) {
                Text(verbatim: message).style(.secondary)
                Button(action: updates.dismissError) {
                    Text(tr: "Dismiss").style(.init(size: 13, weight: .medium, color: Theme.text))
                }
                .buttonStyle(PressDimStyle())
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Capsule().fill(Theme.black40))
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
            .padding(.top, 10)
        }
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
