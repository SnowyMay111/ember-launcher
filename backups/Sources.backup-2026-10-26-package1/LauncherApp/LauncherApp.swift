import SwiftUI
import AppKit
import LauncherCore

@main
struct LauncherApp: App {
    init() {
        FontLoader.registerAll()
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 720)
        .windowResizability(.contentMinSize)
    }
}
