import LauncherCore
import SwiftUI

/// Wraps its children onto new rows, like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}


// MARK: - Console

struct ServerConsoleTab: View {
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

struct ServerPlayersTab: View {
    let profile: ServerProfile
    let running: Bool
    @ObservedObject private var host = LobbyHostController.shared
    @EnvironmentObject private var friends: FriendsStore
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var toasts: ToastCenter
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
                        action(L("Kick")) { send(ServerCommand.kick(name, reason: nil)) }
                        EmberMenu(label: "More", value: L("More"), minWidth: 90) {
                            Button(L("Creative")) { send(ServerCommand.gamemode("creative", name)) }
                            Button(L("Survival")) { send(ServerCommand.gamemode("survival", name)) }
                            Button(L("Operator")) { send(ServerCommand.op(name)) }
                            Button(L("Ban")) { send(ServerCommand.ban(name, reason: nil)) }
                        }
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
                        guard let value = Int(healthValue.trimmingCharacters(in: .whitespaces)), (1...1024).contains(value) else {
                            toasts.show(L("Health must be a number from 1 to 1024."), kind: .error)
                            return
                        }
                        send(ServerCommand.setMaxHealth(value, target, minecraftVersion: profile.minecraftVersion))
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
            if !list.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(list) { player in
                        HStack(spacing: 6) {
                            Text(verbatim: player.name)
                                .font(Theme.font(size: 13, weight: .medium))
                                .foregroundColor(Theme.text)
                            Button { host.disallow(userID: player.userID, on: profile.instanceName) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(width: 16, height: 16)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(L("Remove"))
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 8)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.elevated))
                        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                    }
                }
                .padding(.vertical, 8)
            }
            if candidates.isEmpty {
                HStack(spacing: 8) {
                    Text(verbatim: L(friends.friendsList.isEmpty ? "No friends to add yet." : "All your friends are already allowed."))
                        .font(Theme.font(size: 13, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    if friends.friendsList.isEmpty {
                        action(L("Open Social")) { app.screen = .social }
                    }
                }
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 8) {
                    Spacer()
                    EmberMenu(label: "Friend", value: L("+ From friends"), minWidth: 160) {
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
                .padding(.vertical, 4)
            }
        }
        .id("allowed")
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

struct ServerWorldTab: View {
    enum Part { case settings, world }

    let part: Part
    let profile: ServerProfile
    let running: Bool
    let onChanged: () -> Void
    let onDeleted: () -> Void
    @EnvironmentObject private var toasts: ToastCenter
    @Local private var newName = ""
    @Local private var autoBackup = false
    @Local private var backupsRequest = 0
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
            await loadBackups()
        }
    }

    private var nameRow: some View {
        row(L("Name")) {
            EmberInput(label: "Server name", text: $newName, width: 220)
            SecondaryPill(title: L("Save"), height: 30) {
                do {
                    try host.library.rename(profile.instanceName, to: newName)
                    onChanged()
                } catch {
                    toasts.show(L("Could not rename the server: %@", error.localizedDescription), kind: .error)
                }
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
            await loadBackups()
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
        Task { await loadBackups() }
    }

    /// Each backup's size is measured by walking its folder, so the list is read off the main thread.
    private func loadBackups() async {
        backupsRequest += 1
        let request = backupsRequest
        let library = host.library
        let name = profile.instanceName
        let found = await Task.detached { library.listBackups(for: name) }.value
        // A slower, older listing must not replace a newer one.
        if request == backupsRequest { backups = found }
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
        do {
            try ServerProperties.update(in: directory, values: values)
            if let max = values["max-players"].flatMap(Int.init) {
                var updated = profile
                updated.maxPlayers = max
                try host.library.save(updated)
            }
        } catch {
            toasts.show(L("Could not save the server settings: %@", error.localizedDescription), kind: .error)
        }
    }
}

// MARK: - Mods

struct ServerModsTab: View {
    let profile: ServerProfile
    let running: Bool
    @EnvironmentObject var app: AppState
    @EnvironmentObject private var toasts: ToastCenter
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
        do {
            try manager().setEnabled(instance: profile.instanceName, fileName: mod.fileName, enabled: enabled)
        } catch {
            toasts.show(L("Could not switch %@: %@", mod.displayTitle, error.localizedDescription), kind: .error)
        }
        reload()
    }
}
