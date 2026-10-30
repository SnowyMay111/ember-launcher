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
    @ObservedObject private var room = LobbyRoom.shared
    @ObservedObject private var guest = LobbyGuestController.shared

    @Local private var instanceName = ""
    @Local private var lobbyName = ""
    @Local private var emptyMinecraftVersion = "1.21.1"
    @Local private var privacy: LobbyPrivacy = .friends
    @Local private var maxPlayers = 4
    @Local private var joinCode = ""
    @Local private var copiedCode = false

    private var hostable: [LibraryInstance] {
        app.instances.filter { $0.loader == .fabric || $0.loader == .vanilla }
    }

    private var selected: LibraryInstance? {
        guard !instanceName.isEmpty else { return nil }
        return hostable.first { $0.id == instanceName }
    }

    private var busy: Bool {
        host.isBusy || guest.isBusy || play.isBusy
    }

    var body: some View {
        EmberModal(title: "Play together", width: lobbies.current == nil ? 540 : 620) {
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
                .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
            SecondaryPill(title: "Sign in to Ember", height: 38) {
                app.modal = .emberSignIn
            }
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 18) {
            LobbyField(label: "Start from") {
                EmberMenu(label: "Start from", value: startSourceTitle, minWidth: 280) {
                    Button {
                        instanceName = ""
                    } label: {
                        Text(tr: "New empty lobby (Fabric)")
                    }

                    ForEach(hostable) { item in
                        Button {
                            instanceName = item.id
                        } label: {
                            Text(verbatim: L("Copy of %@", item.name))
                        }
                    }
                }

                if selected == nil {
                    EmberMenu(label: "Minecraft version", value: emptyMinecraftVersion, minWidth: 150) {
                        Button {
                            emptyMinecraftVersion = "1.21.1"
                        } label: {
                            Text(tr: "1.21.1")
                        }
                        Button {
                            emptyMinecraftVersion = "1.20.1"
                        } label: {
                            Text(tr: "1.20.1")
                        }
                    }
                }
            }

            LobbyField(label: "Lobby name") {
                EmberInput(label: "Lobby name", text: $lobbyName, placeholder: defaultLobbyName)
            }

            HStack(alignment: .top, spacing: 24) {
                LobbyField(label: "Who can join") {
                    EmberMenu(label: "Who can join", value: privacyTitle(privacy), minWidth: 200) {
                        Button {
                            privacy = .friends
                        } label: {
                            Text(tr: privacyTitle(.friends))
                        }
                        Button {
                            privacy = .invite
                        } label: {
                            Text(tr: privacyTitle(.invite))
                        }
                    }
                }

                LobbyField(label: "Players") {
                    EmberMenu(label: "Players", value: "\(maxPlayers)", minWidth: 80) {
                        ForEach(2...8, id: \.self) { count in
                            Button {
                                maxPlayers = count
                            } label: {
                                Text(verbatim: "\(count)")
                            }
                        }
                    }
                }
            }

            if !host.eulaAccepted {
                HStack(spacing: 8) {
                    EmberCheckbox(label: "I accept the Minecraft EULA", isOn: $host.eulaAccepted)
                    Text(tr: "I accept the Minecraft EULA (aka.ms/MinecraftEULA)")
                        .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
                }
            }

            Rectangle()
                .fill(Color(hex: 0x252225))
                .frame(height: 1)

            LobbyField(label: "Join with a code") {
                HStack(spacing: 10) {
                    EmberInput(label: "Lobby code", text: $joinCode, placeholder: L("ABC123"))
                    SecondaryPill(title: "Join", height: 40) {
                        guest.join(
                            code: joinCode.trimmingCharacters(in: .whitespaces).uppercased(),
                            lobbyID: nil,
                            settings: settings,
                            app: app
                        )
                    }
                    .disabled(busy || joinCode.trimmingCharacters(in: .whitespaces).count < 4)
                }
            }
        }
    }

    // MARK: - Active lobby

    private func activeView(_ current: ActiveLobby) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                LobbyHeader(
                    current: current,
                    copiedCode: copiedCode,
                    copyCode: {
                        guard let code = current.code else { return }
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        copiedCode = true
                    }
                )

                if current.isHost, room.unsyncedCount > 0 {
                    Text(verbatim: L("%d mods were added by hand and guests will not get them.", room.unsyncedCount))
                        .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
                }

                LobbyPlayersSection(
                    current: current,
                    roster: lobbies.roster,
                    ownUserID: ownUserID,
                    setCanEdit: { userID, can in
                        Task {
                            await lobbies.setCanEdit(userID: userID, can: can)
                        }
                    }
                )

                LobbyContentSection(
                    groups: contentGroups,
                    canEdit: current.canEdit,
                    isRunning: current.isRunning,
                    canRemove: { item in canRemove(item, current: current) },
                    remove: { item in
                        Task {
                            await lobbies.removeItem(item)
                        }
                    },
                    addContent: {
                        app.currentID = room.instanceName
                        app.screen = .mods
                        app.modal = nil
                    },
                    progressText: room.progress.map { String(describing: $0) }
                )

                LobbyRulesSection(
                    current: current,
                    updateSettings: { editPolicy, syncShaders, syncResourcePacks in
                        Task {
                            await lobbies.setSettings(
                                editPolicy: editPolicy,
                                syncShaders: syncShaders,
                                syncResourcePacks: syncResourcePacks
                            )
                        }
                    }
                )

                if !current.isHost, !current.isRunning {
                    Text(tr: "Waiting for the host to start the server…")
                        .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
                }

                if lobbies.tunnelConnecting {
                    Text(tr: "Connecting to the host…")
                        .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 620)
    }

    // MARK: - Status and footer

    @ViewBuilder private var statusLine: some View {
        if case .preparing(let text) = host.state {
            Text(verbatim: text)
                .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
        } else if case .preparing(let text) = guest.state {
            Text(verbatim: text)
                .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
        } else if case .failed(let text) = host.state {
            Text(verbatim: text)
                .style(.init(size: 13, weight: .regular, color: Theme.danger))
        } else if case .failed(let text) = guest.state {
            Text(verbatim: text)
                .style(.init(size: 13, weight: .regular, color: Theme.danger))
        } else if let message = host.errorMessage {
            Text(verbatim: message)
                .style(.init(size: 13, weight: .regular, color: Theme.danger))
        } else if let message = guest.errorMessage {
            Text(verbatim: message)
                .style(.init(size: 13, weight: .regular, color: Theme.danger))
        } else if let message = lobbies.message {
            Text(verbatim: message)
                .style(.init(size: 13, weight: .regular, color: Theme.danger))
        }
    }

    @ViewBuilder private var footer: some View {
        if let current = lobbies.current {
            if current.isHost {
                if case .room = host.state {
                    ModalCancel(title: "Close window")
                    SecondaryPill(title: "Close lobby", height: 38) {
                        host.close()
                    }
                    PrimaryPill(title: "Start server", height: 38, isDisabled: busy) {
                        host.startServer(settings: settings, app: app)
                    }
                } else if case .running = host.state {
                    SecondaryPill(title: "Stop server", height: 38) {
                        host.stopRunningServer()
                    }
                    .disabled(busy)
                    PrimaryPill(title: "Play", showsPlay: true, height: 38, isDisabled: busy) {
                        host.play(settings: settings, app: app, play: play)
                    }
                    SecondaryPill(title: "Close lobby", height: 38) {
                        host.close()
                    }
                } else {
                    ModalCancel(title: "Close window")
                    SecondaryPill(title: "Close lobby", height: 38) {
                        host.close()
                    }
                }
            } else {
                SecondaryPill(title: "Leave lobby", height: 38) {
                    guest.leave()
                }
                PrimaryPill(
                    title: "Play",
                    showsPlay: true,
                    height: 38,
                    isDisabled: !current.isRunning || lobbies.tunnelPort == nil || busy
                ) {
                    guest.play(settings: settings, app: app, play: play)
                }
            }
        } else {
            ModalCancel()
            PrimaryPill(title: "Create lobby", height: 38, isDisabled: !canCreate) {
                host.createRoom(
                    base: selected,
                    reuseBase: false,
                    mcVersion: selected?.minecraftVersion ?? emptyMinecraftVersion,
                    name: effectiveLobbyName,
                    privacy: privacy,
                    maxPlayers: maxPlayers,
                    settings: settings,
                    app: app
                )
            }
        }
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        account.isSignedIn && host.eulaAccepted && !busy
    }

    private var defaultLobbyName: String {
        "\(settings.nickname)'s world"
    }

    private var effectiveLobbyName: String {
        let trimmed = lobbyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultLobbyName : trimmed
    }

    private var startSourceTitle: String {
        if let selected {
            return L("Copy of %@", selected.name)
        }
        return L("New empty lobby (Fabric)")
    }

    private func privacyTitle(_ privacy: LobbyPrivacy) -> String {
        switch privacy {
        case .friends:
            return L("Friends")
        case .invite:
            return L("Invite only")
        }
    }

    private var contentGroups: [LobbyContentGroup] {
        let items = lobbies.items
        let mods = items.filter { contentKind(for: $0) == .mods }
        let shaders = items.filter { contentKind(for: $0) == .shaders }
        let resourcePacks = items.filter { contentKind(for: $0) == .resourcePacks }

        return [
            LobbyContentGroup(id: "mods", title: "Mods", items: mods),
            LobbyContentGroup(id: "shaders", title: "Shaders", items: shaders),
            LobbyContentGroup(id: "resource-packs", title: "Resource packs", items: resourcePacks)
        ].filter { !$0.items.isEmpty }
    }

    private func contentKind(for item: LobbyItem) -> LobbyContentKind {
        let value = String(describing: item.kind).lowercased()
        if value.contains("shader") {
            return .shaders
        }
        if value.contains("resource") || value.contains("pack") {
            return .resourcePacks
        }
        return .mods
    }

    private func canRemove(_ item: LobbyItem, current: ActiveLobby) -> Bool {
        guard !current.isRunning else { return false }
        if current.isHost {
            return true
        }
        guard let ownUserID else { return false }
        return current.canEdit && ownUserID == item.addedBy
    }

    private var ownUserID: String? {
        reflectedAccountID(from: Mirror(reflecting: account), depth: 0)
    }

    private func reflectedAccountID(from mirror: Mirror, depth: Int) -> String? {
        guard depth < 5 else { return nil }

        let preferredLabels = [
            "userID",
            "profileID",
            "sessionID",
            "accountID",
            "id"
        ]

        for child in mirror.children {
            guard let label = child.label, preferredLabels.contains(label) else { continue }
            if let value = reflectedString(child.value), !value.isEmpty {
                return value
            }
        }

        for child in mirror.children {
            if let value = reflectedAccountID(from: Mirror(reflecting: child.value), depth: depth + 1) {
                return value
            }
        }

        return nil
    }

    private func reflectedString(_ value: Any) -> String? {
        if let value = value as? String {
            return value
        }

        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional, let child = mirror.children.first {
            return reflectedString(child.value)
        }

        return nil
    }
}

