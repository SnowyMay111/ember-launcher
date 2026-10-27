import AppKit
import SwiftUI

private struct DropdownHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Hands back the label's own NSView so its place in the window can be read at the moment of the click.
private struct DropdownProbe: NSViewRepresentable {
    let onCreate: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onCreate(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// The rows of the open list in display order and the one the keyboard (or the mouse) is on.
final class DropdownKeys: ObservableObject {
    @Published var activeID: UUID?
    private var rows: [(id: UUID, y: CGFloat, trigger: () -> Void)] = []

    /// Rows appear in no fixed order, so each one reports where it sits and the keys walk them top to bottom.
    func register(_ id: UUID, y: CGFloat, trigger: @escaping () -> Void) {
        rows.removeAll { $0.id == id }
        rows.append((id, y, trigger))
    }

    func unregister(_ id: UUID) {
        rows.removeAll { $0.id == id }
    }

    func move(_ step: Int) {
        guard !rows.isEmpty else { return }
        let ordered = rows.sorted { $0.y < $1.y }
        let current = ordered.firstIndex { $0.id == activeID }
        let next = current.map { min(max($0 + step, 0), ordered.count - 1) } ?? (step > 0 ? 0 : ordered.count - 1)
        activeID = ordered[next].id
    }

    func triggerActive() {
        rows.first { $0.id == activeID }?.trigger()
    }
}

/// Holds the one open list. RootView owns it and draws `EmberDropdownLayer` above everything, dialogs included.
final class DropdownHost: ObservableObject {
    struct Presented {
        let id = UUID()
        let owner: UUID
        let anchor: CGRect
        let minWidth: CGFloat
        let alignTrailing: Bool
        let content: AnyView
        let keys = DropdownKeys()
    }

    @Published private(set) var presented: Presented?
    private var keyMonitor: Any?

    func present(owner: UUID, anchor: CGRect, minWidth: CGFloat, alignTrailing: Bool, content: AnyView) {
        presented = Presented(owner: owner, anchor: anchor, minWidth: minWidth, alignTrailing: alignTrailing, content: content)
        installKeyMonitor()
    }

    func dismiss() {
        presented = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Escape closes, arrows move through the rows, Return picks the highlighted one.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let keys = self.presented?.keys else { return event }
            switch event.keyCode {
            case 53: self.dismiss()
            case 125: keys.move(1)
            case 126: keys.move(-1)
            case 36, 76: keys.triggerActive()
            default: return event
            }
            return nil
        }
    }
}

/// A label that opens our own list instead of the system menu. The content is plain Buttons, Dividers and Text.
struct EmberDropdown<Label: View, Content: View>: View {
    let minWidth: CGFloat?
    let alignTrailing: Bool
    let content: () -> Content
    let label: (_ isOpen: Bool) -> Label

    @EnvironmentObject private var host: DropdownHost
    @Environment(\.isEnabled) private var isEnabled
    @Local private var owner = UUID()
    @Local private var probe: NSView?

    init(minWidth: CGFloat? = nil, alignTrailing: Bool = false,
         @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder label: @escaping (_ isOpen: Bool) -> Label) {
        self.minWidth = minWidth
        self.alignTrailing = alignTrailing
        self.content = content
        self.label = label
    }

    private var isOpen: Bool { host.presented?.owner == owner }

    var body: some View {
        Button(action: toggle) {
            label(isOpen)
        }
        .buttonStyle(.plain)
        .background(DropdownProbe { probe = $0 }.allowsHitTesting(false))
        .opacity(isEnabled ? 1 : 0.5)
        .onDisappear { if isOpen { host.dismiss() } }
    }

    /// The label's frame in the window's top-left coordinates, which is also where the layer is drawn.
    private func labelFrame() -> CGRect {
        guard let view = probe, let content = view.window?.contentView else { return .zero }
        let frame = content.convert(view.bounds, from: view)
        return CGRect(x: frame.minX, y: content.isFlipped ? frame.minY : content.bounds.height - frame.maxY,
                      width: frame.width, height: frame.height)
    }

