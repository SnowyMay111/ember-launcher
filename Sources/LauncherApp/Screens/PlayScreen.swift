import SwiftUI

struct PlayScreen: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayController

    private var playTitle: String {
        switch player.state {
        case .idle, .failed: return "Play"
        case .preparing: return "Starting…"
        case .running: return "Playing"
        }
    }

    private var statusText: String {
        switch player.state {
        case .preparing(let text), .failed(let text): return text
        case .idle, .running: return ""
        }
    }

    private static let statusStyle = Theme.TextStyle(size: 13, weight: .regular, color: Theme.muted)

    /// One line under the buttons: progress or the error; while the game runs, how long this run has lasted.
    @ViewBuilder private var status: some View {
        if let since = player.runningSince {
            TimelineView(.periodic(from: since, by: 30)) { context in
                statusLine(L("In game · %d min", max(0, Int(context.date.timeIntervalSince(since)) / 60)))
            }
        } else {
            statusLine(statusText)
        }
    }

    private func statusLine(_ text: String) -> some View {
        Text(verbatim: text)
            .style(Self.statusStyle)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: 560, minHeight: 18)
    }

    var body: some View {
        if let item = app.current {
            VStack(spacing: 0) {
                CubeIcon()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.white.opacity(0.4), radius: 22)
                    .accessibilityHidden(true)

                Text(verbatim: L("Last played") + " · " + item.lastPlayedAgo)
                    .style(.eyebrow)
                    .padding(.top, 26)

                VStack(spacing: -12) {
                    Text(verbatim: item.name).style(.hero)
                    GradientText(
                        text: item.versionLine,
                        style: .hero,
                        gradient: LinearGradient(colors: [Color(white: 0.878), Theme.muted], startPoint: .top, endPoint: .bottom)
                    )
                }
                .padding(.top, 14)

                Text(verbatim: L("%d mods · %@ played", item.modCount, item.playtimeText))
                    .style(.body16)
                    .padding(.top, 14)

                HStack(spacing: 12) {
                    PrimaryPill(title: playTitle, showsPlay: !player.isBusy, isDisabled: player.isBusy) {
                        player.play(item, settings: settings, app: app)
                    }
                    VersionMenu(item: item)
                    SecondaryPill(title: "Instance settings") { app.modal = .instanceSettings(item.name) }
                    SecondaryPill(title: "Logs") { app.modal = .gameLog(item.name) }
                    if player.hasReport(for: item.name) {
                        SecondaryPill(title: "Health") { app.modal = .sessionHealth(item.name) }
                    }
                }
                .padding(.top, 26)

                VStack(spacing: 12) {
                    status
                    if case .failed = player.state, player.diagnosisInstance == item.name {
                        SecondaryPill(title: "Crash report") { app.modal = .gameLog(item.name) }
                    }
                }
                .padding(.top, 14)

                Spacer(minLength: 24)

                HStack(spacing: 12) {
                    StatCard(label: "Mods", value: "\(item.modCount)")
                    StatCard(label: "Playtime", value: item.playtimeText)
                    StatCard(label: "Memory", value: item.memoryText)
                }
                .frame(maxWidth: 880)
            }
            .padding(.top, 36)
            .padding(.bottom, 28)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
            .task(id: item.name) {
                player.loadLastReport(for: item.name)
            }
        } else {
            emptyState
        }
    }

    /// First launch: nothing to play yet.
    private var emptyState: some View {
        VStack(spacing: 0) {
            CubeIcon()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                .frame(width: 80, height: 80)
                .shadow(color: Color.white.opacity(0.4), radius: 22)
                .accessibilityHidden(true)
            Text(tr: "No instances yet").style(.pageTitle).padding(.top, 26)
            Text(tr: "Create your first instance, or start with the latest release.").style(.body16).padding(.top, 14)
            HStack(spacing: 12) {
                PrimaryPill(title: "New instance") { app.modal = .newInstance }
                SecondaryPill(title: "Start with latest release") {
                    app.useLatest(snapshot: false, memoryMB: Int(settings.memoryGB) * 1024)
                }
            }
            .padding(.top, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

/// Quick switch next to Play: the latest release or snapshot, or any instance.
private struct VersionMenu: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayController
    let item: LibraryInstance

    var body: some View {
        VoxelMenu(label: "Version", value: item.minecraftVersion, isPill: true) {
            if let latest = app.manifest?.latest {
                Button(L("Latest release") + " · " + latest.release) { use(snapshot: false) }
                Button(L("Latest snapshot") + " · " + latest.snapshot) { use(snapshot: true) }
            } else {
                Text(tr: "Version list unavailable")
            }
            Divider()
            ForEach(app.instances) { instance in
                Button((instance.id == item.id ? "✓ " : "") + instance.name) { app.currentID = instance.id }
            }
        }
        .disabled(player.isBusy)
    }

    private func use(snapshot: Bool) {
        app.useLatest(snapshot: snapshot, memoryMB: Int(settings.memoryGB) * 1024)
    }
}