// MARK: - Small lobby views

private struct LobbyField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr: label)
                .style(.init(size: 13, weight: .medium, color: Theme.textSecondary))
            content()
        }
    }
}

private struct LobbyHeader: View {
    let current: ActiveLobby
    let copiedCode: Bool
    let copyCode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: current.name)
                .style(.init(size: 20, weight: .semibold, color: Theme.text))

            Text(verbatim: L("%@ · %@", "\(current.mcVersion)", "\(current.loader)"))
                .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))

            Text(tr: current.isRunning ? "Server is running" : "Setting up")
                .style(.init(
                    size: 13,
                    weight: .medium,
                    color: current.isRunning ? Theme.success : Theme.textSecondary
                ))

            if current.isHost, let code = current.code {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr: "Lobby code")
                            .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
                        Text(verbatim: code)
                            .font(Theme.font(size: 22, weight: .semibold, mono: true))
                            .foregroundColor(Theme.ember)
                    }

                    Spacer()

                    SecondaryPill(title: copiedCode ? "Copied" : "Copy", height: 36) {
                        copyCode()
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.elevated)
                )
            }
        }
    }
}

private struct LobbyPlayersSection: View {
    let current: ActiveLobby
    let roster: [LobbyMember]
    let ownUserID: String?
    let setCanEdit: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr: "Players")
                .style(.init(size: 16, weight: .semibold, color: Theme.text))

            ForEach(roster) { member in
                LobbyMemberRow(
                    member: member,
                    showsPermission: current.isHost && current.editPolicy == .host && isOther(member),
                    setCanEdit: {
                        setCanEdit(member.userID, !member.canEdit)
                    }
                )
            }

            if roster.isEmpty {
                Text(tr: "Only you for now. Share the code or invite a friend from Social.")
                    .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
            }

            if current.editPolicy == .friends || current.editPolicy == .all {
                Text(tr: "Anyone allowed by the lobby rules can add content.")
                    .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
            }
        }
    }

    private func isOther(_ member: LobbyMember) -> Bool {
        guard let ownUserID else { return true }
        return ownUserID != member.userID
    }
}

