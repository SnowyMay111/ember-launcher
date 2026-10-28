import SwiftUI
import LauncherCore

/// Glass card displaying health metrics for Java, Memory, and Updates.
struct EmberHealthCard: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.windowWidth) private var windowWidth

    private var isMemoryRecommended: Bool {
        let range = JVMArgumentsBuilder.memoryRecommendation(isModded: false).recommendedRangeMB
        return range.contains(Int(settings.memoryGB * 1024))
    }

    private var hasWarning: Bool {
        !isMemoryRecommended
    }

    var body: some View {
        HStack(spacing: 17) {
            // Orb
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.violet.opacity(0.22),
                                Theme.ember.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: windowWidth < 760 ? 48 : 58,
                           height: windowWidth < 760 ? 48 : 58)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: hasWarning
                                ? [Theme.ember, Theme.emberDeep]
                                : [Theme.violet, Theme.ember],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(45))
                    .shadow(color: Theme.ember.opacity(0.26), radius: 10)
            }
            .frame(width: windowWidth < 760 ? 48 : 58,
                   height: windowWidth < 760 ? 48 : 58)

            // Text content
            VStack(alignment: .leading, spacing: 5) {
                Text(tr: hasWarning ? "One thing to check" : "Ember is ready")
                    .style(
                        .init(
                            size: 10,
                            weight: .medium,
                            mono: true,
                            tracking: 0.13,
                            color: Color(red: 142/255, green: 105/255, blue: 126/255)
                        )
                    )
                Text(tr: hasWarning ? "Memory is above the recommended range." : "Everything feels good.")
                    .style(.init(size: 16, weight: .semibold, tracking: -0.01, color: Theme.text))
                Text(tr: hasWarning ?
                     "Lower the memory in Java & memory to keep your Mac smooth." :
                     "Java 21 is healthy, memory is balanced, and your worlds are safely backed up.")
                    .style(.init(size: 12.5, weight: .regular, tracking: -0.005,
                                 color: Color(red: 129/255, green: 122/255, blue: 128/255)))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Check badge
            if windowWidth >= 760 {
                Circle()
                    .fill(Color(red: 32/255, green: 39/255, blue: 25/255))
                    .frame(width: 25, height: 25)
                    .overlay(
                        Image(systemName: hasWarning ? "exclamationmark" : "checkmark")
                            .font(Theme.font(size: 11, weight: .semibold))
                            .foregroundColor(hasWarning ? Theme.ember : Theme.success)
                    )
            }
        }
        .frame(minHeight: 124)
        .padding(21)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 24/255, green: 20/255, blue: 23/255),
                            Color(red: 23/255, green: 18/255, blue: 25/255),
                            Color(red: 28/255, green: 20/255, blue: 32/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RadialGradient(
                colors: [Theme.ember.opacity(0.12), Color.clear],
                center: UnitPoint(x: 0.05, y: 0.4),
                startRadius: 0,
                endRadius: 220
            )
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .allowsHitTesting(false)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(Color(red: 58/255, green: 45/255, blue: 55/255), lineWidth: 1)
        )
    }
}

/// Glass card group with a mono uppercase eyebrow header and enclosed settings rows.
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tr: title)
                .style(.init(size: 11, weight: .medium, mono: true, tracking: 0.14, color: Theme.textMuted))
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .overlay(alignment: .bottom) {
                    Theme.border.frame(height: 1)
                }

            content()
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .glass()
    }
}

/// Minus / Value / Plus memory stepper control.
struct MemoryStepper: View {
    @Binding var memoryGB: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Local private var isMinusHovered = false
    @Local private var isPlusHovered = false

    private var canDecrease: Bool {
        memoryGB - 1 >= SettingsStore.memoryRange.lowerBound
    }

