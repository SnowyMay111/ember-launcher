import SwiftUI
import Combine
import LauncherCore

struct HomeScreen: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var player: PlayController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Local private var memoryIndex: Int = 0
    @Local private var timer = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()
    
    private var currentItem: LibraryInstance? {
        app.current
    }
    
    private var heroKind: HeroScene.Kind {
        guard let item = currentItem else { return .world }
        let version = item.minecraftVersion
        let isSnapshot = !(version.range(of: #"^\d+\.\d+(\.\d+)?$"#, options: .regularExpression) != nil)
        if isSnapshot {
            return .abstract
        } else if item.loader != .vanilla && item.modCount > 0 {
            return .carousel
        } else if UserDefaults.standard.string(forKey: "equippedSkinID") != nil && item.loader == .vanilla {
            return .player
        } else {
            return .world
        }
    }
    
    private var heroTitle: String {
        switch heroKind {
        case .world: "THE QUIET\nWILDERNESS"
        case .player: "YOUR STORY,\nYOUR SKIN"
        case .carousel: "PLACES YOU\nREMEMBER"
        case .abstract: "A STRANGE NEW\nBEGINNING"
        }
    }
    
    private var heroCopy: String {
        switch heroKind {
        case .world: "Your favorite world is warm, quiet, and ready for you."
        case .player: "A familiar face returns to a world still waiting."
        case .carousel: "Every world leaves a little light behind."
        case .abstract: "Experimental worlds deserve a little mystery."
        }
    }
    
    private var eyebrow: String {
        guard let item = currentItem else { return "" }
        return L("Last played") + " · " + item.lastPlayedAgo
    }
    
    private var instanceName: String {
        currentItem?.name ?? ""
    }
    
    private var playtime: String {
        currentItem?.playtimeText ?? ""
    }
    
    private var loaderString: String {
        guard let item = currentItem else { return "" }
        return item.loader == .vanilla ? "Vanilla" : "\(item.loader.rawValue) · \(item.modCount) mods"
    }
    
    private var versionName: String {
        guard let item = currentItem else { return "" }
        let base = item.loader == .vanilla ? "Minecraft" : item.loader.rawValue
        return "\(base) \(item.minecraftVersion)"
    }
    
    private var launchState: HomeLaunchPlayState {
        switch player.state {
        case .idle, .failed: .idle
        case .preparing: .launching
        case .running: .ready
        }
    }
    
    private var playTitle: String {
        switch player.state {
        case .idle, .failed: L("Play")
        case .preparing: L("Preparing")
        case .running: L("Playing")
        }
    }
    
    private var playSubtitle: String {
        switch player.state {
        case .idle, .failed: instanceName
        case .preparing(let text): text
        case .running: L("In game")
        }
    }
    
    private var isLaunchDisabled: Bool {
        player.isBusy
    }
    
    private var statusText: String {
        switch player.state {
        case .preparing(let text), .failed(let text):
            text
        default:
            ""
        }
    }
    
    @ViewBuilder private var statusView: some View {
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
            .font(Theme.font(size: 13, weight: .regular, mono: false))
            .foregroundColor(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: 560, minHeight: 18)
    }
    
    @ViewBuilder private func versionMenuContent(for item: LibraryInstance) -> some View {
        // List all instances
        ForEach(app.instances) { instance in
            Button {
                app.currentID = instance.id
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: instance.name)
                            .font(Theme.font(size: 14, weight: .regular, mono: false))
                            .lineLimit(1)
                        Text(verbatim: "\(instance.loader.rawValue) \(instance.minecraftVersion)")
                            .font(Theme.font(size: 12, weight: .regular, mono: false))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer(minLength: 12)
                    if instance.id == item.id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.ember)
                    }
                }
            }
        }
        Divider()
        Button {
            app.modal = .newInstance
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.ember)
                Text(tr: "New instance")
            }
        }
    }
    
    private func use(snapshot: Bool) {
        app.useLatest(snapshot: snapshot, memoryMB: Int(settings.memoryGB) * 1024)
    }
    
    var body: some View {
        Group {
            if let item = currentItem {
                GeometryReader { geo in
                    let width = min(1120, geo.size.width - 56)
                    let topPad = max(34, min(72, 0.06 * (geo.size.height + 116)))
                    ScrollView {
                        VStack(spacing: 0) {
                            HomeHeroCard(
                                kind: heroKind,
                                memoryIndex: memoryIndex,
                                skin: nil,
                                eyebrow: eyebrow,
                                title: heroTitle,
                                copy: heroCopy,
                                instance: instanceName,
                                loader: loaderString,
                                playtime: playtime,
                                viewport: geo.size.width + 84
                            )
                            .frame(width: width)
                            
                            Spacer().frame(height: 18)
                            
                            HomeLaunchPanel(
                                versionName: versionName,
                                playState: launchState,
                                playTitle: playTitle,
                                playSubtitle: playSubtitle,
                                isDisabled: isLaunchDisabled,
                                onPlay: { player.play(item, settings: settings, app: app) },
                                onSettings: { app.modal = .instanceSettings(item.name) },
                                versionMenu: { versionMenuContent(for: item) }
                            )
                            .frame(width: width)
                            
                            if !statusText.isEmpty || player.hasReport(for: item.name) {
                                Spacer().frame(height: 14)
                                HStack(spacing: 12) {
                                    statusView
                                    if player.hasReport(for: item.name) {
                                        SecondaryPill(title: "Health") { app.modal = .sessionHealth(item.name) }
                                    }
                                    if case .failed = player.state, player.diagnosisInstance == item.name {
                                        SecondaryPill(title: "Crash report") { app.modal = .gameLog(item.name) }
                                    }
                                }
                                .frame(maxWidth: width)
                            }
                            
                        }
                        .padding(.top, topPad)
                        .frame(maxWidth: .infinity)
                    }
                }
                .task(id: item.name) {
                    player.loadLastReport(for: item.name)
                }
                .onReceive(timer) { _ in
                    guard heroKind == .carousel, !reduceMotion else { return }
                    memoryIndex = (memoryIndex + 1) % 3
                }
                .onChange(of: item.id) {
                    memoryIndex = 0
                }
            } else {
                emptyState
            }
        }
    }
    
    private var footer: some View {
        HStack {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color(red: 0x6f/255, green: 0x80/255, blue: 0x55/255))
                    .frame(width: 5, height: 5)
                    .shadow(color: Color(red: 0x6f/255, green: 0x80/255, blue: 0x55/255, opacity: 0.5), radius: 8)
                Text(verbatim: L("All systems operational"))
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Color(red: 0x55/255, green: 0x52/255, blue: 0x4d/255))
            }
            Spacer()
            Text(verbatim: "Ember Launcher · \(LauncherInfo.version)")
                .font(Theme.font(size: 12, weight: .regular))
                .foregroundColor(Color(red: 0x55/255, green: 0x52/255, blue: 0x4d/255))
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 0) {
            CubeIcon()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                .frame(width: 80, height: 80)
                .shadow(color: Color.white.opacity(0.4), radius: 22)
                .accessibilityHidden(true)
            Text(tr: "No instances yet")
                .font(Theme.font(size: 24, weight: .bold, mono: false))
                .padding(.top, 26)
            Text(tr: "Create your first instance, or start with the latest release.")
                .font(Theme.font(size: 16, weight: .regular, mono: false))
                .padding(.top, 14)
            HStack(spacing: 12) {
                PrimaryPill(title: "New instance") { app.modal = .newInstance }
                SecondaryPill(title: "Start with latest release") {
                    app.useLatest(snapshot: false, memoryMB: Int(settings.memoryGB) * 1024)
                }
                SecondaryPill(title: "All versions") { app.modal = .allVersions }
            }
            .padding(.top, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

private struct VersionMenu: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayController
    let item: LibraryInstance
    
    var body: some View {
        EmberMenu(label: "Version", value: item.minecraftVersion, isPill: true) {
            if let latest = app.manifest?.latest {
                Button(L("Latest release") + " · " + latest.release) { use(snapshot: false) }
                Button(L("Latest snapshot") + " · " + latest.snapshot) { use(snapshot: true) }
            } else {
                Text(tr: "Version list unavailable")
            }
            Divider()
            Button(L("All versions…")) { app.modal = .allVersions }
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