private struct LobbyMemberRow: View {
    let member: LobbyMember
    let showsPermission: Bool
    let setCanEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: member.nick)
                .style(.init(size: 14, weight: .regular, color: Theme.text))

            Spacer()

            Text(tr: member.state == "playing" ? "Playing" : "Joined")
                .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))

            if showsPermission {
                SecondaryPill(
                    title: member.canEdit ? "Remove access" : "Allow adding",
                    height: 34
                ) {
                    setCanEdit()
                }
            }
        }
    }
}

private enum LobbyContentKind {
    case mods
    case shaders
    case resourcePacks
}

private struct LobbyContentGroup: Identifiable {
    let id: String
    let title: String
    let items: [LobbyItem]
}

private struct LobbyContentSection: View {
    let groups: [LobbyContentGroup]
    let canEdit: Bool
    let isRunning: Bool
    let canRemove: (LobbyItem) -> Bool
    let remove: (LobbyItem) -> Void
    let addContent: () -> Void
    let progressText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr: "Content")
                .style(.init(size: 16, weight: .semibold, color: Theme.text))

            if groups.isEmpty {
                Text(tr: "Nothing here yet. Add mods, shaders or resource packs.")
                    .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr: group.title)
                            .style(.init(size: 14, weight: .medium, color: Theme.text))

                        ForEach(group.items) { item in
                            LobbyItemRow(
                                item: item,
                                canRemove: canRemove(item),
                                remove: {
                                    remove(item)
                                }
                            )
                        }
                    }
                }
            }

            if canEdit && !isRunning {
                SecondaryPill(title: "Add content", height: 38) {
                    addContent()
                }
            }

            if let progressText, !progressText.isEmpty {
                Text(verbatim: progressText)
                    .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
            }
        }
    }
}

