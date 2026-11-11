import LauncherCore
import SwiftUI

/// Saved lobby servers: start and stop them, see who is playing, manage players, world settings and mods.
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
    @Local private var backupBusy = false
    @Local private var lastBackup: Date?
    @Local private var worldBytes: Int64 = 0
    /// Counts `refreshBackup` calls, so a slow older answer never replaces a newer one.
    @Local private var statsRequest = 0
    @Local private var backupNote = ""
    @EnvironmentObject private var lobbies: LobbyStore

    private var selected: ServerProfile? {
        profiles.first { $0.id == selectedID } ?? profiles.first
    }

    private func isRunning(_ profile: ServerProfile) -> Bool {
        host.runningInstance == profile.instanceName
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    chips
                    if let profile = selected {
                        detail(profile, proxy: proxy).id(profile.id)
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 56)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.never)
        }
        .task { reload() }
        .onChange(of: host.runningInstance) { _, _ in reload() }
        .onChange(of: selectedID) { _, _ in refreshBackup() }
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
        refreshBackup()
    }

    private func refreshBackup() {
        statsRequest += 1
        let request = statsRequest
        guard let profile = selected else { lastBackup = nil; worldBytes = 0; return }
        let library = host.library
        let name = profile.instanceName
        Task {
            // Walking the world and every backup folder is slow on big worlds, so it stays off the main thread.
            let (date, bytes) = await Task.detached {
                (library.listBackups(for: name).first?.date, library.worldFolderSize(for: name))
            }.value
            guard request == statsRequest else { return }
            lastBackup = date
            worldBytes = bytes
        }
    }

    // MARK: - Server chips

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(profiles) { profile in
                    chip(profile)
                }
                Button { app.modal = .lobby } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                        Text(verbatim: L("New server")).font(Theme.font(size: 13, weight: .medium))
                    }
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .overlay(Capsule().strokeBorder(Theme.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.never)
    }

    private func chip(_ profile: ServerProfile) -> some View {
        let isSelected = profile.id == selected?.id
        return Button { selectedID = profile.id } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isRunning(profile) ? Theme.success : Theme.textMuted)
                    .frame(width: 8, height: 8)
                Text(verbatim: profile.name)
                    .font(Theme.font(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? Theme.text : Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(isSelected ? Theme.elevated : Theme.surface))
            .overlay(Capsule().strokeBorder(isSelected ? Theme.ember.opacity(0.7) : Theme.border, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
        .background(cardBackground(radius: 16))
    }

    private func cardBackground(radius: CGFloat = 16, stroke: Color = Theme.border) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(stroke, lineWidth: 1))
    }

    // MARK: - Detail

    private func detail(_ profile: ServerProfile, proxy: ScrollViewProxy) -> some View {
        let running = isRunning(profile)
        return VStack(alignment: .leading, spacing: 16) {
            hero(profile, running: running)
            tiles(profile, running: running, proxy: proxy)
            tabStrip
            switch tab {
            case .panel:
                overview(profile, running: running)
            case .settings:
                card {
                    ServerWorldTab(part: .settings, profile: profile, running: running, onChanged: reload) {
                        selectedID = nil
                        reload()
                    }
                }
            case .world:
                card { ServerWorldTab(part: .world, profile: profile, running: running, onChanged: reload, onDeleted: {}) }
            case .mods:
                card { ServerModsTab(profile: profile, running: running) }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(cardBackground())
    }

    private var tabStrip: some View {
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
        .background(cardBackground(stroke: running ? Theme.success.opacity(0.45) : Theme.border))
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
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.elevated))
    }

    private func statsRow(_ profile: ServerProfile, running: Bool) -> some View {
        HStack(spacing: 10) {
            stat(L("Players"), running ? "\(host.players.count) / \(profile.maxPlayers)" : "– / \(profile.maxPlayers)")
            stat(L("World size"), worldSize)
            stat(L("Last backup"), lastBackup.map { $0.formatted(.relative(presentation: .named)) } ?? L("Never"))
        }
        .padding(.top, 4)
    }

    /// Measured by `refreshBackup`, not while drawing: the screen redraws on every console line.
    private var worldSize: String {
        guard worldBytes > 0 else { return "–" }
        return ByteCountFormatter.string(fromByteCount: worldBytes, countStyle: .file)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: label)
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Theme.textSecondary)
            Text(verbatim: value)
                .font(Theme.font(size: 15, weight: .medium))
                .foregroundColor(Theme.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.elevated))
    }

    // MARK: - Quick actions

    private func tiles(_ profile: ServerProfile, running: Bool, proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            tile(icon: "person.badge.plus", title: L("Invite friends"), subtitle: L("Choose who can join")) {
                tab = .panel
                withAnimation { proxy.scrollTo("allowed", anchor: .center) }
            }
            tile(
                icon: "externaldrive",
                title: backupBusy ? L("Working…") : L("Back up now"),
                subtitle: backupNote.isEmpty ? L("Copy the world") : backupNote
            ) { backUp(profile, running: running) }
            tile(icon: "slider.horizontal.3", title: L("Settings"), subtitle: L("Difficulty, mode, backups")) {
                tab = .settings
            }
        }
    }

    private func tile(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.ember)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.ember.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)
                        .font(Theme.font(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                    Text(verbatim: subtitle)
                        .font(Theme.font(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground())
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDimStyle())
    }

    private func backUp(_ profile: ServerProfile, running: Bool) {
        guard !backupBusy else { return }
        backupBusy = true
        backupNote = ""
        let library = host.library
        let name = profile.instanceName
        Task {
            if running {
                host.send("save-off")
                host.send("save-all flush")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
            let result = await Task.detached { Result { try library.backupWorld(for: name) } }.value
            if running { host.send("save-on") }
            switch result {
            case .success: backupNote = L("Backup saved.")
            case .failure: backupNote = L("Could not back up the world.")
            }
            refreshBackup()
            backupBusy = false
        }
    }

    // MARK: - Overview

    private func overview(_ profile: ServerProfile, running: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(L("Players"))
                ServerPlayersTab(profile: profile, running: running)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(cardBackground())

            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(L("What is happening"))
                activityFeed(running: running)
                consoleToggle(running: running)
                if consoleOpen {
                    ServerConsoleTab(profile: profile, running: running)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(cardBackground())
            .animation(.easeInOut(duration: 0.2), value: consoleOpen)
        }
    }

    private func activityFeed(running: Bool) -> some View {
        let events = running ? ServerActivityFeed.build(from: host.logLines) : []
        return VStack(alignment: .leading, spacing: 0) {
            if events.isEmpty {
                Text(verbatim: running ? L("Nothing yet.") : L("Start the server to see what happens."))
                    .font(Theme.font(size: 13, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.vertical, 8)
            }
            ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                let (icon, color, text) = describe(event)
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color)
                        .frame(width: 18)
                    Text(verbatim: text)
                        .font(Theme.font(size: 13, weight: .regular))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
            }
        }
    }

    private func describe(_ event: ServerActivityKind) -> (String, Color, String) {
        switch event {
        case .joined(let name): return ("arrow.right.circle", Theme.success, L("%@ joined", name))
        case .left(let name): return ("arrow.left.circle", Theme.textSecondary, L("%@ left", name))
        case .worldSaved: return ("checkmark.circle", Theme.ember, L("World saved"))
        case .started: return ("play.circle", Theme.success, L("Server started"))
        }
    }

    private func consoleToggle(running: Bool) -> some View {
        Button { consoleOpen.toggle() } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .rotationEffect(.degrees(consoleOpen ? 90 : 0))
                Text(verbatim: L("Full console"))
                    .font(Theme.font(size: 13, weight: .medium))
                    .foregroundColor(Theme.text)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
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
}
