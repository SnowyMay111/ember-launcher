import SwiftUI

struct FriendsDrawer: View {
    @EnvironmentObject var app: AppState

    struct FriendDrawerItem: Identifiable {
        let id: String
        let name: String
        let status: String
        let isOnline: Bool
        let color: Color
    }

    private let friends: [FriendDrawerItem] = [
        FriendDrawerItem(id: "1", name: "Mossy", status: "Building in 1.21.4", isOnline: true, color: Color(red: 101/255, green: 73/255, blue: 56/255)),
        FriendDrawerItem(id: "2", name: "Luna", status: "In the main menu", isOnline: true, color: Color(red: 77/255, green: 89/255, blue: 68/255)),
        FriendDrawerItem(id: "3", name: "North", status: "Exploring Ember Valley", isOnline: true, color: Color(red: 89/255, green: 71/255, blue: 92/255)),
        FriendDrawerItem(id: "4", name: "Rowan", status: "Offline · 2h ago", isOnline: false, color: Color(red: 77/255, green: 73/255, blue: 68/255)),
    ]

    var body: some View {
        ZStack(alignment: .trailing) {
            // Backdrop
            Color.black.opacity(0.42)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        app.friendsDrawerOpen = false
                    }
                }

            // Drawer container
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "FRIENDS")
                            .font(Theme.font(size: 10, weight: .medium, mono: true))
                            .tracking(1.4)
                            .foregroundColor(Color(red: 146/255, green: 112/255, blue: 91/255))

                        Text(verbatim: "3 people online")
                            .font(Theme.font(size: 15, weight: .semibold))
                            .foregroundColor(Theme.text)
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            app.friendsDrawerOpen = false
                        }
                    } label: {
                        Circle()
                            .fill(Color(red: 29/255, green: 26/255, blue: 23/255))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("×")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(red: 145/255, green: 137/255, blue: 129/255))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .frame(height: 72)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Theme.border).frame(height: 1)
                }

                // Current Group
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(verbatim: "YOUR GROUP")
                            .font(Theme.font(size: 9, weight: .medium, mono: true))
                            .tracking(1.2)
                            .foregroundColor(Color(red: 143/255, green: 109/255, blue: 89/255))
                        Spacer()
                        Text(verbatim: "Quiet Crew · 3/8")
                            .font(Theme.font(size: 11, weight: .semibold))
                            .foregroundColor(Theme.text)
                    }

                    HStack(spacing: -6) {
                        groupAvatar("M", bg: Color(red: 97/255, green: 70/255, blue: 56/255))
                        groupAvatar("C", bg: Color(red: 75/255, green: 89/255, blue: 68/255))
                        groupAvatar("L", bg: Color(red: 89/255, green: 71/255, blue: 92/255))

                        Button {
                            // Add member
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 36/255, green: 32/255, blue: 28/255))
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(Color(red: 24/255, green: 20/255, blue: 17/255), lineWidth: 2))
                                Text(verbatim: "＋")
                                    .font(Theme.font(size: 12, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    }

                    Button {
                        withAnimation {
                            app.friendsDrawerOpen = false
                            app.modal = .lobby
                        }
                    } label: {
                        Text(verbatim: "Create lobby for group")
                            .font(Theme.font(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 216/255, green: 160/255, blue: 121/255))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color(red: 37/255, green: 26/255, blue: 21/255))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 91/255, green: 65/255, blue: 51/255), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color(red: 24/255, green: 20/255, blue: 17/255))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 59/255, green: 48/255, blue: 40/255), lineWidth: 1))
                .padding(14)

                // Friends list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
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

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: friend.name)
                                        .font(Theme.font(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.text)
                                    Text(verbatim: friend.status)
                                        .font(Theme.font(size: 10, weight: .regular))
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Circle()
                                    .fill(friend.isOnline ? Theme.success : Color(red: 77/255, green: 73/255, blue: 68/255))
                                    .frame(width: 6, height: 6)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.vertical, 4)
                }

                Spacer(minLength: 8)

                // Footer link
                Button {
                    withAnimation {
                        app.friendsDrawerOpen = false
                        app.screen = .social
                    }
                } label: {
                    HStack {
                        Text(verbatim: "Open Social center →")
                            .font(Theme.font(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 168/255, green: 159/255, blue: 150/255))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Theme.border).frame(height: 1)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: 320)
            .background(Color(red: 16/255, green: 15/255, blue: 13/255))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 56/255, green: 49/255, blue: 44/255), lineWidth: 1)
            )
            .padding(14)
            .shadow(color: Color.black.opacity(0.55), radius: 30, x: -10, y: 0)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private func groupAvatar(_ letter: String, bg: Color) -> some View {
        ZStack {
            Circle()
                .fill(bg)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Color(red: 24/255, green: 20/255, blue: 17/255), lineWidth: 2))
            Text(letter)
                .font(Theme.font(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
