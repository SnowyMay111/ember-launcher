import Foundation
import LauncherCore
import SwiftUI

struct FriendsList: View {
    let compact: Bool

    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: FriendsStore
    @EnvironmentObject var ember: EmberAccountStore
    @Local private var tag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            if !ember.isSignedIn {
                VStack(alignment: .leading, spacing: 12) {
                    Text(verbatim: L("Sign in to your Ember account to add friends."))
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    SecondaryPill(title: L("Sign in"), height: 34) {
                        app.friendsDrawerOpen = false
                        app.modal = .emberSignIn
                    }
                }
            } else {
                signedInContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { LobbyStore.shared.beginBrowsing() }
        .onDisappear { LobbyStore.shared.endBrowsing() }
        .onChange(of: ember.isSignedIn) { _, _ in LobbyStore.shared.refreshSoon() }
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            HStack(spacing: 8) {
                EmberInput(
                    label: L("Friend tag"),
                    text: $tag,
                    placeholder: "@tag"
                )

                SecondaryPill(title: L("Add"), height: 40) {
                    guard !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    store.sendRequest(tag: tag)
                    tag = ""
                }
            }

            if let message = store.message {
                Text(verbatim: message)
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .onTapGesture {
                        store.message = nil
                    }
                    .contentShape(Rectangle())
            }

            if !store.incoming.isEmpty {
                friendsSection(title: L("Requests")) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.incoming, id: \.userID) { entry in
                            requestRow(entry)
                        }
                    }
                }
            }

            friendsSection(title: L("Friends")) {
                if store.friendsList.isEmpty {
                    Text(verbatim: L("No friends yet. Add someone by their tag."))
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(store.friendsList, id: \.userID) { entry in
                            FriendListRow(entry: entry, compact: compact) {
                                store.remove(entry)
                            }
                        }
                    }
                }
            }

            if !store.outgoing.isEmpty {
                friendsSection(title: L("Sent")) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.outgoing, id: \.userID) { entry in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: entry.displayName)
                                        .font(Theme.font(size: 13, weight: .semibold))
                                        .foregroundColor(Theme.text)

                                    Text(verbatim: "@\(entry.tag)")
                                        .font(Theme.font(size: 12, weight: .regular))
                                        .foregroundColor(Theme.textSecondary)
                                }

                                Spacer()

                                SmallFriendButton(title: L("Cancel")) {
                                    store.remove(entry)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    private func friendsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(verbatim: title)
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)

            content()
        }
    }

    private func requestRow(_ entry: FriendEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: entry.displayName)
                    .font(Theme.font(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text)

                Text(verbatim: "@\(entry.tag)")
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            HStack(spacing: 6) {
                SmallFriendButton(title: L("Accept")) {
                    store.accept(entry)
                }

                SmallFriendButton(title: L("Decline")) {
                    store.decline(entry)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FriendListRow: View {
    let entry: FriendEntry
    let compact: Bool
    let remove: () -> Void

    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var toasts: ToastCenter
    @ObservedObject private var lobbyStore = LobbyStore.shared
    @Local private var isHovered = false
    @Local private var isJoining = false
    @Local private var showCard = false

    var body: some View {
        HStack(spacing: 10) {
            PlayerHead(
                name: entry.avatarName ?? entry.displayName,
                size: compact ? 30 : 34
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: entry.displayName)
                    .font(Theme.font(size: 13, weight: .semibold))
                    .foregroundColor(Theme.text)

                HStack(spacing: 5) {
                    Circle()
                        .fill(entry.online ? Theme.success : Color(red: 77 / 255, green: 73 / 255, blue: 68 / 255))
                        .frame(width: 7, height: 7)

                    Text(verbatim: statusText)
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let lobby = hostedLobby {
                SmallFriendButton(title: L("Join")) {
                    join(lobby)
                }
                .disabled(isJoining)
                .opacity(isJoining ? 0.5 : 1)
            }

            if isHovered {
                IconButton(
                    systemName: "person.badge.minus",
                    label: L("Remove friend"),
                    action: remove
                )
                .frame(width: 32, height: 32)
            }
        }
        .padding(.vertical, compact ? 4 : 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { showCard = true }
        .popover(isPresented: $showCard, arrowEdge: .trailing) {
            friendCard
        }
    }

    private var friendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PlayerHead(
                    name: entry.avatarName ?? entry.displayName,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: entry.displayName)
                        .font(Theme.font(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)

                    Text(verbatim: "@\(entry.tag)")
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(entry.online ? Theme.success : Color(red: 77 / 255, green: 73 / 255, blue: 68 / 255))
                    .frame(width: 7, height: 7)

                Text(verbatim: presenceText)
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }

            if let activity = activityText {
                Text(verbatim: activity)
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let lobby = hostedLobby {
                    SmallFriendButton(title: L("Join")) {
                        join(lobby)
                    }
                    .disabled(isJoining)
                    .opacity(isJoining ? 0.5 : 1)
                }

                if lobbyStore.current?.isHost == true {
                    SmallFriendButton(title: L("Invite to my lobby")) {
                        lobbyStore.invite(userID: entry.userID)
                        showCard = false
                    }
                }

                SmallFriendButton(title: L("Remove friend")) {
                    showCard = false
                    remove()
                }
            }
        }
        .padding(14)
        .frame(width: 240, alignment: .leading)
    }

    /// A visible, ready lobby this friend is hosting.
    private var hostedLobby: VisibleLobby? {
        lobbyStore.visible.first { $0.hostUser == entry.userID && $0.ready }
    }

    private var presenceText: String {
        if entry.online {
            return L("Online")
        }

        guard let lastSeenAt = entry.lastSeenAt else {
            return L("Offline")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return L("Last seen %@", formatter.localizedString(for: lastSeenAt, relativeTo: Date()))
    }

    private var activityText: String? {
        guard let activity = entry.activity, !activity.isEmpty else { return nil }
        return activity == "playing" ? L("Playing Minecraft") : activity
    }

    private func join(_ lobby: VisibleLobby) {
        guard !isJoining else { return }
        let lobbyID = lobby.lobbyID
        isJoining = true
        Task {
            let joined = await LobbyStore.shared.join(code: nil, lobbyID: lobbyID, nick: settings.nickname)
            isJoining = false
            if joined {
                showCard = false
            } else if let message = LobbyStore.shared.message {
                toasts.show(message, kind: .info)
            }
        }
    }

    private var statusText: String {
        if entry.online {
            if entry.activity == "playing" {
                return L("Playing Minecraft")
            }
            return entry.activity ?? L("Online")
        }

        guard let lastSeenAt = entry.lastSeenAt else {
            return L("Offline")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "\(L("Offline")) · \(formatter.localizedString(for: lastSeenAt, relativeTo: Date()))"
    }
}

struct SmallFriendButton: View {
    let title: String
    let action: () -> Void

    @Local private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(Theme.font(size: 12, weight: .semibold))
                .foregroundColor(isHovered ? Theme.text : Theme.textSecondary)
                .padding(.horizontal, 9)
                .frame(minHeight: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Theme.surface : Theme.elevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isHovered ? Theme.lineStrong : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
