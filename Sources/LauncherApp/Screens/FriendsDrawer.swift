import SwiftUI

struct FriendsDrawer: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: FriendsStore

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
                        Text(verbatim: L("Friends"))
                            .font(Theme.font(size: 13, weight: .semibold))
                            .foregroundColor(Theme.text)

                        Text(verbatim: L("%d online", store.onlineCount))
                            .font(Theme.font(size: 12, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
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
                .soonPreview(badge: false)

                // Friends list
                ScrollView {
                    FriendsList(compact: true)
                        .padding(14)
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
                        Text(verbatim: L("Open Social center →"))
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
