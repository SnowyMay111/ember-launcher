import SwiftUI

struct RootView: View {
    @StateObject private var app = AppState()
    @StateObject private var settings = SettingsStore()
    @StateObject private var player = PlayController()

    var body: some View {
        ZStack {
            Theme.bg

            VStack(spacing: 0) {
                TopBar()

                ZStack {
                    Glow(app.screen == .play ? .play : .page)
                    screen
                }
            }
        }
        .ignoresSafeArea()
        .overlay { modalLayer }
        .environmentObject(app)
        .environmentObject(settings)
        .environmentObject(player)
        .background(WindowConfigurator())
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(.dark)
    }

    /// Dialog over a dimmed backdrop; the backdrop also stops clicks reaching the screen below.
    @ViewBuilder private var modalLayer: some View {
        if let modal = app.modal {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
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
                case .gameLog(let name):
                    GameLogModal(name: name).id(name)
                }
            }
        }
    }

    @ViewBuilder private var screen: some View {
        switch app.screen {
        case .play: PlayScreen()
        case .library: LibraryScreen()
        case .settings: SettingsScreen()
        case .mods: ComingSoonScreen(title: "Mods")
        case .skins: ComingSoonScreen(title: "Skins")
        }
    }
}
