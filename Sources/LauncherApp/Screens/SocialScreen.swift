import SwiftUI

struct SocialScreen: View {
    @EnvironmentObject var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct FriendItem: Identifiable {
        let id: String
        let name: String
        let status: String
        let isOnline: Bool
        let color: Color
    }

    private let friends: [FriendItem] = [
        FriendItem(id: "1", name: "Mossy", status: "Building in 1.21.4", isOnline: true, color: Color(red: 101/255, green: 73/255, blue: 56/255)),
        FriendItem(id: "2", name: "Luna", status: "In the main menu", isOnline: true, color: Color(red: 77/255, green: 89/255, blue: 68/255)),
        FriendItem(id: "3", name: "North", status: "Exploring Ember Valley", isOnline: true, color: Color(red: 89/255, green: 71/255, blue: 92/255)),
        FriendItem(id: "4", name: "Rowan", status: "Offline · 2h ago", isOnline: false, color: Color(red: 77/255, green: 73/255, blue: 68/255)),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Intro header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "PLAY TOGETHER")
                            .font(Theme.font(size: 10, weight: .medium, mono: true))
                            .tracking(2.0)
                            .foregroundColor(Color(red: 123/255, green: 119/255, blue: 113/255))

                        Text(verbatim: "Social")
                            .font(Theme.font(size: 26, weight: .semibold))
                            .tracking(-0.8)
                            .foregroundColor(Theme.text)

