import SwiftUI

/// Top bar on every screen: greeting eyebrow and title on the left, Java runtime badge and account on the right.
struct TopBar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

    private var pageTitle: String {
        switch app.screen {
        case .play:
            return L("Welcome home.")
        case .library:
            return L("Instances")
        case .mods:
            return L("Mods")
        case .skins:
            return L("Skins")
        case .settings:
            return L("Settings")
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: L("Welcome back"))
                    .font(Theme.font(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0x7b/255, green: 0x77/255, blue: 0x71/255))

                Text(pageTitle)
                    .font(Theme.font(size: 23, weight: .semibold))
                    .tracking(-0.69)
                    .foregroundColor(Theme.text)
            }

            Spacer(minLength: 16)

            HStack(spacing: 24) {
                UpdatePill()
                AccountPill(name: settings.nickname) { app.modal = .profile }
            }
        }
        .padding(.horizontal, 71)
        .frame(height: 116)
        .background(WindowDragArea())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }
}

/// Java runtime chip next to the account (64x28 in the design: 9 pt mono, dark fill, thin border).
private struct RuntimeChip: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .style(.init(size: 9, weight: .medium, mono: true, color: Color(red: 0x94/255, green: 0x8c/255, blue: 0x99/255)))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(Color(red: 0x12/255, green: 0x10/255, blue: 0x14/255)))
            .overlay(Capsule().strokeBorder(Color(red: 0x2d/255, green: 0x29/255, blue: 0x2f/255), lineWidth: 1))
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


