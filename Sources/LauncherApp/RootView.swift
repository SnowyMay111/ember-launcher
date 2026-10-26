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
        .environmentObject(app)
        .environmentObject(settings)
        .environmentObject(player)
        .background(WindowConfigurator())
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(.dark)
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
