import SwiftUI
import LauncherCore

struct SocialScreen: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: FriendsStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var play: PlayController
    @ObservedObject private var lobbyStore = LobbyStore.shared
    @ObservedObject private var guest = LobbyGuestController.shared
    @EnvironmentObject var toasts: ToastCenter
    @ObservedObject private var invitesStore = InvitesStore.shared
    @ObservedObject private var recentStore = RecentPlayersStore.shared
    @Local private var joiningLobbyID: String? = nil
    @Local private var pendingFriendTag: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Intro header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: L("Social"))
                            .font(Theme.font(size: 26, weight: .semibold))
                            .tracking(-0.8)
                            .foregroundColor(Theme.text)

                        Text(verbatim: L("A quiet place for friends, invitations, and temporary worlds."))
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
                            Text(verbatim: L("Create lobby"))
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
        .task {
            InvitesStore.shared.markAllSeen()
            await FriendsStore.shared.refresh()
        }
        .onChange(of: invitesStore.invites.map(\.lobbyID)) { _, _ in
            InvitesStore.shared.markAllSeen()
        }
        .onChange(of: store.message) { _, message in
            guard pendingFriendTag != nil, let message else { return }
            pendingFriendTag = nil
            toasts.show(message, kind: .info)
        }
    }

    // MARK: - Friends Panel

    private var friendsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: L("Friends"))
                    .font(Theme.font(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text)

                Spacer()

                Text(verbatim: L("%d online", store.onlineCount))
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            ScrollView(.vertical, showsIndicators: false) {
                FriendsList(compact: false)
                    .padding(14)
            }
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
                Text(verbatim: L("Lobbies"))
                    .font(Theme.font(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                Text(verbatim: L("Friends only"))
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            VStack(spacing: 12) {
                if lobbyStore.visible.isEmpty {
                    Text(verbatim: L("No lobbies from friends yet."))
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                ForEach(lobbyStore.visible) { lobby in
                    lobbyCard(lobby)
                }

                // Start from your world
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: L("Start from your world"))
                            .font(Theme.font(size: 13, weight: .semibold))
                            .foregroundColor(Theme.text)
                        Text(verbatim: L("Friends join without changing your instance."))
                            .font(Theme.font(size: 12, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    Button {
                        app.modal = .lobby
                    } label: {
                        Text(verbatim: L("Create"))
                            .font(Theme.font(size: 12, weight: .bold))
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

    private func lobbyCard(_ lobby: VisibleLobby) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: lobby.name)
                    .font(Theme.font(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Spacer()
                if lobby.invited {
                    Text(verbatim: L("Invited"))
                        .font(Theme.font(size: 12, weight: .medium))
                        .foregroundColor(Theme.ember)
                }
            }
            Text(verbatim: L("%@ is hosting", lobby.hostName) + " · \(lobby.loader.capitalized) \(lobby.mcVersion)")
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
            Text(verbatim: L("%d / %d players", lobby.players, lobby.maxPlayers))
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)

            Button {
                guest.join(code: nil, lobbyID: lobby.lobbyID, settings: settings, app: app)
                app.modal = .lobby
            } label: {
                Text(verbatim: L("Join lobby"))
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 32/255, green: 20/255, blue: 14/255))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Theme.emberGradient)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(!lobby.ready || lobby.players >= lobby.maxPlayers)
            .opacity(lobby.ready && lobby.players < lobby.maxPlayers ? 1 : 0.5)
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(red: 21/255, green: 19/255, blue: 16/255))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 49/255, green: 43/255, blue: 38/255), lineWidth: 1)
        )
    }

    // MARK: - Invites Panel

    private var invitesPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: L("Invites"))
                    .font(Theme.font(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text)
                Spacer()
                if invitesStore.unseenCount > 0 {
                    Text(verbatim: L("%d new", invitesStore.unseenCount))
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 14) {
                if invitesStore.invites.isEmpty {
                    Text(verbatim: L("No invitations."))
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                ForEach(invitesStore.invites) { lobby in
                    inviteCard(lobby)
                }

                // Recent players
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: L("Recent players"))
                        .font(Theme.font(size: 13, weight: .semibold))
                        .foregroundColor(Theme.text)

                    if recentPlayers.isEmpty {
                        Text(verbatim: L("Players you meet in lobbies show up here."))
                            .font(Theme.font(size: 12, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(recentPlayers, id: \.userID) { player in
                                recentPlayerRow(player)
                            }
                        }
                    }
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

    private func inviteCard(_ lobby: VisibleLobby) -> some View {
        let isJoining = joiningLobbyID == lobby.lobbyID
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 89/255, green: 71/255, blue: 92/255))
                        .frame(width: 32, height: 32)
                    Text(verbatim: String(lobby.hostName.prefix(1)).uppercased())
                        .font(Theme.font(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: L("%@ invited you", lobby.hostName))
                        .font(Theme.font(size: 13, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Text(verbatim: "\(lobby.name) · \(lobby.loader.capitalized) \(lobby.mcVersion)")
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                Button {
                    accept(lobby)
                } label: {
                    Text(verbatim: L("Accept"))
                        .font(Theme.font(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 219/255, green: 163/255, blue: 116/255))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(Color(red: 38/255, green: 27/255, blue: 22/255))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 96/255, green: 69/255, blue: 53/255), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(joiningLobbyID != nil)
                .opacity(isJoining ? 0.5 : 1)

                Button {
                    InvitesStore.shared.dismiss(lobby.lobbyID)
                } label: {
                    Text(verbatim: L("Later"))
                        .font(Theme.font(size: 12, weight: .regular))
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
    }

    private func recentPlayerRow(_ player: RecentPlayerRecord) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: player.name)
                    .font(Theme.font(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(verbatim: "@\(player.tag) · \(relativeTime(player.lastSeen))")
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            SmallFriendButton(title: L("Add friend")) {
                pendingFriendTag = player.tag
                store.sendRequest(tag: player.tag)
            }

            Button {
                recentStore.remove(userID: player.userID)
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.font(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 22, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("Hide player"))
            .accessibilityLabel(L("Hide player"))
        }
        .padding(.vertical, 4)
    }

    /// Recent players who are not already friends, newest first.
    private var recentPlayers: [RecentPlayerRecord] {
        let friendIDs = Set(store.friendsList.map(\.userID))
        return Array(recentStore.players.filter { !friendIDs.contains($0.userID) }.prefix(8))
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func accept(_ lobby: VisibleLobby) {
        guard joiningLobbyID == nil else { return }
        let lobbyID = lobby.lobbyID
        joiningLobbyID = lobbyID
        Task {
            let joined = await LobbyStore.shared.join(code: nil, lobbyID: lobbyID, nick: settings.nickname)
            joiningLobbyID = nil
            if !joined, let message = LobbyStore.shared.message {
                toasts.show(message, kind: .info)
            }
        }
    }
}
