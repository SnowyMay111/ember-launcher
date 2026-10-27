import SwiftUI

/// Horizontal step indicator for wizard flows.
struct FlowStepper: View {
    let step: Int
    var total = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...total, id: \.self) { index in
                Circle()
                    .strokeBorder(Color(hex: 0x514a51), lineWidth: 1)
                    .background(
                        Circle()
                            .fill(index <= step ? Theme.ember : Color.clear)
                    )
                    .frame(width: 8, height: 8)
                    .shadow(color: Theme.emberSoft, radius: index <= step ? 9 : 0)
                    .accessibilityHidden(true)

                if index < total {
                    Rectangle()
                        .fill(Color(hex: 0x292529))
                        .frame(width: 70, height: 1)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(height: 30)
        .accessibilityElement()
        .accessibilityLabel(L("Step %d of %d", step, total))
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Card for selectable choices in the wizard.
struct ChoiceCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    @Local private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .strokeBorder(Color(hex: 0x6b646b), lineWidth: 1)
                    .background(
                        Circle()
                            .fill(isSelected ? Theme.ember : Color.clear)
                    )
                    .frame(width: 9, height: 9)
                    .shadow(color: Theme.emberSoft, radius: isSelected ? 8 : 0)
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: title)
                        .style(.init(size: 12, weight: .bold, color: isSelected ? Color(hex: 0xeee8ee) : Color(hex: 0xaaa3aa)))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(tr: subtitle)
                        .style(.init(size: 10, color: Color(hex: 0x676168)))
                }
            }
            .frame(minHeight: 78)
            .padding(13)
            .background(isSelected ? Color(hex: 0x211b22) : Color(hex: 0x171517))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color(hex: isSelected ? 0x654e68 : 0x292629), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Preview of the instance name.
struct NamePreviewCard: View {
    let name: String

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.emberGradient)
                    .frame(width: 34, height: 34)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(hex: 0x1b110a))
                    .frame(width: 12, height: 12)
                    .opacity(0.55)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tr: "YOUR NEW INSTANCE")
                    .style(.init(size: 8, weight: .medium, mono: true, tracking: 0.1, color: Color(hex: 0x676068)))

                Text(verbatim: name)
                    .style(.init(size: 13, weight: .semibold, color: .white))
                    .lineLimit(1)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0x151315))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(hex: 0x282428), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

/// Card showing a summary of selected options.
struct SummaryCard: View {
    let rows: [(label: String, value: String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack {
                    Text(tr: row.label)
                        .style(.init(size: 9, weight: .medium, mono: true, tracking: 0.1, color: Color(hex: 0x655f65)))

                    Spacer()

                    Text(verbatim: row.value)
                        .style(.init(size: 12, weight: .semibold, color: Color(hex: 0xeee8ee)))
                }
                .frame(minHeight: 54)
                .padding(.horizontal, 17)

                if idx < rows.count - 1 {
                    Divider()
                        .background(Color(hex: 0x252225))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(hex: 0x2b282b), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

/// Small text button used in flow footers.
struct FlowTextButton: View {
    let title: String
    var action: () -> Void = {}

    @Local private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(tr: title)
                .style(.init(size: 12, weight: .medium, color: isHovered ? Color(hex: 0xb7b0b7) : Color(hex: 0x797279)))
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

/// Primary action button for flow footers.
struct FlowPrimaryButton: View {
    let title: String
    var isDisabled = false
    var action: () -> Void = {}

    @Local private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(tr: title)
                .style(.init(size: 13, weight: .bold, color: Color(hex: 0x1b110a)))
                .padding(.vertical, 12)
                .padding(.horizontal, 17)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.emberGradient)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.ember, lineWidth: 1)
                        )
                )
                .shadow(color: Theme.emberSoft, radius: isHovered && !isDisabled && !reduceMotion ? 20 : 14, y: isHovered && !isDisabled && !reduceMotion ? 6 : 0)
                .offset(y: isHovered && !isDisabled && !reduceMotion ? -1 : 0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1.0)
        .keyboardShortcut(.defaultAction)
        .onHover { hovering in isHovered = hovering }
    }
}

/// Install state view shown during installation.
struct FlowInstallState: View {
    let title: String
    let detail: String
    var fraction: Double? = nil

    @Local private var isTurned = false
    @Local private var isSliding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: 0x1f1920))
                    .shadow(color: Color(hex: 0x9657ae).opacity(0.14), radius: 35)

                Rectangle()
                    .fill(
                        LinearGradient(colors: [Color(hex: 0x9f69bd), Color(hex: 0xe3975f)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .frame(width: 25, height: 25)
                    .modifier(TurnAnimation(isTurned: $isTurned, reduceMotion: reduceMotion))
            }
            .frame(width: 68, height: 68)

            Spacer().frame(height: 25)

            Text(verbatim: title)
                .style(.init(size: 15, weight: .bold, color: .white))

            Text(verbatim: detail)
                .style(.init(size: 12, color: Color(hex: 0x706970)))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 4)

            // Progress track
            VStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: 0x282428))
                        .frame(height: 4)

                    if let fraction = fraction {
                        GeometryReader { geo in
                            Capsule()
                                .fill(
                                    LinearGradient(colors: [Color(hex: 0x8f5eaa), Theme.ember],
                                                   startPoint: .leading,
                                                   endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * CGFloat(fraction), height: 4)
                                .animation(.easeOut(duration: 0.25), value: fraction)
                        }
                    } else {
                        SlidingProgress(isSliding: $isSliding, reduceMotion: reduceMotion)
                            .frame(height: 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)

                if let fraction = fraction {
                    Text(verbatim: "\(Int(fraction * 100))%")
                        .style(.init(size: 10, mono: true, color: Color(hex: 0x514c51)))
                }
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, minHeight: 330)
        .accessibilityElement(children: .combine)
        .onAppear {
            isTurned.toggle()
            if fraction == nil {
                isSliding.toggle()
            }
        }
    }
}

// MARK: - Helper modifiers

private struct TurnAnimation: ViewModifier {
    @Binding var isTurned: Bool
    var reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .rotationEffect(.degrees(isTurned ? 90 : 0))
                .scaleEffect(isTurned ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isTurned)
        }
    }
}

private struct SlidingProgress: View {
    @Binding var isSliding: Bool
    var reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            GeometryReader { geo in
                Capsule()
                    .fill(
                        LinearGradient(colors: [Color(hex: 0x8f5eaa), Theme.ember],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * 0.35)
            }
        } else {
            Capsule()
                .fill(
                    LinearGradient(colors: [Color(hex: 0x8f5eaa), Theme.ember],
                                   startPoint: .leading,
                                   endPoint: .trailing)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .mask(
                    GeometryReader { geo in
                        Capsule()
                            .frame(width: geo.size.width * 0.35)
                            .offset(x: isSliding ? geo.size.width * 0.65 : 0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isSliding)
                    }
                )
        }
    }
}
