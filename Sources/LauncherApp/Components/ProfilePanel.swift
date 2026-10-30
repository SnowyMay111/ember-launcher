import SwiftUI

struct ProfilePanel: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var accounts: AccountStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Local private var isAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr: "YOUR PROFILE").style(.eyebrow)
                        .padding(.bottom, 4)
                    Text(displayName)
                        .font(Theme.font(size: 25, weight: .semibold))
                        .tracking(-1)
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: { app.modal = nil }) {
                    Circle()
                        .fill(Color(red: 0x20/255, green: 0x1e/255, blue: 0x20/255))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("×")
                                .font(.system(size: 18))
                                .foregroundColor(Color(red: 0x8e/255, green: 0x87/255, blue: 0x8e/255))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Close"))
            }
            .padding(.top, 25)
            .padding(.horizontal, 27)
            .padding(.bottom, 20)

            HStack(spacing: 16) {
                PixelAvatar(size: 55)
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(Theme.font(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(tr: accounts.isSignedIn ? "Microsoft account" : "Offline profile")
                        .font(Theme.font(size: 9))
                        .foregroundColor(Color(red: 0x67/255, green: 0x60/255, blue: 0x67/255))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color(red: 0x16/255, green: 0x14/255, blue: 0x16/255))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(Color(red: 0x29/255, green: 0x25/255, blue: 0x29/255), lineWidth: 1)
            )
            .padding(.top, 5)
            .padding(.horizontal, 22)
            .padding(.bottom, 25)

            VStack(spacing: 7) {
                profileRow(text: "Manage account", isDisabled: false) {
                    app.screen = .settings
                }
                if accounts.isSignedIn {
                    profileRow(text: "Sign out of Microsoft", isDisabled: false) {
                        accounts.signOut()
                    }
                } else {
                    profileRow(text: "Sign in with Microsoft", isDisabled: isWaitingForCode) {
                        accounts.signIn()
                    }
                }
            }
            .padding(.horizontal, 22)

            signInStatus
                .padding(.top, 18)
                .padding(.horizontal, 22)
        }
        .padding(.bottom, 22)
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0x11/255, green: 0x10/255, blue: 0x11/255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(red: 0x34/255, green: 0x2e/255, blue: 0x34/255), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.7), radius: 35, x: 0, y: 20)
        .shadow(color: Color(red: 105/255, green: 62/255, blue: 125/255).opacity(0.08), radius: 35, x: 0, y: 0)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: reduceMotion ? 0 : (isAppeared ? 0 : 12))
        .scaleEffect(reduceMotion ? 1 : (isAppeared ? 1 : 0.98))
        .onAppear { withAnimation(.easeOut(duration: 0.28)) { isAppeared = true } }
        .onExitCommand {
            app.modal = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("Your Profile"))
    }

    private var displayName: String { accounts.session?.name ?? settings.nickname }

    private var isWaitingForCode: Bool {
        if case .waitingForCode = accounts.phase { return true }
        return false
    }

    @ViewBuilder
    private var signInStatus: some View {
        let muted = Color(red: 0x67/255, green: 0x60/255, blue: 0x67/255)
        switch accounts.phase {
        case .idle:
            Text(tr: accounts.isSignedIn ? "Signed in. Online servers and your own skin are available." : "Without an account you play offline with the nickname from settings.")
                .font(Theme.font(size: 10))
                .foregroundColor(muted)
                .lineSpacing(6)
        case .waitingForCode(let userCode, let url):
            VStack(alignment: .leading, spacing: 10) {
                Text(tr: "Open the page and enter this code:")
                    .font(Theme.font(size: 10))
                    .foregroundColor(muted)
                Text(verbatim: userCode)
                    .font(Theme.font(size: 22, weight: .semibold, mono: true))
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                HStack(spacing: 14) {
                    profileRow(text: "Open Microsoft page", isDisabled: false) { NSWorkspace.shared.open(url) }
                    profileRow(text: "Cancel", isDisabled: false) { accounts.cancelSignIn() }
                }
            }
        case .failed(let message):
            Text(verbatim: message)
                .font(Theme.font(size: 10))
                .foregroundColor(Color(red: 0.93, green: 0.45, blue: 0.40))
                .lineSpacing(6)
        }
    }

    private func profileRow(text: String, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        ProfileRowButton(text: text, isDisabled: isDisabled, action: action)
    }

    private struct ProfileRowButton: View {
        let text: String
        let isDisabled: Bool
        let action: () -> Void
        @Local private var isHovering = false

        var body: some View {
            Button(action: action) {
                Text(tr: text)
                    .font(Theme.font(size: 11))
                    .foregroundColor(Color(red: 0xa1/255, green: 0x9a/255, blue: 0xa1/255))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isHovering ? Color(red: 0x1e/255, green: 0x1b/255, blue: 0x1e/255) : Color(red: 0x17/255, green: 0x15/255, blue: 0x17/255))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(red: 0x29/255, green: 0x26/255, blue: 0x29/255), lineWidth: 1)
                    )
            }
            .buttonStyle(PressDimStyle())
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.45 : 1.0)
            .onHover { hovering in
                isHovering = hovering && !isDisabled
            }
        }
    }
}
