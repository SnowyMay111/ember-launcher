import SwiftUI

struct LobbyFlowModal: View {
    @EnvironmentObject var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Local private var selectedWorld = "Birch Hollow"
    @Local private var privacy = "Friends only"
    @Local private var isCreated = false
    @Local private var allowCheats = false
    @Local private var friendsCanInvite = true
    @Local private var copiedCode = false

    private let privacyOptions: [(title: String, desc: String)] = [
        ("Friends only", "Anyone on your friends list"),
        ("Invite only", "Only people with an invite"),
        ("Public", "Visible to everyone in Social")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "TEMPORARY LOBBY")
                        .font(Theme.font(size: 10, weight: .medium, mono: true))
                        .tracking(1.4)
                        .foregroundColor(Color(red: 143/255, green: 109/255, blue: 89/255))

                    Text(verbatim: isCreated ? "Lobby is ready" : "Bring friends in")
                        .font(Theme.font(size: 24, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundColor(Theme.text)
                }

                Spacer()

                Button {
                    app.modal = nil
                } label: {
                    Circle()
                        .fill(Color(hex: 0x201e20))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("×")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: 0x8e878e))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
            .padding(.horizontal, 28)
            .padding(.bottom, 18)

            Divider().background(Theme.border)

            if isCreated {
                readyView
            } else {
                setupView
            }
        }
        .frame(width: 540)
        .background(Color(red: 17/255, green: 16/255, blue: 17/255))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(red: 52/255, green: 46/255, blue: 52/255), lineWidth: 1)
        )
    }

    // MARK: - Setup View

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // World picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "WORLD")
                            .font(Theme.font(size: 10, weight: .medium, mono: true))
                            .tracking(1.2)
                            .foregroundColor(Theme.textSecondary)

                        HStack {
                            Text(selectedWorld)
                                .font(Theme.font(size: 13, weight: .medium))
                                .foregroundColor(Theme.text)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Color(red: 24/255, green: 22/255, blue: 24/255))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                        .onTapGesture {
                            selectedWorld = (selectedWorld == "Birch Hollow") ? "Ember Valley" : "Birch Hollow"
                        }
                    }

                    // Privacy options
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "WHO CAN JOIN")
                            .font(Theme.font(size: 10, weight: .medium, mono: true))
                            .tracking(1.2)
                            .foregroundColor(Theme.textSecondary)

                        VStack(spacing: 0) {
                            ForEach(Array(privacyOptions.enumerated()), id: \.offset) { index, opt in
                                Button {
                                    privacy = opt.title
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .stroke(privacy == opt.title ? Theme.ember : Theme.textSecondary, lineWidth: 1.5)
                                                .frame(width: 14, height: 14)
                                            if privacy == opt.title {
                                                Circle()
                                                    .fill(Theme.ember)
                                                    .frame(width: 8, height: 8)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(opt.title)
                                                .font(Theme.font(size: 12, weight: .semibold))
                                                .foregroundColor(privacy == opt.title ? Theme.text : Theme.textSecondary)
                                            Text(opt.desc)
                                                .font(Theme.font(size: 10, weight: .regular))
                                                .foregroundColor(Theme.textMuted)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(privacy == opt.title ? Color(red: 30/255, green: 24/255, blue: 20/255) : Color(red: 21/255, green: 19/255, blue: 16/255))
                                }
                                .buttonStyle(.plain)

                                if index < privacyOptions.count - 1 {
                                    Divider().background(Theme.border)
                                }
                            }
                        }
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    }

                    // Settings grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        settingChip(label: "MAX PLAYERS", value: "8")
                        settingChip(label: "DIFFICULTY", value: "Normal")
                        settingChip(label: "MOD SYNC", value: "Required")
                        settingChip(label: "MEMBER ROLE", value: "Survival")
                    }

                    // Permissions
                    VStack(spacing: 12) {
                        toggleRow(title: "Allow cheats", subtitle: "Only the host can change this later", isOn: $allowCheats)
                        Divider().background(Theme.border)
                        toggleRow(title: "Friends can invite", subtitle: "Group members may bring mutual friends", isOn: $friendsCanInvite)
                    }
                    .padding(.top, 4)

                    // Note
                    HStack(spacing: 10) {
                        Image(systemName: "person.2")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.ember)
                        Text(verbatim: "This is temporary. Your world and instance files stay private.")
                            .font(Theme.font(size: 11, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 23/255, green: 20/255, blue: 17/255))
                    .cornerRadius(8)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Theme.ember).frame(width: 3)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: 360)

            Divider().background(Theme.border)

            // Footer
            HStack {
                Button {
                    app.modal = nil
                } label: {
                    Text(verbatim: "Cancel")
                        .font(Theme.font(size: 12, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation { isCreated = true }
                } label: {
                    HStack(spacing: 6) {
                        Text(verbatim: "Create \(privacy) lobby →")
                            .font(Theme.font(size: 12, weight: .bold))
                    }
                    .foregroundColor(Color(red: 32/255, green: 20/255, blue: 14/255))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.emberGradient)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
    }

    private func settingChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.font(size: 9, weight: .medium, mono: true))
                .tracking(1.0)
                .foregroundColor(Theme.textMuted)

            HStack {
                Text(value)
                    .font(Theme.font(size: 12, weight: .medium))
                    .foregroundColor(Theme.text)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color(red: 21/255, green: 19/255, blue: 16/255))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font(size: 12, weight: .semibold))
                    .foregroundColor(Theme.text)
                Text(subtitle)
                    .font(Theme.font(size: 10, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Theme.ember))
        }
    }

    // MARK: - Ready View

    private var readyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(red: 88/255, green: 65/255, blue: 52/255), lineWidth: 1.5)
                    .frame(width: 74, height: 74)

                Circle()
                    .fill(Theme.ember)
                    .frame(width: 40, height: 40)

                Text(verbatim: "3")
                    .font(Theme.font(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 32/255, green: 20/255, blue: 14/255))
            }
            .padding(.top, 16)

            VStack(spacing: 6) {
                Text(verbatim: "Waiting in \(selectedWorld)")
                    .font(Theme.font(size: 18, weight: .semibold))
                    .foregroundColor(Theme.text)

                Text(verbatim: "Friends can now see and join your lobby. It closes when you leave.")
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Invite code
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "INVITE CODE")
                        .font(Theme.font(size: 8, weight: .medium, mono: true))
                        .foregroundColor(Theme.textMuted)
                    Text(verbatim: "WARM-4821")
                        .font(Theme.font(size: 15, weight: .bold, mono: true))
                        .foregroundColor(Theme.ember)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("WARM-4821", forType: .string)
                    copiedCode = true
                } label: {
                    Text(copiedCode ? "Copied!" : "Copy")
                        .font(Theme.font(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color(red: 21/255, green: 19/255, blue: 16/255))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 48)

            Button {
                app.modal = nil
            } label: {
                Text(verbatim: "Open lobby")
                    .font(Theme.font(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 32/255, green: 20/255, blue: 14/255))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Theme.emberGradient)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 48)
            .padding(.bottom, 24)
        }
    }
}
