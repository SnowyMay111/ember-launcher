import SwiftUI
import LauncherCore

/// Sign-in and sign-up dialog for the Ember account. Skippable: the launcher works without an account.
struct EmberAuthPanel: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var ember: EmberAccountStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Mode { case signIn, signUp }

    @Local private var mode: Mode = .signIn
    @Local private var email = ""
    @Local private var password = ""
    @Local private var tag = ""
    @Local private var displayName = ""
    @Local private var isAppeared = false

    private var isWorking: Bool { ember.phase == .working }

    private var canSubmit: Bool {
        guard ember.isConfigured, !isWorking, email.contains("@"), password.count >= 6 else { return false }
        return mode == .signIn || (tag.count >= 3 && !displayName.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 14) {
                providerRow
                HStack(spacing: 10) {
                    Rectangle().fill(Theme.border).frame(height: 1)
                    Text(tr: "or with email").font(Theme.font(size: 11)).foregroundColor(Theme.textMuted)
                    Rectangle().fill(Theme.border).frame(height: 1)
                }
                VoxelInput(label: "Email", text: $email, placeholder: L("Email"))
                VoxelSecureInput(label: "Password", text: $password, placeholder: L("Password"))
                if mode == .signUp {
                    VoxelInput(label: "Tag", text: $tag, placeholder: L("Unique tag, e.g. kotiki"))
                    VoxelInput(label: "Display name", text: $displayName, placeholder: L("Display name"))
                }
                submitButton
                HStack {
                    Button(mode == .signIn ? L("Create an account") : L("I already have an account")) {
                        mode = mode == .signIn ? .signUp : .signIn
                        ember.clearMessage()
                    }
                    Spacer()
                    if mode == .signIn {
                        Button(L("Forgot password?")) { ember.resetPassword(email: email) }
                            .disabled(!email.contains("@") || isWorking)
                    }
                }
                .buttonStyle(.plain)
                .font(Theme.font(size: 12, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                message
            }
            .padding(.horizontal, 27)
            Button(L("Continue without an account")) { app.modal = nil }
                .buttonStyle(.plain)
                .font(Theme.font(size: 11))
                .foregroundColor(Theme.textMuted)
                .padding(.top, 18)
                .padding(.horizontal, 27)
        }
        .padding(.bottom, 24)
        .frame(width: 440)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(red: 0x11/255, green: 0x10/255, blue: 0x11/255)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color(red: 0x34/255, green: 0x2e/255, blue: 0x34/255), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.7), radius: 35, x: 0, y: 20)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: reduceMotion ? 0 : (isAppeared ? 0 : 12))
        .onAppear {
            ember.clearMessage()
            withAnimation(.easeOut(duration: 0.28)) { isAppeared = true }
        }
        .onChange(of: ember.isSignedIn) { signedIn in
            if signedIn { app.modal = .profile }
        }
        .onExitCommand { app.modal = nil }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("Ember account"))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr: "EMBER ACCOUNT").style(.eyebrow)
                Text(tr: mode == .signIn ? "Sign in" : "Create account")
                    .font(Theme.font(size: 25, weight: .semibold))
                    .tracking(-1)
                    .foregroundColor(.white)
            }
            Spacer()
            Button(action: { app.modal = nil }) {
                Circle()
                    .fill(Color(red: 0x20/255, green: 0x1e/255, blue: 0x20/255))
                    .frame(width: 32, height: 32)
                    .overlay(Text("×").font(.system(size: 18)).foregroundColor(Color(red: 0x8e/255, green: 0x87/255, blue: 0x8e/255)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("Close"))
        }
        .padding(.top, 25)
        .padding(.horizontal, 27)
        .padding(.bottom, 18)
    }

    private var providerRow: some View {
        HStack(spacing: 8) {
            ForEach(EmberOAuthProvider.allCases, id: \.self) { provider in
                Button { ember.signIn(with: provider) } label: {
                    Text(verbatim: Self.title(provider))
                        .font(Theme.font(size: 12, weight: .medium))
                        .foregroundColor(Theme.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.elevated))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(!ember.isConfigured || isWorking)
            }
        }
    }

    private var submitButton: some View {
        Button {
            if mode == .signIn {
                ember.signIn(email: email, password: password)
            } else {
                ember.signUp(email: email, password: password, tag: tag, displayName: displayName)
            }
        } label: {
            Text(tr: isWorking ? "Please wait…" : (mode == .signIn ? "Sign in" : "Create account"))
                .font(Theme.font(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 27/255, green: 17/255, blue: 10/255))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Theme.emberGradient)
                .cornerRadius(Theme.radiusCompact)
                .opacity(canSubmit ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }

    @ViewBuilder private var message: some View {
        if !ember.isConfigured {
            Text(tr: "Ember accounts are not set up in this build.")
                .font(Theme.font(size: 11)).foregroundColor(Theme.textMuted)
        } else {
            switch ember.phase {
            case .notice(let text): Text(verbatim: text).font(Theme.font(size: 11)).foregroundColor(Theme.success)
            case .failed(let text): Text(verbatim: text).font(Theme.font(size: 11)).foregroundColor(Theme.danger)
            default: EmptyView()
            }
        }
    }

    private static func title(_ provider: EmberOAuthProvider) -> String {
        switch provider {
        case .google: return "Google"
        case .azure: return "Microsoft"
        case .discord: return "Discord"
        }
    }
}