    private func toggle() {
        guard isEnabled else { return }
        if isOpen {
            host.dismiss()
        } else {
            host.present(owner: owner, anchor: labelFrame(), minWidth: minWidth ?? 0,
                         alignTrailing: alignTrailing, content: AnyView(content()))
        }
    }
}

/// Put in an overlay above the dialogs: draws the open list and closes it on a click outside.
struct EmberDropdownLayer: View {
    @EnvironmentObject private var host: DropdownHost

    var body: some View {
        ZStack {
            if let presented = host.presented {
                DropdownCard(presented: presented).id(presented.id)
            }
        }
        .ignoresSafeArea()
    }
}

private struct DropdownCard: View {
    let presented: DropdownHost.Presented

    @EnvironmentObject private var host: DropdownHost
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Local private var appeared = false
    @Local private var rowsHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            // The layer ignores the safe area, the anchor was measured inside it: shift by the difference.
            let origin = geo.frame(in: .global).origin
            let anchor = presented.anchor.offsetBy(dx: -origin.x, dy: -origin.y)
            let width = max(anchor.width, presented.minWidth)
            let rawX = presented.alignTrailing ? anchor.maxX - width : anchor.minX
            let x = min(max(rawX, 12), max(12, geo.size.width - width - 12))
            let below = geo.size.height - anchor.maxY - 18
            let above = anchor.minY - 18
            let opensUp = below < 200 && above > below
            let cap = min(320, max(opensUp ? above : below, 80))

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { host.dismiss() }

                VStack(alignment: .leading, spacing: 0) {
                    if opensUp {
                        Spacer(minLength: 0)
                    } else {
                        Color.clear.frame(height: anchor.maxY + 6)
                    }
                    list(width: width, cap: cap, opensUp: opensUp)
                    if opensUp {
                        Color.clear.frame(height: geo.size.height - anchor.minY + 6)
                    } else {
                        Spacer(minLength: 0)
                    }
                }
                .padding(.leading, x)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) { appeared = true }
        }
    }

    private func list(width: CGFloat, cap: CGFloat, opensUp: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let rows = VStack(alignment: .leading, spacing: 2) {
            presented.content
        }
        .padding(6)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: DropdownHeightKey.self, value: proxy.size.height)
            }
        )
        // Short lists hug their rows; once they measure taller than the cap they scroll inside it.
        return Group {
            if rowsHeight > cap {
                ScrollView { rows }.frame(height: cap)
            } else {
                rows
            }
        }
        .onPreferenceChange(DropdownHeightKey.self) { rowsHeight = max(rowsHeight, $0) }
        .frame(width: width)
        .buttonStyle(DropdownRowStyle())
        .environmentObject(presented.keys)
        .environment(\.colorScheme, .dark)
        .background(shape.fill(Theme.surface))
        .overlay(shape.strokeBorder(Theme.line, lineWidth: 1))
        .clipShape(shape)
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        .scaleEffect(appeared ? 1 : 0.97, anchor: opensUp ? .bottom : .top)
        .opacity(appeared ? 1 : 0)
    }
}

private struct DropdownRowStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DropdownRow(configuration: configuration)
    }
}

/// One row: Ember highlight on hover or keyboard focus, closes the list after its action ran.
private struct DropdownRow: View {
    let configuration: PrimitiveButtonStyleConfiguration

    @EnvironmentObject private var host: DropdownHost
    @EnvironmentObject private var keys: DropdownKeys
    @Environment(\.isEnabled) private var isEnabled
    @Local private var rowID = UUID()

    var body: some View {
        configuration.label
            .font(Theme.font(size: 14, weight: .regular))
            .foregroundColor(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.ember.opacity(keys.activeID == rowID ? 0.14 : 0))
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { inside in
                if inside {
                    keys.activeID = rowID
                } else if keys.activeID == rowID {
                    keys.activeID = nil
                }
            }
            .onTapGesture(perform: run)
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        keys.register(rowID, y: proxy.frame(in: .global).minY, trigger: run)
                    }
                }
            )
            .onDisappear { keys.unregister(rowID) }
    }

    private func run() {
        guard isEnabled else { return }
        configuration.trigger()
        host.dismiss()
    }
}
