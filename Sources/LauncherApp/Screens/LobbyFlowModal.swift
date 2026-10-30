import SwiftUI
import LauncherCore

/// Host a world for friends or join a lobby with a code; the launcher does everything else.
struct LobbyFlowModal: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var play: PlayController
    @ObservedObject private var account = EmberAccountStore.shared
    @ObservedObject private var lobbies = LobbyStore.shared
    @ObservedObject private var host = LobbyHostController.shared
    @ObservedObject private var guest = LobbyGuestController.shared

    @Local private var instanceName = ""
    @Local private var lobbyName = ""
    @Local private var privacy: LobbyPrivacy = .friends
    @Local private var maxPlayers = 4
    @Local private var joinCode = ""
    @Local private var copiedCode = false

    private var hostable: [LibraryInstance] {
        app.instances.filter { $0.loader == .fabric || $0.loader == .vanilla }
    }

    private var selected: LibraryInstance? {
        hostable.first { $0.id == instanceName } ?? hostable.first
    }

    private var busy: Bool { host.isBusy || guest.isBusy || play.isBusy }

    var body: some View {
        EmberModal(title: "Play together", width: 540) {
            VStack(alignment: .leading, spacing: 18) {
                if !account.isSignedIn {
                    signedOutView
                } else if let current = lobbies.current {
                    activeView(current)
                } else {
                    setupView
                }
                statusLine
            }
        } footer: {
            footer
        }
    }

    // MARK: - Signed out

    private var signedOutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr: "Lobbies use your Ember account, so friends can find you and the host knows who may join.")
                .style(.secondary)
            SecondaryPill(title: "Sign in to Ember", height: 38) {
                app.modal = .emberSignIn
            }
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModalField(label: "World") {
                if hostable.isEmpty {
                    Text(tr: "Create a Fabric or Vanilla instance first.").style(.secondary)
                } else {
                    EmberMenu(label: "World", value: selected?.name ?? "…", minWidth: 280) {
                        ForEach(hostable) { item in
                            Button(item.name) { instanceName = item.id }
                        }
                    }
                }
            }

            ModalField(label: "Lobby name") {
                EmberInput(label: "Lobby name", text: $lobbyName, placeholder: defaultLobbyName)
            }

            HStack(alignment: .top, spacing: 24) {
                ModalField(label: "Who can join") {
                    EmberMenu(label: "Who can join", value: privacyTitle(privacy), minWidth: 200) {
                        Button(privacyTitle(.friends)) { privacy = .friends }
                        Button(privacyTitle(.invite)) { privacy = .invite }
                    }
                }
                ModalField(label: "Players") {
                    EmberMenu(label: "Players", value: "\(maxPlayers)", minWidth: 80) {
                        ForEach(2...8, id: \.self) { count in
                            Button("\(count)") { maxPlayers = count }
                        }
                    }
                }
            }

            if !host.eulaAccepted {
                HStack(spacing: 8) {
                    EmberCheckbox(label: "I accept the Minecraft EULA", isOn: $host.eulaAccepted)
                    Text(tr: "I accept the Minecraft EULA (aka.ms/MinecraftEULA)").style(.secondary)
                }
            }

            Rectangle().fill(Color(hex: 0x252225)).frame(height: 1)

            ModalField(label: "Join with a code") {
                HStack(spacing: 10) {
                    EmberInput(label: "Lobby code", text: $joinCode, placeholder: "ABC123")
                    SecondaryPill(title: "Join", height: 40) {
                        guest.join(code: joinCode.trimmingCharacters(in: .whitespaces).uppercased(), lobbyID: nil,
                                   settings: settings, app: app, play: play)
                    }
                    .disabled(busy || joinCode.trimmingCharacters(in: .whitespaces).count < 4)
                }
            }
        }
    }

    // MARK: - Active lobby

    private func activeView(_ current: ActiveLobby) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(verbatim: current.name).style(.row)
            Text(verbatim: "\(current.mcVersion) · \(current.loader)").style(.secondary)

            if current.isHost, let code = current.code {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr: "Lobby code").style(.secondary)
                        Text(verbatim: code)
                            .font(Theme.font(size: 22, weight: .semibold, mono: true))
                            .foregroundColor(Theme.ember)
                    }
                    Spacer()
                    SecondaryPill(title: copiedCode ? "Copied" : "Copy", height: 36) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        copiedCode = true
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.elevated))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(tr: "In the lobby").style(.secondary)
                ForEach(lobbies.roster) { member in
                    HStack {
                        Text(verbatim: member.nick).style(.row)
                        Spacer()
                        Text(tr: member.state == "playing" ? "Playing" : "Joined").style(.secondary)
                    }
                }
                if lobbies.roster.isEmpty {
                    Text(tr: "Only you for now. Share the code or invite a friend from Social.").style(.secondary)
                }
            }
        }
    }

    // MARK: - Status and footer

    @ViewBuilder private var statusLine: some View {
        if case .preparing(let text) = host.state {
            Text(verbatim: text).style(.secondary)
        } else if case .preparing(let text) = guest.state {
            Text(verbatim: text).style(.secondary)
        } else if case .failed(let text) = host.state {
            Text(verbatim: text).style(.init(size: 13, weight: .regular, color: Theme.danger))
        } else if case .failed(let text) = guest.state {
            Text(verbatim: text).style(.init(size: 13, weight: .regular, color: Theme.danger))
        } else if let message = lobbies.message {
            Text(verbatim: message).style(.init(size: 13, weight: .regular, color: Theme.danger))
        }
    }

    @ViewBuilder private var footer: some View {
        if let current = lobbies.current {
            ModalCancel(title: "Close window")
            SecondaryPill(title: current.isHost ? "Close lobby" : "Leave lobby", height: 38) {
                if current.isHost { host.close() } else { lobbies.leave() }
            }
        } else {
            ModalCancel()
            PrimaryPill(title: "Create lobby", height: 38, isDisabled: !canCreate) {
                guard let item = selected else { return }
                host.host(
                    item,
                    name: effectiveLobbyName,
                    privacy: privacy,
                    maxPlayers: maxPlayers,
                    settings: settings,
                    app: app,
                    play: play
                )
            }
        }
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        account.isSignedIn && selected != nil && host.eulaAccepted && !busy
    }

    private var defaultLobbyName: String { "\(settings.nickname)'s world" }

    private var effectiveLobbyName: String {
        let trimmed = lobbyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultLobbyName : trimmed
    }

    private func privacyTitle(_ privacy: LobbyPrivacy) -> String {
        switch privacy {
        case .friends: return L("Friends")
        case .invite: return L("Invite only")
        }
    }
}
