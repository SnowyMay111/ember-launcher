import SwiftUI
import AppKit

/// Provides a draggable area for the window without using `isMovableByWindowBackground`.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No dynamic updates needed.
    }

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override var isOpaque: Bool { false }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