    private var canIncrease: Bool {
        memoryGB + 1 <= SettingsStore.memoryRange.upperBound
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: {
                guard canDecrease else { return }
                if reduceMotion {
                    memoryGB -= 1
                } else {
                    withAnimation(.easeOut(duration: 0.18)) {
                        memoryGB -= 1
                    }
                }
            }) {
                Image(systemName: "minus")
                    .font(Theme.font(size: 11, weight: .semibold))
                    .foregroundColor(canDecrease ? Theme.text : Theme.textMuted)
                    .frame(width: 30, height: 30)
                    .background(Theme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCompact, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusCompact, style: .continuous)
                            .strokeBorder(isMinusHovered && canDecrease ? Color(hex: 0x544038) : Color(hex: 0x302c2a), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canDecrease)
            .onHover { isMinusHovered = $0 }
            .accessibilityLabel(L("Less memory"))

            Text(L("%d GB", Int(memoryGB)))
                .style(.init(size: 15, weight: .semibold, tracking: -0.01, color: Theme.ember))
                .frame(minWidth: 46, alignment: .center)

            Button(action: {
                guard canIncrease else { return }
                if reduceMotion {
                    memoryGB += 1
                } else {
                    withAnimation(.easeOut(duration: 0.18)) {
                        memoryGB += 1
                    }
                }
            }) {
                Image(systemName: "plus")
                    .font(Theme.font(size: 11, weight: .semibold))
                    .foregroundColor(canIncrease ? Theme.text : Theme.textMuted)
                    .frame(width: 30, height: 30)
                    .background(Theme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCompact, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusCompact, style: .continuous)
                            .strokeBorder(isPlusHovered && canIncrease ? Color(hex: 0x544038) : Color(hex: 0x302c2a), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canIncrease)
            .onHover { isPlusHovered = $0 }
            .accessibilityLabel(L("More memory"))
        }
    }
}

struct MemoryPresetItem {
    let name: String
    let gb: Int
}

private let memoryPresets: [MemoryPresetItem] = [
    MemoryPresetItem(name: "Light", gb: 4),
    MemoryPresetItem(name: "Balanced", gb: 6),
    MemoryPresetItem(name: "Modded", gb: 8),
    MemoryPresetItem(name: "Heavy", gb: 12)
]

/// Preset button with ember highlight when active.
struct MemoryPresetButton: View {
    let preset: MemoryPresetItem
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Local private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(tr: preset.name)
                    .style(.init(size: 13, weight: .semibold, tracking: -0.01, color: isSelected ? Theme.text : Theme.textSecondary))
                Text(L("%d GB", preset.gb))
                    .style(.init(size: 11.5, weight: .medium, color: isSelected ? Theme.ember : Theme.textMuted))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 12)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [Theme.ember.opacity(0.16), Theme.violet.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else if isHovered && !isDisabled {
                        Theme.elevated
                    } else {
                        Theme.surface
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .strokeBorder(
                        isSelected ? Theme.ember :
                            (isHovered && !isDisabled ? Color(hex: 0x3e3631) : Color(hex: 0x292624)),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(preset.name), \(preset.gb) GB")
    }
}

/// Adaptive grid of 4 memory preset options.
struct MemoryPresetsGrid: View {
    @Binding var memoryGB: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 7) {
            ForEach(memoryPresets, id: \.gb) { preset in
                let isSelected = Int(memoryGB) == preset.gb
                let isDisabled = Double(preset.gb) > SettingsStore.memoryRange.upperBound
                MemoryPresetButton(
                    preset: preset,
                    isSelected: isSelected,
                    isDisabled: isDisabled
                ) {
                    if reduceMotion {
                        memoryGB = Double(preset.gb)
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) {
                            memoryGB = Double(preset.gb)
                        }
                    }
                }
            }
        }
    }
}

/// No key yet: a hidden input and Save. Key saved: a badge and Remove (it is never shown again).
struct AIKeyField: View {
    @EnvironmentObject var settings: SettingsStore
    @Local private var draft = ""

    var body: some View {
        if settings.hasAIKey {
            HStack(spacing: 12) {
                MonoBadge(text: L("Saved"))
                SecondaryPill(title: "Remove", action: settings.removeAIKey)
            }
        } else {
            HStack(spacing: 10) {
                VoxelSecureInput(label: "API key", text: $draft, width: 200, placeholder: "sk-…")
                SecondaryPill(title: "Save") {
                    settings.saveAIKey(draft)
                    draft = ""
                }
            }
        }
    }
}
