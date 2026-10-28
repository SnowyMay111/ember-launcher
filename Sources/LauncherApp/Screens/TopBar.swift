import SwiftUI

/// Top bar on every screen: greeting eyebrow and title on the left, Java runtime badge and account on the right.
struct TopBar: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

    private var pageTitle: String {
        switch app.screen {
        case .play:
            return L("Welcome home.")
        case .social:
            return L("Social")
        case .library:
            return L("Instances")
        case .mods:
            return L("Explore")
        case .skins:
            return L("Skins")
        case .settings:
            return L("Settings")
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if app.screen != .settings {
                VStack(alignment: .leading, spacing: 7) {
                    Text(verbatim: L("Welcome back"))
                        .font(Theme.font(size: 12, weight: .medium))
                        .foregroundColor(Color(red: 0x7b/255, green: 0x77/255, blue: 0x71/255))

                    Text(pageTitle)
                        .font(Theme.font(size: 23, weight: .semibold))
                        .tracking(-0.69)
                        .foregroundColor(Theme.text)
                }
            }

            Spacer(minLength: 16)

            HStack(spacing: 16) {
                UpdatePill()
                SocialTopButton {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        app.friendsDrawerOpen.toggle()
                    }
                }
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

private struct SocialTopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                HStack(spacing: -6) {
                    avatarCircle("M", bg: Color(red: 102/255, green: 75/255, blue: 60/255))
                    avatarCircle("L", bg: Color(red: 83/255, green: 94/255, blue: 71/255))
                    avatarCircle("N", bg: Color(red: 93/255, green: 72/255, blue: 94/255))
                }
                .padding(.leading, 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "3 online")
                        .font(Theme.font(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 216/255, green: 208/255, blue: 198/255))
                    Text(verbatim: "Friends")
                        .font(Theme.font(size: 9, weight: .regular))
                        .foregroundColor(Color(red: 142/255, green: 136/255, blue: 128/255))
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(red: 142/255, green: 136/255, blue: 128/255))
                    .padding(.trailing, 2)
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background(Color(red: 17/255, green: 16/255, blue: 14/255))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 41/255, green: 38/255, blue: 34/255), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func avatarCircle(_ letter: String, bg: Color) -> some View {
        ZStack {
            Circle()
                .fill(bg)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color(red: 17/255, green: 16/255, blue: 14/255), lineWidth: 2))
            Text(letter)
                .font(Theme.font(size: 8, weight: .bold))
                .foregroundColor(.white)
        }
    }
}


