import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var app = AppState()
    @StateObject private var settings: SettingsStore
    @StateObject private var player = PlayController()
    @StateObject private var updates: UpdateController
    @StateObject private var toasts = ToastCenter()
    @StateObject private var dropdowns = DropdownHost()

    init() {
        let settings = SettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _updates = StateObject(wrappedValue: UpdateController(settings: settings))
    }

    var body: some View {
        ZStack {
            AmbientBackdrop()

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    SidebarNavigation(compact: proxy.size.width < 760)

                    VStack(spacing: 0) {
                        TopBar()

                        ZStack(alignment: .top) {
                            screen
                                .frame(maxWidth: app.screen == .play || app.screen == .library ? .infinity : 1120)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .overlay(alignment: .top) { UpdateNotice() }
                        .overlay(alignment: .bottom) { ToastHost() }
                    }
                }
                .environment(\.windowWidth, proxy.size.width)
            }
        }
        .ignoresSafeArea()
        .overlay {
            modalLayer
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: app.modal != nil)
        }
        .overlay {
            if app.friendsDrawerOpen {
                FriendsDrawer()
            }
        }
        .overlay { EmberDropdownLayer() }
        .environmentObject(app)
        .environmentObject(settings)
        .environmentObject(player)
        .environmentObject(updates)
        .environmentObject(toasts)
        .environmentObject(dropdowns)
        .environment(\.backgroundAnimations, settings.backgroundAnimations)
        .onAppear { updates.start() }
        .onChange(of: player.isBusy) { _, busy in updates.gameIsBusy = busy }
        .onChange(of: settings.autoUpdate) { _, isOn in
            if isOn { updates.autoUpdateEnabled() }
        }
        .background(WindowConfigurator())
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(.dark)
    }

    /// Dialog over a dimmed backdrop; the backdrop also stops clicks reaching the screen below.
    @ViewBuilder private var modalLayer: some View {
        if let modal = app.modal {
            ZStack {
                Color.black.opacity(0.62)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {}
                switch modal {
                case .newInstance:
                    NewInstanceModal()
                case .instanceSettings(let name):
                    if let instance = app.instances.first(where: { $0.id == name }) {
                        InstanceSettingsModal(instance: instance).id(name)
                    }
                case .optimize(let name):
                    if let instance = app.instances.first(where: { $0.id == name }) {
                        OptimizationModal(instance: instance).id(name)
                    }
                case .changeVersion(let name):
                    if let instance = app.instances.first(where: { $0.id == name }) {
                        VersionModal(instance: instance).id(name)
                    }
                case .sessionHealth(let name):
                    if let instance = app.instances.first(where: { $0.id == name }) {
                        SessionDiagnosticsView(instance: instance).id(name)
                    }
                case .gameLog(let name):
                    GameLogModal(name: name).id(name)
                case .allVersions:
                    AllVersionsModal()
                case .profile:
                    ProfilePanel()
                case .modProject(let hit):
                    if let mods = app.activeMods {
                        ModDetailPanel(hit: hit, mods: mods).id(hit.projectId)
                    }
                case .instanceDetails(let name):
                    if let instance = app.instances.first(where: { $0.id == name }) {
                        InstanceDetailPanel(instance: instance).id(name)
                    }
                case .lobby:
                    LobbyFlowModal()
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder private var screen: some View {
        switch app.screen {
        case .play: HomeScreen()
        case .library: LibraryScreen()
        case .social: SocialScreen()
        case .settings: SettingsScreen()
        case .mods: ModsScreen(app: app)
        case .skins: SkinsScreen()
        }
    }
}
