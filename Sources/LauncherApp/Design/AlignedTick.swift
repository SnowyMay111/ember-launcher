import SwiftUI
import AppKit

/// Decorative animations share one aligned tick so the window is redrawn once per tick.
/// Every tick is a whole multiple of 1/15 s counted from the reference date, so layers with
/// `every: 1` (15 fps), `every: 2` (7.5 fps) and `every: 3` (5 fps) land on the same instants.
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
    private var viewers = 0
    private var isVisible = true

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeOcclusionStateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isVisible = NSApp.occlusionState.contains(.visible)
                self?.refresh()
            }
        }
    }

    func source(every: Int) -> Source {
        let step = max(every, 1)
        if let source = sources[step] { return source }
        let source = Source()
        sources[step] = source
        return source
    }

    func retain() { viewers += 1; refresh() }
    func release() { viewers = max(viewers - 1, 0); refresh() }

    private func refresh() {
        let shouldRun = viewers > 0 && isVisible
        if shouldRun, timer == nil {
            let timer = Timer(timeInterval: 1 / AlignedTick.baseFramesPerSecond, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else if !shouldRun, let timer {
            timer.invalidate()
            self.timer = nil
        }
    }

    private func tick() {
        let base = AlignedTick.baseFramesPerSecond
        let frame = Int((Date().timeIntervalSinceReferenceDate * base).rounded())
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