private struct LobbyItemRow: View {
    let item: LobbyItem
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: item.title)
                    .style(.init(size: 14, weight: .regular, color: Theme.text))
                Text(verbatim: L("added by %@", item.addedNick ?? L("Unknown player")))
                    .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
            }

            Spacer()

            if canRemove {
                SecondaryPill(title: "Remove", height: 32) {
                    remove()
                }
            }
        }
    }
}

private struct LobbyRulesSection: View {
    let current: ActiveLobby
    let updateSettings: (LobbyEditPolicy, Bool, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr: "Rules")
                .style(.init(size: 16, weight: .semibold, color: Theme.text))

            if current.isHost {
                LobbyField(label: "Who can add content") {
                    EmberMenu(
                        label: "Who can add content",
                        value: editPolicyTitle(current.editPolicy),
                        minWidth: 220
                    ) {
                        Button {
                            updateSettings(.host, current.syncShaders, current.syncResourcePacks)
                        } label: {
                            Text(tr: "Only me")
                        }
                        Button {
                            updateSettings(.friends, current.syncShaders, current.syncResourcePacks)
                        } label: {
                            Text(tr: "Friends")
                        }
                        Button {
                            updateSettings(.all, current.syncShaders, current.syncResourcePacks)
                        } label: {
                            Text(tr: "Everyone")
                        }
                    }
                }

                EmberCheckbox(
                    label: "Sync shaders",
                    isOn: Binding(
                        get: { current.syncShaders },
                        set: { updateSettings(current.editPolicy, $0, current.syncResourcePacks) }
                    )
                )

                EmberCheckbox(
                    label: "Sync resource packs",
                    isOn: Binding(
                        get: { current.syncResourcePacks },
                        set: { updateSettings(current.editPolicy, current.syncShaders, $0) }
                    )
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr: "Who can add content")
                        .style(.init(size: 13, weight: .medium, color: Theme.textSecondary))
                    Text(tr: editPolicyTitle(current.editPolicy))
                        .style(.init(size: 14, weight: .regular, color: Theme.text))

                    Text(verbatim: L("Sync shaders: %@", current.syncShaders ? L("On") : L("Off")))
                        .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
                    Text(verbatim: L("Sync resource packs: %@", current.syncResourcePacks ? L("On") : L("Off")))
                        .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
                }
            }
        }
        .disabled(current.isRunning)
    }

    private func editPolicyTitle(_ policy: LobbyEditPolicy) -> String {
        switch policy {
        case .host:
            return L("Only me")
        case .friends:
            return L("Friends")
        case .all:
            return L("Everyone")
        }
    }
}