                        Text(verbatim: "A quiet place for friends, invitations, and temporary worlds.")
                            .font(Theme.font(size: 13, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    Button {
                        app.modal = .lobby
                    } label: {
                        HStack(spacing: 6) {
                            Text(verbatim: "＋")
                                .font(Theme.font(size: 14, weight: .medium))
                            Text(verbatim: "Create lobby")
                                .font(Theme.font(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 27/255, green: 17/255, blue: 10/255))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.emberGradient)
                        .cornerRadius(Theme.radiusCompact)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)

                // 3-panel layout
                HStack(alignment: .top, spacing: 14) {
                    friendsPanel
                        .frame(maxWidth: .infinity)

                    lobbiesPanel
                        .frame(maxWidth: .infinity * 1.4)

                    invitesPanel
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 56)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Friends Panel

    private var friendsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: "FRIENDS")
                    .font(Theme.font(size: 10, weight: .medium, mono: true))
                    .tracking(1.4)
                    .foregroundColor(Color(red: 143/255, green: 109/255, blue: 89/255))
                Spacer()
                Text(verbatim: "3 online")
                    .font(Theme.font(size: 11, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            VStack(spacing: 4) {
                ForEach(friends) { friend in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(friend.color)
                                .frame(width: 34, height: 34)
                            Text(String(friend.name.prefix(1)))
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(Color(red: 234/255, green: 223/255, blue: 212/255))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: friend.name)
                                .font(Theme.font(size: 13, weight: .semibold))
                                .foregroundColor(Theme.text)
                            Text(verbatim: friend.status)
                                .font(Theme.font(size: 11, weight: .regular))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Circle()
                            .fill(friend.isOnline ? Theme.success : Color(red: 77/255, green: 73/255, blue: 68/255))
                            .frame(width: 7, height: 7)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
            }
            .padding(.vertical, 8)

            Spacer(minLength: 8)

            Button {
                // View all friends
            } label: {
                Text(verbatim: "View all friends →")
                    .font(Theme.font(size: 11, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Theme.border).frame(height: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .background(Color(red: 17/255, green: 16/255, blue: 14/255))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    // MARK: - Lobbies Panel

    private var lobbiesPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: "ACTIVE LOBBIES")
                    .font(Theme.font(size: 10, weight: .medium, mono: true))
                    .tracking(1.4)
                    .foregroundColor(Color(red: 147/255, green: 112/255, blue: 91/255))
                Spacer()
                Text(verbatim: "Friends only")
                    .font(Theme.font(size: 11, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            VStack(spacing: 14) {
                // Active lobby card
                VStack(alignment: .leading, spacing: 0) {
                    // Sunset scene
                    ZStack(alignment: .bottomTrailing) {
                        LinearGradient(
                            colors: [
                                Color(red: 50/255, green: 41/255, blue: 58/255),
                                Color(red: 111/255, green: 73/255, blue: 51/255),
                                Color(red: 23/255, green: 23/255, blue: 19/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 100)

                        Circle()
                            .fill(Color(red: 240/255, green: 160/255, blue: 98/255).opacity(0.8))
                            .frame(width: 24, height: 24)
                            .blur(radius: 2)
                            .offset(x: -30, y: -20)
                    }
                    .clipped()

                    VStack(alignment: .leading, spacing: 10) {
                        Text(verbatim: "2 / 8 PLAYERS")
                            .font(Theme.font(size: 9, weight: .medium, mono: true))
                            .tracking(1.2)
                            .foregroundColor(Color(red: 147/255, green: 112/255, blue: 91/255))

                        Text(verbatim: "Birch Hollow evening")
                            .font(Theme.font(size: 16, weight: .semibold))
                            .foregroundColor(Theme.text)

                        Text(verbatim: "Mossy is hosting · Fabric 1.21.4")
                            .font(Theme.font(size: 12, weight: .regular))
                            .foregroundColor(Theme.textSecondary)

                        HStack(spacing: -6) {
                            lobbyAvatar("M", bg: Color(red: 97/255, green: 70/255, blue: 56/255))
                            lobbyAvatar("L", bg: Color(red: 77/255, green: 89/255, blue: 68/255))
                            Text(verbatim: "+ invite")
                                .font(Theme.font(size: 10, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                                .padding(.leading, 14)
                        }
                        .padding(.top, 4)

                        Button {
                            // Join lobby
                        } label: {
                            Text(verbatim: "Join lobby")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(Color(red: 32/255, green: 20/255, blue: 14/255))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(Theme.emberGradient)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(14)
                }
                .background(Color(red: 21/255, green: 19/255, blue: 16/255))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 49/255, green: 43/255, blue: 38/255), lineWidth: 1)
                )

                // Start from your world
                HStack(spacing: 12) {
                    Text(verbatim: "＋")
                        .font(Theme.font(size: 20, weight: .medium))
                        .foregroundColor(Theme.ember)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "Start from your world")
                            .font(Theme.font(size: 12, weight: .semibold))
                            .foregroundColor(Theme.text)
                        Text(verbatim: "Friends join without changing your instance.")
                            .font(Theme.font(size: 10, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    Button {
                        app.modal = .lobby
                    } label: {
                        Text(verbatim: "Create")
                            .font(Theme.font(size: 11, weight: .bold))
                            .foregroundColor(Theme.ember)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.ember.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 57/255, green: 51/255, blue: 45/255), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
            }
            .padding(14)
        }
        .background(Color(red: 17/255, green: 16/255, blue: 14/255))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func lobbyAvatar(_ letter: String, bg: Color) -> some View {
        ZStack {
            Circle()
                .fill(bg)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color(red: 21/255, green: 19/255, blue: 16/255), lineWidth: 2))
            Text(letter)
                .font(Theme.font(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Invites Panel

    private var invitesPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: "INVITES")
                    .font(Theme.font(size: 10, weight: .medium, mono: true))
                    .tracking(1.4)
                    .foregroundColor(Color(red: 147/255, green: 112/255, blue: 91/255))
                Spacer()
                Text(verbatim: "1 new")
                    .font(Theme.font(size: 11, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 14) {
                // Invite Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 89/255, green: 71/255, blue: 92/255))
                                .frame(width: 32, height: 32)
                            Text(verbatim: "N")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "North invited you")
                                .font(Theme.font(size: 12, weight: .semibold))
                                .foregroundColor(Theme.text)
                            Text(verbatim: "Old Pines · Vanilla 1.21.4")
                                .font(Theme.font(size: 10, weight: .regular))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            // Accept
                        } label: {
                            Text(verbatim: "Accept")
                                .font(Theme.font(size: 11, weight: .semibold))
                                .foregroundColor(Color(red: 219/255, green: 163/255, blue: 116/255))
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(Color(red: 38/255, green: 27/255, blue: 22/255))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 96/255, green: 69/255, blue: 53/255), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button {
                            // Later
                        } label: {
                            Text(verbatim: "Later")
                                .font(Theme.font(size: 11, weight: .regular))
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(Color.clear)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 54/255, green: 49/255, blue: 44/255), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color(red: 21/255, green: 19/255, blue: 16/255))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.border, lineWidth: 1)
                )

                // Recent Players
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "RECENT PLAYERS")
                        .font(Theme.font(size: 9, weight: .medium, mono: true))
                        .tracking(1.2)
                        .foregroundColor(Color(red: 117/255, green: 109/255, blue: 102/255))

                    Text(verbatim: "Luna · 2 days ago")
                        .font(Theme.font(size: 11, weight: .regular))
                        .foregroundColor(Theme.textSecondary)

                    Text(verbatim: "Rowan · 5 days ago")
                        .font(Theme.font(size: 11, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.top, 8)
            }
            .padding(14)
        }
        .background(Color(red: 17/255, green: 16/255, blue: 14/255))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}
