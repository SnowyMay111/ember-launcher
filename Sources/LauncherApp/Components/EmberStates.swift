import SwiftUI

// MARK: - Empty State

/// Centered, calm state view for empty collections, missing search results, offline states, and errors.
struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.elevated)
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
                Image(systemName: systemImage)
                    .font(Theme.font(size: 28, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            VStack(spacing: Theme.Space.xs) {
                Text(verbatim: title)
                    .style(Theme.TextStyle.cardTitle)
                    .multilineTextAlignment(.center)
                Text(verbatim: message)
                    .style(Theme.TextStyle.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 360)

            if let actionTitle = actionTitle, let action = action {
                PrimaryPill(title: actionTitle, action: action)
                    .padding(.top, Theme.Space.xs)
            }
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Progress State

/// Progress indicator with Ember gradient fill, indeterminate shimmer, and mono caption metrics.
struct ProgressState: View {
    let title: String
    let detail: String?
    let progress: Double?
    let eta: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Local private var isShimmering = false

    init(
        title: String,
        detail: String? = nil,
        progress: Double? = nil,
        eta: String? = nil
    ) {
        self.title = title
        self.detail = detail
        self.progress = progress
        self.eta = eta
    }

    private var percentString: String {
        guard let progress = progress else { return "" }
        let clamped = max(0.0, min(1.0, progress))
        let percent = Int((clamped * 100.0).rounded())
        return "\(percent)%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack {
                    Text(verbatim: title)
                        .style(Theme.TextStyle.cardTitle)
                    Spacer()
                }
                if let detail = detail {
                    Text(verbatim: detail)
                        .style(Theme.TextStyle.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.elevated)
                        .overlay(Capsule().strokeBorder(Theme.border.opacity(0.5), lineWidth: 0.5))

                    if let progress = progress {
                        let clamped = max(0.0, min(1.0, progress))
                        Capsule()
                            .fill(Theme.emberGradient)
                            .frame(width: geo.size.width * clamped)
                    } else {
                        if reduceMotion {
                            Capsule()
                                .fill(Theme.emberGradient)
                                .frame(width: geo.size.width)
                                .opacity(0.65)
                        } else {
                            let barWidth = max(36.0, geo.size.width * 0.35)
                            Capsule()
                                .fill(Theme.emberGradient)
                                .frame(width: barWidth)
                                .offset(x: isShimmering ? (geo.size.width - barWidth) : 0)
                                .animation(
                                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                    value: isShimmering
                                )
                        }
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)

            if progress != nil || eta != nil {
                HStack {
                    if progress != nil {
                        Text(verbatim: percentString)
                            .style(.init(size: 11, weight: .medium, mono: true, color: Theme.textSecondary))
                    }
                    Spacer()
                    if let eta = eta {
                        Text(verbatim: eta)
                            .style(.init(size: 11, weight: .medium, mono: true, color: Theme.textMuted))
                    }
                }
            }
        }
        .onAppear {
            if !reduceMotion && progress == nil {
                isShimmering = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(percentString)
    }
}

// MARK: - Toast System

/// Semantic toast variants for feedback banners.
enum ToastKind: Equatable, Sendable {
    case success
    case error
    case info
}

/// A lightweight toast notification payload.
struct ToastMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let kind: ToastKind

    init(id: UUID = UUID(), text: String, kind: ToastKind = .info) {
        self.id = id
        self.text = text
        self.kind = kind
    }
}

/// Central state manager for transient toast messages.
@MainActor
final class ToastCenter: ObservableObject {
    @Published var current: ToastMessage?

    private var dismissTask: Task<Void, Never>?

    func show(_ text: String, kind: ToastKind = .info) {
        dismissTask?.cancel()
        current = ToastMessage(text: text, kind: kind)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
    }
}

private struct ToastMoveModifier: ViewModifier {
    let offset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(opacity)
    }
}

/// Host overlay view rendering the current toast pill at bottom center without blocking outer clicks.
struct ToastHost: View {
    @EnvironmentObject var toasts: ToastCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {}

    private var toastTransition: AnyTransition {
        if reduceMotion {
            return .asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.22)),
                removal: .opacity.animation(.easeIn(duration: 0.18))
            )
        } else {
            return .asymmetric(
                insertion: .modifier(
                    active: ToastMoveModifier(offset: 12, opacity: 0),
                    identity: ToastMoveModifier(offset: 0, opacity: 1)
                ).animation(.easeOut(duration: 0.22)),
                removal: .modifier(
                    active: ToastMoveModifier(offset: 8, opacity: 0),
                    identity: ToastMoveModifier(offset: 0, opacity: 1)
                ).animation(.easeIn(duration: 0.18))
            )
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let toast = toasts.current {
                toastCapsule(toast)
                    .transition(toastTransition)
                    .padding(.bottom, Theme.Space.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private func toastCapsule(_ toast: ToastMessage) -> some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: iconName(for: toast.kind))
                .font(Theme.font(size: 14, weight: .semibold))
                .foregroundColor(iconColor(for: toast.kind))
                .accessibilityHidden(true)

            Text(verbatim: toast.text)
                .style(Theme.TextStyle.body16)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
        .background(Capsule().fill(Theme.elevated))
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
        .contentShape(Capsule())
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLabel(toast.text)
    }

    private func iconName(for kind: ToastKind) -> String {
        switch kind {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private func iconColor(for kind: ToastKind) -> Color {
        switch kind {
        case .success:
            return Theme.success
        case .error:
            return Theme.danger
        case .info:
            return Theme.violet
        }
    }
}
