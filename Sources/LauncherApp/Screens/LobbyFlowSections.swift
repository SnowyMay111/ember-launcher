import SwiftUI
import LauncherCore

// MARK: - Small lobby views

struct LobbyField<Content: View>: View {
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

struct LobbyHeader: View {
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

struct LobbyPlayersSection: View {
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

struct LobbyMemberRow: View {
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

enum LobbyContentKind {
    case mods
    case shaders
    case resourcePacks
}

struct LobbyContentGroup: Identifiable {
    let id: String
    let title: String
    let items: [LobbyItem]
}

struct LobbyContentSection: View {
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

struct LobbyItemRow: View {
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

struct LobbyRulesSection: View {
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

                HStack(spacing: 8) {
                    EmberCheckbox(
                        label: "Sync shaders",
                        isOn: Binding(
                            get: { current.syncShaders },
                            set: { updateSettings(current.editPolicy, $0, current.syncResourcePacks) }
                        )
                    )
                    Text(tr: "Sync shaders")
                        .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
                }

                HStack(spacing: 8) {
                    EmberCheckbox(
                        label: "Sync resource packs",
                        isOn: Binding(
                            get: { current.syncResourcePacks },
                            set: { updateSettings(current.editPolicy, current.syncShaders, $0) }
                        )
                    )
                    Text(tr: "Sync resource packs")
                        .style(.init(size: 13, weight: .regular, color: Theme.textSecondary))
                }
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
