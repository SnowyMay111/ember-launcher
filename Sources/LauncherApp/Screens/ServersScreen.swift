import LauncherCore
import SwiftUI

/// Saved lobby servers: start and stop them, read the console, manage players, world settings and mods.
struct ServersScreen: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var play: PlayController
    @ObservedObject private var host = LobbyHostController.shared

    private enum Tab: String, CaseIterable {
        case panel = "Overview"
        case settings = "Settings"
        case world = "World"
        case mods = "Mods"
    }

    @Local private var profiles: [ServerProfile] = []
    @Local private var selectedID: String?
    @Local private var tab: Tab = .panel
    @Local private var consoleOpen = false
    @EnvironmentObject private var lobbies: LobbyStore

    private var selected: ServerProfile? {
        profiles.first { $0.id == selectedID } ?? profiles.first
    }

    private func isRunning(_ profile: ServerProfile) -> Bool {
        host.runningInstance == profile.instanceName
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            listPanel.frame(width: 230)
            ScrollView {
                Group {
                    if let profile = selected {
                        detail(profile).id(profile.id)
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.never)
        }
        .padding(.horizontal, 56)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .task { reload() }
        .onChange(of: host.runningInstance) { _, _ in reload() }
    }

    /// Worlds hosted before profiles existed: a server folder named after an instance gets a profile from that instance.
    private func adoptLegacyServers() {
        let library = host.library
        let known = Set(library.list().map(\.instanceName))
        for item in app.instances where !known.contains(item.name) {
            let directory = library.directory(for: item.name)
            guard FileManager.default.fileExists(atPath: directory.appendingPathComponent("server.properties").path) else { continue }
            let maxPlayers = Int(ServerProperties.read(in: directory)["max-players"] ?? "") ?? 4
            try? library.save(ServerProfile(
                instanceName: item.name,
                name: item.name,
                minecraftVersion: item.minecraftVersion,
                loader: item.loader.coreName,
                maxPlayers: maxPlayers,
                lastPlayed: nil
            ))
        }
    }

    private func reload() {
        adoptLegacyServers()
        profiles = host.library.list()
        if selectedID == nil || !profiles.contains(where: { $0.id == selectedID }) {
            selectedID = host.runningInstance ?? profiles.first?.id
        }
    }

    // MARK: - List

    private var listPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: L("My servers"))
                .font(Theme.font(size: 13, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.bottom, 4)
            ForEach(profiles) { profile in
                Button {
                    selectedID = profile.id
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isRunning(profile) ? Theme.success : Theme.textMuted)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: profile.name)
                                .font(Theme.font(size: 13, weight: .medium))
                                .foregroundColor(Theme.text)
                                .lineLimit(1)
                            Text(verbatim: listSubtitle(profile))
                                .font(Theme.font(size: 12, weight: .regular))
                                .foregroundColor(isRunning(profile) ? Theme.success : Theme.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(profile.id == selected?.id ? Theme.elevated : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            SecondaryPill(title: L("New server"), height: 34, fillsWidth: true) {
                app.modal = .lobby
            }
            .padding(.top, 6)
        }
        .padding(14)
        .background(panelBackground)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: L("Start your first server"))
                .font(Theme.font(size: 16, weight: .semibold))
                .foregroundColor(Theme.text)
            Text(verbatim: L("Create a lobby and its world is saved here, so you can start it again any time."))
                .font(Theme.font(size: 13, weight: .regular))
                .foregroundColor(Theme.textSecondary)
            PrimaryPill(title: L("Create lobby"), height: 38) { app.modal = .lobby }
        }
        .padding(20)
        .background(panelBackground)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private func listSubtitle(_ profile: ServerProfile) -> String {
        if isRunning(profile) { return L("Running · %d online", host.players.count) }
        return "\(profile.loader.capitalized) \(profile.minecraftVersion)"
    }

    // MARK: - Detail

    private func detail(_ profile: ServerProfile) -> some View {
        let running = isRunning(profile)
        return VStack(alignment: .leading, spacing: 14) {
            hero(profile, running: running)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(Tab.allCases, id: \.self) { item in
                        Button { tab = item } label: {
                            Text(verbatim: L(item.rawValue))
                                .font(Theme.font(size: 13, weight: .medium))
                                .foregroundColor(tab == item ? Theme.text : Theme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(tab == item ? Theme.ember : Color.clear).frame(height: 2)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }

                switch tab {
                case .panel: panel(profile, running: running)
                case .settings:
                    ServerWorldTab(part: .settings, profile: profile, running: running, onChanged: reload) {
                        selectedID = nil
                        reload()
                    }
                case .world:
                    ServerWorldTab(part: .world, profile: profile, running: running, onChanged: reload, onDeleted: {})
                case .mods:
                    ServerModsTab(profile: profile, running: running)
                }
            }
            .padding(18)
            .background(panelBackground)
        }
    }

    // MARK: - Hero

    private func hero(_ profile: ServerProfile, running: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: profile.name)
                        .font(Theme.font(size: 22, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Text(verbatim: "\(profile.loader.capitalized) \(profile.minecraftVersion) · " + lastPlayedText(profile))
                        .font(Theme.font(size: 13, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer(minLength: 12)
                statusBadge(running: running)
            }

            HStack(spacing: 10) {
                if running {
                    PrimaryPill(title: L("Join"), showsPlay: true, height: 40, isDisabled: play.isBusy || host.state != .running) {
                        host.play(settings: settings, app: app, play: play)
                    }
                    SecondaryPill(title: L("Stop"), height: 40) { host.stopRunningServer() }
                } else {
                    PrimaryPill(title: L("Start"), height: 40, isDisabled: !canStart(profile)) { start(profile) }
                }
                if let progress = progressText {
                    ProgressView().controlSize(.small)
                    Text(verbatim: progress)
                        .font(Theme.font(size: 13, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                } else if !running, !host.eulaAccepted {
                    Text(verbatim: L("Accept the Minecraft EULA in Create lobby first."))
                        .font(Theme.font(size: 13, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            if running { addressRow }
            statsRow(profile, running: running)
            HStack(spacing: 8) {
                EmberCheckbox(label: "Open Minecraft with my server", isOn: $settings.joinOwnServer)
                Text(verbatim: L("Open Minecraft with my server"))
                    .font(Theme.font(size: 13, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.top, -6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(running ? Theme.success.opacity(0.45) : Theme.border, lineWidth: 1)
                )
        )
    }

    private var progressText: String? {
        if case .preparing(let text) = host.state { return text }
        return nil
    }

    private func statusBadge(running: Bool) -> some View {
        let starting = progressText != nil
        let color = running ? Theme.success : (starting ? Theme.ember : Theme.textMuted)
        let text = running ? L("Running") : (starting ? L("Starting…") : L("Stopped"))
        return HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(verbatim: text)
                .font(Theme.font(size: 13, weight: .medium))
                .foregroundColor(Theme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.elevated))
    }

    private func lastPlayedText(_ profile: ServerProfile) -> String {
        guard let date = profile.lastPlayed else { return L("Never started") }
        return L("Last started %@", date.formatted(.relative(presentation: .named)))
    }

    /// The address friends can paste into Minecraft; published once the tunnel is up.
    private var addressRow: some View {
        HStack(spacing: 10) {
            Text(verbatim: L("Address"))
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
            if let address = lobbies.current?.address {
                Text(verbatim: address)
                    .font(Theme.font(size: 13, weight: .medium))
                    .foregroundColor(Theme.text)
                    .textSelection(.enabled)
                    .lineLimit(1)
                Spacer()
                SecondaryPill(title: L("Copy address"), height: 30) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(address, forType: .string)
                }
            } else {
                Text(verbatim: L("Waiting for the address…"))
                    .font(Theme.font(size: 13, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.elevated))
    }

    private func panel(_ profile: ServerProfile, running: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(L("Players"))
            ServerPlayersTab(profile: profile, running: running)
            Button { consoleOpen.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .rotationEffect(.degrees(consoleOpen ? 90 : 0))
                    Text(verbatim: L("Console"))
                        .font(Theme.font(size: 15, weight: .semibold))
                        .foregroundColor(Theme.text)
                    if !consoleOpen, running, let last = host.logLines.last {
                        Text(verbatim: last)
                            .font(Theme.font(size: 12, weight: .regular, mono: true))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            if consoleOpen {
                ServerConsoleTab(profile: profile, running: running)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: consoleOpen)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(verbatim: text)
            .font(Theme.font(size: 15, weight: .semibold))
            .foregroundColor(Theme.text)
    }

    private func instance(for profile: ServerProfile) -> LibraryInstance? {
        app.instances.first { $0.name == profile.instanceName }
    }

    private func canStart(_ profile: ServerProfile) -> Bool {
        host.eulaAccepted && !host.isBusy && !play.isBusy && host.runningInstance == nil && instance(for: profile) != nil
    }

    private func start(_ profile: ServerProfile) {
        guard let item = instance(for: profile) else { return }
        host.createRoom(
            base: item,
            reuseBase: true,
            mcVersion: item.minecraftVersion,
            name: profile.name,
            privacy: .invite,
            maxPlayers: profile.maxPlayers,
            settings: settings,
            app: app,
            startImmediately: true
        )
    }

    private func statsRow(_ profile: ServerProfile, running: Bool) -> some View {
        HStack(spacing: 10) {
            stat(L("Players"), running ? "\(host.players.count) / \(profile.maxPlayers)" : "– / \(profile.maxPlayers)")
            stat(L("Uptime"), running ? uptime : "–")
            stat(L("World size"), worldSize(profile))
        }
        .padding(.top, 8)
    }

    private var uptime: String {
        guard let startedAt = host.startedAt else { return "–" }
        let minutes = Int(Date().timeIntervalSince(startedAt) / 60)
        return minutes < 60 ? L("%d min", minutes) : L("%d h %d min", minutes / 60, minutes % 60)
    }

    private func worldSize(_ profile: ServerProfile) -> String {
        let bytes = host.library.worldFolderSize(for: profile.instanceName)
        guard bytes > 0 else { return "–" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: label)
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
            Text(verbatim: value)
                .font(Theme.font(size: 15, weight: .medium))
                .foregroundColor(Theme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.elevated))
    }
}

// MARK: - Console

private struct ServerConsoleTab: View {
    let profile: ServerProfile
    let running: Bool
    @ObservedObject private var host = LobbyHostController.shared
    @Local private var command = ""
    @Local private var savedLog: [String] = []

    private var lines: [String] { running ? host.logLines : savedLog }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(verbatim: line)
                                .font(Theme.font(size: 12, weight: .regular, mono: true))
                                .foregroundColor(line.hasPrefix(">") ? Theme.ember : Theme.text.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 240)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.bg))
                .onChange(of: lines.count) { _, count in
                    if count > 0 { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }
            if running {
                HStack(spacing: 8) {
                    EmberInput(label: "Command", text: $command, placeholder: "gamerule keepInventory true")
                        .onSubmit(send)
                    SecondaryPill(title: L("Send"), height: 40, action: send)
                }
                HStack(spacing: 8) {
                    quick(L("Day"), "time set day")
                    quick(L("Clear"), "weather clear")
                    quick(L("Save world"), "save-all")
                }
            } else {
                Text(verbatim: L("Start the server to send commands."))
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .task { loadSavedLog() }
    }

    private func quick(_ title: String, _ command: String) -> some View {
        SecondaryPill(title: title, height: 30) { host.send(command) }
    }

    private func send() {
        host.send(command)
        command = ""
    }

    private func loadSavedLog() {
        let url = host.library.directory(for: profile.instanceName).appendingPathComponent("launcher-server.log")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        savedLog = Array(text.split(separator: "\n", omittingEmptySubsequences: true).suffix(150)).map(String.init)
    }
}

// MARK: - Players

private struct ServerPlayersTab: View {
    let profile: ServerProfile
    let running: Bool
    @ObservedObject private var host = LobbyHostController.shared
    @EnvironmentObject private var friends: FriendsStore
    @EnvironmentObject private var app: AppState
    @Local private var healthPlayer = ""
    @Local private var healthValue = "20"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !running {
                note(L("Start the server to manage players."))
            } else if host.players.isEmpty {
                note(L("Nobody is online."))
            } else {
                ForEach(host.players, id: \.self) { name in
                    row {
                        Text(verbatim: name)
                            .font(Theme.font(size: 13, weight: .medium))
                            .foregroundColor(Theme.text)
                        Spacer()
                        action(L("Heal")) { (ServerCommand.healAndFeed(name) ?? []).forEach(host.send) }
                        action(L("Creative")) { send(ServerCommand.gamemode("creative", name)) }
                        action(L("Survival")) { send(ServerCommand.gamemode("survival", name)) }
                        action(L("Operator")) { send(ServerCommand.op(name)) }
                        action(L("Kick")) { send(ServerCommand.kick(name, reason: nil)) }
                        action(L("Ban")) { send(ServerCommand.ban(name, reason: nil)) }
                    }
                }
                row {
                    Text(verbatim: L("Max health"))
                        .font(Theme.font(size: 13, weight: .regular))
                        .foregroundColor(Theme.text)
                    Spacer()
                    EmberMenu(label: "Player", value: healthPlayer.isEmpty ? (host.players.first ?? "") : healthPlayer, minWidth: 120) {
                        ForEach(host.players, id: \.self) { name in
                            Button(name) { healthPlayer = name }
                        }
                    }
                    EmberInput(label: "Health", text: $healthValue, width: 64, alignment: .center)
                    action(L("Apply")) {
                        let target = healthPlayer.isEmpty ? (host.players.first ?? "") : healthPlayer
                        send(ServerCommand.setMaxHealth(Int(healthValue) ?? 20, target, minecraftVersion: profile.minecraftVersion))
                    }
                }
            }
            allowedSection
        }
    }

    private var allowed: [TrustedPlayer] {
        _ = host.trustedRevision
        return host.trusted(for: profile.instanceName)
    }

    private var allowedSection: some View {
        let list = allowed
        let candidates = friends.friendsList.filter { friend in !list.contains { $0.userID == friend.userID } }
        return VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: L("Allowed players"))
                .font(Theme.font(size: 14, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.top, 16)
            Text(verbatim: L("Only these friends can join, even when you are away from the game. Friends who join are added automatically."))
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 4)
                .padding(.bottom, 4)
            if list.isEmpty {
                note(L("Nobody is allowed yet."))
            }
            ForEach(list) { player in
                row {
                    Text(verbatim: player.name)
                        .font(Theme.font(size: 13, weight: .medium))
                        .foregroundColor(Theme.text)
                    Text(verbatim: player.tag)
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    action(L("Remove")) { host.disallow(userID: player.userID, on: profile.instanceName) }
                }
            }
            if candidates.isEmpty {
                row {
                    Text(verbatim: L(friends.friendsList.isEmpty ? "No friends to add yet." : "All your friends are already allowed."))
                        .font(Theme.font(size: 13, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    if friends.friendsList.isEmpty {
                        action(L("Open Social")) { app.screen = .social }
                    }
                }
            } else {
                row {
                    Text(verbatim: L("Add a friend"))
                        .font(Theme.font(size: 13, weight: .regular))
                        .foregroundColor(Theme.text)
                    Spacer()
                    EmberMenu(label: "Friend", value: L("Choose…"), minWidth: 160) {
                        ForEach(candidates) { friend in
                            Button(friend.displayName) {
                                host.allow(
                                    [TrustedPlayer(userID: friend.userID, tag: friend.tag, name: friend.displayName)],
                                    on: profile.instanceName
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func send(_ command: String?) {
        if let command { host.send(command) }
    }

    private func note(_ text: String) -> some View {
        Text(verbatim: text)
            .font(Theme.font(size: 13, weight: .regular))
            .foregroundColor(Theme.textSecondary)
            .padding(.vertical, 8)
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8, content: content)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private func action(_ title: String, _ run: @escaping () -> Void) -> some View {
        SecondaryPill(title: title, height: 30, action: run)
    }
}

// MARK: - World

private struct ServerWorldTab: View {
    enum Part { case settings, world }

    let part: Part
    let profile: ServerProfile
    let running: Bool
    let onChanged: () -> Void
    let onDeleted: () -> Void
    @Local private var newName = ""
    @Local private var autoBackup = false
    @Local private var settingsNote = ""
    @ObservedObject private var host = LobbyHostController.shared
    @Local private var difficulty = "easy"
    @Local private var gamemode = "survival"
    @Local private var pvp = true
    @Local private var maxPlayers = 4
    @Local private var backups: [WorldBackup] = []
    @Local private var backupNote = ""
    @Local private var backupBusy = false

    private let difficulties = ["peaceful", "easy", "normal", "hard"]
    private let modes = ["survival", "creative", "adventure"]
    private let rules: [(name: String, title: String)] = [
        ("keepInventory", "Keep inventory after death"),
        ("mobGriefing", "Mobs break blocks"),
        ("doDaylightCycle", "Day and night cycle"),
        ("doMobSpawning", "Mobs spawn"),
    ]

    private var directory: URL { host.library.directory(for: profile.instanceName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch part {
            case .settings:
                nameRow
            row(L("Difficulty")) {
                EmberMenu(label: "Difficulty", value: L(difficulty.capitalized), minWidth: 160) {
                    ForEach(difficulties, id: \.self) { value in
                        Button(L(value.capitalized)) {
                            difficulty = value
                            save(["difficulty": value])
                            if running, let command = ServerCommand.difficulty(value) { host.send(command) }
                        }
                    }
                }
            }
            row(L("Default game mode")) {
                EmberMenu(label: "Game mode", value: L(gamemode.capitalized), minWidth: 160) {
                    ForEach(modes, id: \.self) { value in
                        Button(L(value.capitalized)) { gamemode = value; save(["gamemode": value]) }
                    }
                }
            }
            row("PvP") {
                EmberToggle(label: "PvP", isOn: Binding(get: { pvp }, set: { pvp = $0; save(["pvp": $0 ? "true" : "false"]) }))
            }
            row(L("Max players")) {
                EmberMenu(label: "Max players", value: "\(maxPlayers)", minWidth: 80) {
                    ForEach([2, 4, 6, 8, 10, 16, 20], id: \.self) { value in
                        Button("\(value)") { maxPlayers = value; save(["max-players": "\(value)"]) }
                    }
                }
            }
                row(L("Back up on stop")) {
                    EmberToggle(label: "Back up on stop", isOn: Binding(
                        get: { autoBackup },
                        set: {
                            autoBackup = $0
                            try? host.library.setAutoBackup(profile.instanceName, $0)
                            onChanged()
                        }
                    ))
                }
                Text(verbatim: L("Copies the world each time the server stops and keeps the last 5 copies."))
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 8)
            Text(verbatim: running
                 ? L("Game mode, PvP and max players apply after a restart.")
                 : L("Changes are saved right away."))
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 10)
                manageSection
            case .world:
            if running {
                ForEach(rules, id: \.name) { rule in
                    row(L(rule.title)) {
                        ruleButton(L("On"), rule.name, true)
                        ruleButton(L("Off"), rule.name, false)
                    }
                }
                row(L("Time")) {
                    timeButton(L("Day"), "day")
                    timeButton(L("Night"), "night")
                }
                row(L("Weather")) {
                    weatherButton(L("Clear"), "clear")
                    weatherButton(L("Rain"), "rain")
                }
            } else {
                Text(verbatim: L("Rules, time and weather can be changed while the server is running."))
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 10)
            }
                backupsSection
            }
        }
        .task {
            load()
            newName = profile.name
            autoBackup = profile.autoBackup
            backups = host.library.listBackups(for: profile.instanceName)
        }
    }

    private var nameRow: some View {
        row(L("Name")) {
            EmberInput(label: "Server name", text: $newName, width: 220)
            SecondaryPill(title: L("Save"), height: 30) {
                try? host.library.rename(profile.instanceName, to: newName)
                onChanged()
            }
            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newName == profile.name)
        }
    }

    private var manageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: L("Manage"))
                .font(Theme.font(size: 15, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.top, 20)
            row(L("Server folder")) {
                SecondaryPill(title: L("Show in Finder"), height: 30) { NSWorkspace.shared.open(directory) }
            }
            row(L("Delete server")) {
                SecondaryPill(title: L("Move to Trash"), height: 30, action: confirmDelete)
                    .disabled(running)
            }
            Text(verbatim: running
                 ? L("Stop the server before deleting it.")
                 : (settingsNote.isEmpty
                    ? L("The world and its backups go to the Trash, so you can put them back. The game instance stays in the Library.")
                    : settingsNote))
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 8)
        }
    }

    private func confirmDelete() {
        let alert = NSAlert()
        alert.messageText = L("Move “%@” to the Trash?", profile.name)
        alert.informativeText = L("The world and its backups go to the Trash, so you can put them back. The game instance stays in the Library.")
        alert.addButton(withTitle: L("Move to Trash"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try host.library.remove(profile.instanceName)
            onDeleted()
        } catch {
            settingsNote = L("Could not move the server to the Trash.")
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: title)
                .font(Theme.font(size: 13, weight: .regular))
                .foregroundColor(Theme.text)
            Spacer()
            content()
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private var backupsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: L("Backups"))
                .font(Theme.font(size: 15, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(.top, 20)
            Text(verbatim: backupNote.isEmpty
                 ? L("Copies the world. Restoring keeps the current world in the backups folder.")
                 : backupNote)
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 4)
                .padding(.bottom, 4)
            row(L("World backup")) {
                SecondaryPill(title: backupBusy ? L("Working…") : L("Back up now"), height: 30, action: backUp)
            }
            ForEach(backups.prefix(6)) { backup in
                row(backup.date.formatted(date: .abbreviated, time: .shortened)) {
                    Text(verbatim: ByteCountFormatter.string(fromByteCount: backup.bytes, countStyle: .file))
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                    if !running {
                        SecondaryPill(title: L("Restore"), height: 30) { restore(backup) }
                    }
                }
            }
        }
    }

    private func backUp() {
        guard !backupBusy else { return }
        backupBusy = true
        let library = host.library
        let name = profile.instanceName
        let wasRunning = running
        Task {
            if wasRunning {
                host.send("save-off")
                host.send("save-all flush")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
            let result = await Task.detached { Result { try library.backupWorld(for: name) } }.value
            if wasRunning { host.send("save-on") }
            switch result {
            case .success: backupNote = L("Backup saved.")
            case .failure: backupNote = L("Could not back up the world.")
            }
            backups = library.listBackups(for: name)
            backupBusy = false
        }
    }

    private func restore(_ backup: WorldBackup) {
        guard !running else { return }
        do {
            try host.library.restoreBackup(backup, for: profile.instanceName)
            backupNote = L("Backup restored. The previous world is kept in the backups folder.")
        } catch {
            backupNote = L("Could not restore the backup.")
        }
        backups = host.library.listBackups(for: profile.instanceName)
    }

    private func ruleButton(_ title: String, _ name: String, _ value: Bool) -> some View {
        SecondaryPill(title: title, height: 30) {
            if let command = ServerCommand.gamerule(name, value) { host.send(command) }
        }
    }

    private func timeButton(_ title: String, _ value: String) -> some View {
        SecondaryPill(title: title, height: 30) {
            if let command = ServerCommand.time(value) { host.send(command) }
        }
    }

    private func weatherButton(_ title: String, _ value: String) -> some View {
        SecondaryPill(title: title, height: 30) {
            if let command = ServerCommand.weather(value) { host.send(command) }
        }
    }

    private func load() {
        let values = ServerProperties.read(in: directory)
        difficulty = values["difficulty"] ?? "easy"
        gamemode = values["gamemode"] ?? "survival"
        pvp = (values["pvp"] ?? "true") == "true"
        maxPlayers = Int(values["max-players"] ?? "") ?? profile.maxPlayers
    }

    private func save(_ values: [String: String]) {
        try? ServerProperties.update(in: directory, values: values)
        if let max = values["max-players"].flatMap(Int.init) {
            var updated = profile
            updated.maxPlayers = max
            try? host.library.save(updated)
        }
    }
}

// MARK: - Mods

private struct ServerModsTab: View {
    let profile: ServerProfile
    let running: Bool
    @EnvironmentObject var app: AppState
    @Local private var mods: [InstalledMod] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if mods.isEmpty {
                Text(verbatim: L("This world has no mods."))
                    .font(Theme.font(size: 13, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
            }
            ForEach(mods) { mod in
                HStack(spacing: 8) {
                    Text(verbatim: mod.displayTitle)
                        .font(Theme.font(size: 13, weight: .regular))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Spacer()
                    EmberToggle(label: mod.displayTitle, isOn: Binding(
                        get: { mod.isEnabled },
                        set: { toggle(mod, $0) }
                    ))
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
            }
            Text(verbatim: L("Guests get the mods that are on here. Changes apply after a restart."))
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 10)
        }
        .task { reload() }
    }

    private func manager() -> ModManager { ModManager(store: app.store) }

    private func reload() {
        mods = (try? manager().list(instance: profile.instanceName)) ?? []
    }

    private func toggle(_ mod: InstalledMod, _ enabled: Bool) {
        try? manager().setEnabled(instance: profile.instanceName, fileName: mod.fileName, enabled: enabled)
        reload()
    }
}
