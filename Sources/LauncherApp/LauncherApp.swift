import SwiftUI
import AppKit
import LauncherCore

@main
struct LauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage(SettingsStore.serverMenuBarKey) private var serverMenuBar = false

    init() {
        FontLoader.registerAll()
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 720)
        .windowResizability(.contentMinSize)

        MenuBarExtra(isInserted: $serverMenuBar) {
            ServerMenuBarContent()
        } label: {
            ServerMenuBarLabel()
        }
    }
}

/// Quitting stops a hosted server, so ask first while one is running.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let host = LobbyHostController.shared
        guard host.runningInstance != nil else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = L("Stop the server and quit?")
        alert.informativeText = host.players.isEmpty
            ? L("The server is running and will be stopped.")
            : L("The server is running with %d players online. They will be disconnected.", host.players.count)
        alert.addButton(withTitle: L("Stop and quit"))
        alert.addButton(withTitle: L("Cancel"))
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

private struct ServerMenuBarLabel: View {
    @ObservedObject private var host = LobbyHostController.shared

    var body: some View {
        Image(systemName: host.runningInstance == nil ? "flame" : "flame.fill")
    }
}

private struct ServerMenuBarContent: View {
    @ObservedObject private var host = LobbyHostController.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let name = host.runningInstance {
            Text(L("Server running: %@", name))
            Text(L("%d players online", host.players.count))
            Divider()
            Button(L("Stop server")) { host.close() }
        } else {
            Text(L("No server running"))
        }
        Divider()
        Button(L("Open Ember")) { showWindow() }
        Button(L("Quit Ember")) { NSApp.terminate(nil) }
    }

    private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}
