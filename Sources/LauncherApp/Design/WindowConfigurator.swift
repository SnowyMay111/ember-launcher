import SwiftUI
import AppKit

final class WindowConfiguratorView: NSView {
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
        setupObservers()
    }

    private func setupObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()

        guard let window = self.window else { return }

        let names: [Notification.Name] = [
            NSWindow.didResizeNotification,
            NSWindow.didEndLiveResizeNotification,
            NSWindow.didExitFullScreenNotification
        ]

        for name in names {
            let obs = NotificationCenter.default.addObserver(
                forName: name,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.configureWindow()
            }
            observers.append(obs)
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func configureWindow() {
        guard let window = self.window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = .black
        window.isOpaque = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.isMovableByWindowBackground = true

        adjustTrafficLights(in: window)
        DispatchQueue.main.async { [weak self, weak window] in
            guard let window = window else { return }
            self?.adjustTrafficLights(in: window)
        }
    }

    private func adjustTrafficLights(in window: NSWindow) {
        guard let close = window.standardWindowButton(.closeButton),
              let superview = close.superview else { return }

        let mini = window.standardWindowButton(.miniaturizeButton)
        let zoom = window.standardWindowButton(.zoomButton)

        let nativeSpacing1 = (mini?.frame.minX ?? 0) - close.frame.minX
        let nativeSpacing2 = (zoom?.frame.minX ?? 0) - close.frame.minX
        let delta1 = nativeSpacing1 > 0 ? nativeSpacing1 : 20.0
        let delta2 = nativeSpacing2 > delta1 ? nativeSpacing2 : 40.0

        let windowHeight = window.frame.height
        let targetPointInWindow = NSPoint(x: 20, y: windowHeight - 28)
        let localCenter = superview.convert(targetPointInWindow, from: nil)

        close.setFrameOrigin(NSPoint(x: localCenter.x, y: localCenter.y - close.frame.height / 2))
        mini?.setFrameOrigin(NSPoint(x: localCenter.x + delta1, y: localCenter.y - (mini?.frame.height ?? 0) / 2))
        zoom?.setFrameOrigin(NSPoint(x: localCenter.x + delta2, y: localCenter.y - (zoom?.frame.height ?? 0) / 2))
    }
}

public struct WindowConfigurator: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        WindowConfiguratorView()
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        if let configView = nsView as? WindowConfiguratorView {
            configView.configureWindow()
        }
    }
}
