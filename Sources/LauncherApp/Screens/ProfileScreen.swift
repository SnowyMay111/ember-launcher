import SwiftUI
import LauncherCore

/// Full profile page: public profile, privacy, linked accounts and play statistics.
struct ProfileScreen: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var ember: EmberAccountStore
    @EnvironmentObject var microsoft: AccountStore
    @EnvironmentObject var settings: SettingsStore

    @Local private var displayName = ""
    @Local private var tag = ""
    @Local private var bio = ""
    @Local private var avatarName = ""
    @Local private var tagNote: String?

    private var profile: EmberProfile? { ember.profile }
    private var isSaving: Bool { ember.phase == .working }

    private var isDirty: Bool {
        guard let profile else { return false }
        return displayName != profile.displayName || tag != profile.tag || bio != profile.bio || avatarName != (profile.avatarName ?? "")
    }

    private var totalMinutes: Int { app.instances.reduce(0) { $0 + $1.playtimeSeconds / 60 } }
    private var totalMods: Int { app.instances.reduce(0) { $0 + $1.modCount } }
    private var favoritePack: String? { app.instances.max { $0.playtimeSeconds < $1.playtimeSeconds }.flatMap { $0.playtimeSeconds > 0 ? $0.name : nil } }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    eyebrow: "YOUR SPACE",
                    title: "Profile",
                    subtitle: "How friends see you, what they can see, and the accounts behind it.",
                    alignment: .leading
                )
                .padding(.bottom, 10)

                if ember.isSignedIn {
                    if profile != nil {
                        profileGroup
                        privacyGroup
                        statsGroup
                    } else {
                        Text(tr: "Loading your profile…").font(Theme.font(size: 13)).foregroundColor(Theme.textSecondary)
                    }
                } else {
                    signedOutCard
                }
                linkedGroup
                if case .failed(let text) = ember.phase {
                    Text(verbatim: text).font(Theme.font(size: 12)).foregroundColor(Theme.danger)
                }
            }
            .frame(maxWidth: 820, alignment: .topLeading)
            .padding(.top, 36)
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: ember.session?.userID) {
            ember.clearMessage()
            await ember.loadProfile()
            fillFields()
            pushStats()
        }
    }

    // MARK: - Groups

    private var signedOutCard: some View {
        SettingsGroup(title: "EMBER ACCOUNT") {
            SettingsRow(title: "Not signed in", detail: "An account gives you a profile, friends and your settings on every Mac. Playing without one works as before.", isLast: true) {
                actionButton("Sign in or create account") { app.modal = .emberSignIn }
            }
        }
    }

    private var profileGroup: some View {
        SettingsGroup(title: "PROFILE") {
            SettingsRow(title: "Display name", detail: "The name friends see.") {
                VoxelInput(label: "Display name", text: $displayName, width: 240)
            }
            SettingsRow(title: "Tag", detail: tagNote ?? "Unique, 3-16 letters, digits or underscore. Friends find you by it.") {
                VoxelInput(label: "Tag", text: $tag, width: 240)
            }
            SettingsRow(title: "About", detail: "Up to 200 characters.") {
                VoxelInput(label: "About", text: $bio, width: 240)
            }
            SettingsRow(title: "Avatar", detail: "Minecraft name whose skin head is shown. Empty uses your nickname.", isLast: true) {
                HStack(spacing: 12) {
                    PlayerHead(name: avatarName.isEmpty ? settings.nickname : avatarName, size: 38)
                    VoxelInput(label: "Avatar name", text: $avatarName, width: 190)
                }
            }
            if isDirty {
                HStack {
                    Spacer()
                    actionButton(isSaving ? "Saving…" : "Save changes") { saveProfile() }
                        .disabled(isSaving)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
        }
    }

    private var privacyGroup: some View {
        SettingsGroup(title: "PRIVACY") {
            SettingsRow(title: "Show when I'm playing", detail: "Friends see your online status and the game you are in.") {
                VoxelToggle(label: "Show online status", isOn: binding(\.showOnlineStatus, { EmberProfileUpdate(showOnlineStatus: $0) }))
            }
            SettingsRow(title: "Friend requests", detail: "Who can send you a request.") {
                choice(["everyone": "Everyone", "nobody": "Nobody"], value: profile?.friendRequests ?? "everyone") {
                    save(EmberProfileUpdate(friendRequests: $0))
                }
            }
            SettingsRow(title: "Profile visibility", detail: "Who can open your profile.") {
                choice(["public": "Public", "friends": "Friends", "private": "Only me"], value: profile?.profileVisibility ?? "public") {
                    save(EmberProfileUpdate(profileVisibility: $0))
                }
            }
            SettingsRow(title: "Show statistics", detail: "Play time and pack counts on your profile.", isLast: true) {
                VoxelToggle(label: "Show statistics", isOn: binding(\.showStats, { EmberProfileUpdate(showStats: $0) }))
            }
        }
    }

    private var statsGroup: some View {
        SettingsGroup(title: "STATISTICS") {
            SettingsRow(title: "Play time", detail: "Across all instances on this Mac.") { value(Self.duration(totalMinutes)) }
            SettingsRow(title: "Instances", detail: "Installed here.") { value("\(app.instances.count)") }
            SettingsRow(title: "Mods", detail: "Installed across instances.") { value("\(totalMods)") }
            SettingsRow(title: "Most played", detail: "The instance you launch the most.", isLast: true) { value(favoritePack ?? "–") }
        }
    }

    private var linkedGroup: some View {
        SettingsGroup(title: "LINKED ACCOUNTS") {
            if ember.isSignedIn {
                SettingsRow(title: "Ember", detail: ember.session?.email ?? "Signed in") {
                    actionButton("Sign out") { ember.signOut() }
                }
            }
            SettingsRow(
                title: "Microsoft · Minecraft",
                detail: microsoft.session.map { L("Signed in as %@", $0.name) } ?? "Needed for online servers and your own skin. Offline play needs nothing.",
                isLast: true
            ) {
                if microsoft.isSignedIn {
                    actionButton("Sign out") { microsoft.signOut() }
                } else {
                    actionButton("Sign in with Microsoft") { microsoft.signIn(); app.modal = .profile }
                }
            }
        }
    }

    // MARK: - Pieces

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(tr: title)
                .font(Theme.font(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 27/255, green: 17/255, blue: 10/255))
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(Theme.emberGradient)
                .cornerRadius(Theme.radiusCompact)
        }
        .buttonStyle(.plain)
    }

    private func value(_ text: String) -> some View {
        Text(verbatim: text).font(Theme.font(size: 13, weight: .semibold)).foregroundColor(Theme.text)
    }

    private func choice(_ options: [String: String], value: String, onPick: @escaping (String) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(options.keys.sorted(by: { options[$0]! < options[$1]! }), id: \.self) { key in
                Button { onPick(key) } label: {
                    Text(tr: options[key] ?? key)
                        .font(Theme.font(size: 12, weight: .medium))
                        .foregroundColor(value == key ? Theme.ember : Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(RoundedRectangle(cornerRadius: 8).fill(value == key ? Theme.elevated : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(value == key ? Theme.ember.opacity(0.5) : Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func binding(_ keyPath: KeyPath<EmberProfile, Bool>, _ update: @escaping (Bool) -> EmberProfileUpdate) -> Binding<Bool> {
        Binding(get: { profile?[keyPath: keyPath] ?? true }, set: { save(update($0)) })
    }

    // MARK: - Actions

    private func fillFields() {
        guard let profile else { return }
        displayName = profile.displayName
        tag = profile.tag
        bio = profile.bio
        avatarName = profile.avatarName ?? ""
    }

    private func save(_ update: EmberProfileUpdate) { ember.save(update) }

    private func saveProfile() {
        guard let profile else { return }
        let newTag = tag.trimmingCharacters(in: .whitespaces).lowercased()
        Task {
            if newTag != profile.tag, !(await ember.isTagAvailable(newTag)) {
                tagNote = L("This tag is taken or not allowed.")
                return
            }
            tagNote = nil
            let update = EmberProfileUpdate(
                tag: newTag != profile.tag ? newTag : nil,
                displayName: displayName != profile.displayName ? displayName.trimmingCharacters(in: .whitespaces) : nil,
                bio: bio != profile.bio ? String(bio.prefix(200)) : nil,
                avatarName: avatarName != (profile.avatarName ?? "") ? String(avatarName.prefix(16)) : nil
            )
            ember.save(update)
        }
    }

    /// Keeps the server copy of the numbers in step with this Mac; only sent when something changed.
    private func pushStats() {
        guard let profile else { return }
        guard profile.playtimeMinutes != totalMinutes || profile.instancesCount != app.instances.count
            || profile.modsCount != totalMods || profile.favoritePack != favoritePack else { return }
        ember.save(EmberProfileUpdate(playtimeMinutes: totalMinutes, instancesCount: app.instances.count, modsCount: totalMods, favoritePack: favoritePack))
    }

    private static func duration(_ minutes: Int) -> String {
        minutes < 60 ? L("%d min", minutes) : L("%d h %d min", minutes / 60, minutes % 60)
    }
}
