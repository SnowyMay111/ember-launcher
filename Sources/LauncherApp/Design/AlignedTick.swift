import SwiftUI
import AppKit

/// Decorative animations share one aligned tick so the window is redrawn once per tick.
/// Every tick is a whole multiple of 1/30 s counted from the reference date, so layers with
/// `every: 3` (10 fps) and `every: 6` (5 fps) land on the same instants.
struct AlignedTick: TimelineSchedule {
    static let baseFramesPerSecond: Double = 30
    var every: Int = 1
    var paused: Bool = false

    typealias Entries = AnySequence<Date>

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        if paused {
            // Single entry to render once and then stop updating.
            return AnySequence([startDate])
        }
        let step = max(every, 1)
        let base = Self.baseFramesPerSecond
        let first = Int((startDate.timeIntervalSinceReferenceDate * base / Double(step)).rounded(.up))
        // Integer tick numbers keep dates identical across views, so there is no drift between them.
        return AnySequence((first...).lazy.map { Date(timeIntervalSinceReferenceDate: Double($0 * step) / base) })
    }
}

/// One timer for all decorative animations. `TimelineView` stops while a system menu, a dialog or an
/// open/save panel is on screen (the main run loop leaves its default mode), so the ticks come from a timer
/// in the common modes instead. It runs only while a `TickView` is on screen and the app is visible.
@MainActor
final class TickClock {
    static let shared = TickClock()

    final class Source: ObservableObject {
        @Published fileprivate(set) var date = Date()
        fileprivate var index = Int.min
    }

    private var sources: [Int: Source] = [:]
    private var timer: Timer?
    private var timerStep = 0
    private var viewers = 0
    private var isVisible = true
    private var isActive = NSApplication.shared.isActive
    /// True while Minecraft is running: the launcher sits behind the game, so it stops drawing.
    var gameRunning = false {
        didSet { if gameRunning != oldValue { refresh() } }
    }

    private init() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: NSApplication.didChangeOcclusionStateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isVisible = NSApp.occlusionState.contains(.visible)
                self?.refresh()
            }
        }
        // Another app in front: the animations freeze on their last frame until Ember is active again.
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.isActive = NSApp.isActive
                    self?.refresh()
                }
            }
        }
    }

    func source(every: Int) -> Source {
        let step = max(every, 1)
        if let source = sources[step] { return source }
        let source = Source()
        sources[step] = source
        refresh()
        return source
    }

    func retain() { viewers += 1; refresh() }
    func release() { viewers = max(viewers - 1, 0); refresh() }

    private func refresh() {
        let step = sources.keys.min() ?? 1
        let shouldRun = viewers > 0 && isVisible && isActive && !gameRunning
        if let timer, !shouldRun || step != timerStep {
            timer.invalidate()
            self.timer = nil
        }
        guard shouldRun, timer == nil else { return }

        // One fire per frame of the fastest layer, aimed at the middle of that frame, so a fire that comes
        // a little early or late still lands in the right frame.
        let interval = Double(step) / AlignedTick.baseFramesPerSecond
        let now = Date().timeIntervalSinceReferenceDate
        let first = ((now / interval).rounded(.down) + 1.5) * interval
        let timer = Timer(
            fire: Date(timeIntervalSinceReferenceDate: first), interval: interval, repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = interval / 4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        timerStep = step
    }

    private func tick() {
        let base = AlignedTick.baseFramesPerSecond
        let frame = Int((Date().timeIntervalSinceReferenceDate * base).rounded(.down))
        for (step, source) in sources where frame / step != source.index {
            source.index = frame / step
            source.date = Date(timeIntervalSinceReferenceDate: Double(source.index * step) / base)
        }
    }
}

/// Drop-in for `TimelineView(AlignedTick(every:paused:))` that keeps running while menus and panels are open.
struct TickView<Content: View>: View {
    var every: Int = 1
    var paused = false
    @ViewBuilder var content: (Date) -> Content

    var body: some View {
        if paused {
            content(Date())
        } else {
            Running(source: TickClock.shared.source(every: every), content: content)
        }
    }

    private struct Running: View {
        @ObservedObject var source: TickClock.Source
        let content: (Date) -> Content

        var body: some View {
            content(source.date)
                .onAppear { TickClock.shared.retain() }
                .onDisappear { TickClock.shared.release() }
        }
    }
}
