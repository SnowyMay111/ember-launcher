import SwiftUI

private let fieldFont = Font.custom("Geist-Regular", size: 14)

/// Search field: elevated fill, border, radius 12, magnifier icon, placeholder in textMuted.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    /// Toolbar look of the prototype's `.search-field`: 280×42, 13 pt text.
    var compact = false
    @FocusState private var focused: Bool
    @Local private var isHovered = false

    var body: some View {
        let radius: CGFloat = compact ? 11 : Theme.radiusInput
        HStack(spacing: compact ? 8 : 10) {
            SearchIcon()
                .stroke(focused ? Theme.ember : (compact ? Color(hex: 0x77716b) : Theme.textMuted), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: compact ? 15 : 16, height: compact ? 15 : 16)
                .accessibilityHidden(true)
            TextField("", text: $text, prompt: Text(verbatim: L(placeholder)).foregroundColor(compact ? Color(hex: 0x56524e) : Theme.textMuted))
                .textFieldStyle(.plain)
                .font(compact ? Theme.font(size: 13, weight: .regular, mono: false) : fieldFont)
                .foregroundColor(compact ? Color(hex: 0xddd7d0) : Theme.text)
                .focused($focused)
                .accessibilityLabel(L(placeholder))
        }
        .padding(.horizontal, compact ? 13 : 14)
        .frame(width: compact ? 280 : 260, height: compact ? 42 : 40)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(compact ? Color(hex: 0x10100f) : Theme.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    focused ? Theme.ember.opacity(0.6) : (isHovered ? Theme.lineStrong : (compact ? Color(hex: 0x272522) : Theme.border)),
                    lineWidth: focused ? 1.5 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .onHover { isHovered = $0 }
        .onTapGesture { focused = true }
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .animation(.easeInOut(duration: 0.18), value: focused)
    }
}

/// Full-width search field for list screens.
struct WideSearchField: View {
    let placeholder: String
    @Binding var text: String
    let resultText: String?
    @FocusState private var focused: Bool
    @Local private var isHovered = false
    @Local private var isClearHovered = false

    init(placeholder: String, text: Binding<String>, resultText: String? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.resultText = resultText
    }

    var body: some View {
        HStack(spacing: 12) {
            SearchIcon()
                .stroke(
                    focused ? Theme.ember : Theme.textSecondary,
                    style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            TextField(
                "",
                text: $text,
                prompt: Text(verbatim: L(placeholder)).foregroundColor(Theme.textSecondary)
            )
                .textFieldStyle(.plain)
                .font(Theme.font(size: 15))
                .foregroundColor(Theme.text)
                .focused($focused)
                .accessibilityLabel(L(placeholder))
            if !text.isEmpty {
                if let resultText = resultText {
                    Text(verbatim: resultText)
                        .font(Theme.font(size: 13))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(Theme.font(size: 11, weight: .semibold))
                        .foregroundColor(isClearHovered ? Theme.text : Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .onHover { isClearHovered = $0 }
                .accessibilityLabel(L("Clear search"))
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    focused ? Theme.ember.opacity(0.6) : (isHovered ? Theme.lineStrong : Theme.border),
                    lineWidth: focused ? 1.5 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onHover { isHovered = $0 }
        .onTapGesture { focused = true }
        .onExitCommand { text = "" }
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .animation(.easeInOut(duration: 0.18), value: focused)
    }
}

/// Text input: elevated fill, border, ember focus ring.
struct EmberInput: View {
    let label: String
    @Binding var text: String
    var width: CGFloat? = nil
    var alignment: TextAlignment = .leading
    var placeholder = ""
    @FocusState private var focused: Bool
    @Local private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        TextField("", text: $text, prompt: Text(verbatim: placeholder).foregroundColor(Theme.textMuted))
            .textFieldStyle(.plain)
            .font(fieldFont)
            .foregroundColor(Theme.text)
            .multilineTextAlignment(alignment)
            .focused($focused)
            .padding(.horizontal, 14)
            .frame(width: width, height: 40)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .fill(Theme.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .strokeBorder(
                        focused ? Theme.ember.opacity(0.6) : (isHovered ? Theme.lineStrong : Theme.border),
                        lineWidth: focused ? 1.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous))
            .onHover { isHovered = $0 }
            .onTapGesture { focused = true }
            .opacity(isEnabled ? 1.0 : 0.45)
            .animation(.easeInOut(duration: 0.18), value: isHovered)
            .animation(.easeInOut(duration: 0.18), value: focused)
            .accessibilityLabel(L(label))
    }
}

/// Switch with ember gradient track when on, elevated fill when off, and smooth motion.
struct EmberToggle: View {
    let label: String
    @Binding var isOn: Bool

    @Local private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                // background
                Capsule()
                    .fill(isOn ? Color(hex: 0x5e3d2c) : Color(hex: 0x292624))
                // knob
                Circle()
                    .fill(isOn ? Color(hex: 0xff4500) : Color(hex: 0x77716b))
                    .frame(width: 16, height: 16)
                    .padding(3)
            }
            .frame(width: 38, height: 22)
            .overlay(
                Capsule()
                    .strokeBorder(isOn ? Color(hex: 0xff4500) : Theme.ember.opacity(0.6), lineWidth: isOn ? 0 : 1.5)
                    .padding(-2)
                    .opacity(isFocused ? 1 : 0)
            )
            .contentShape(Capsule())
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isOn)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.45)
        .accessibilityLabel(L(label))
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? L("On") : L("Off"))
    }
}

/// Native slider with ember tint and mono value readout.
struct EmberSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String

    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 14) {
            Slider(value: Binding(get: { value }, set: { value = $0.rounded() }), in: range)
                .tint(Theme.ember)
                .focused($isFocused)
                .frame(width: 200)
                .accessibilityLabel(L(label))
            Text(verbatim: valueText)
                .style(.init(size: 13, weight: .regular, mono: true, color: Theme.text))
                .frame(minWidth: 44, alignment: .trailing)
        }
        .opacity(isEnabled ? 1.0 : 0.45)
    }
}

/// Secure input with elevated fill, border, and ember focus ring.
struct EmberSecureInput: View {
    let label: String
    @Binding var text: String
    var width: CGFloat? = nil
    var placeholder = ""
    @FocusState private var focused: Bool
    @Local private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        SecureField("", text: $text, prompt: Text(verbatim: placeholder).foregroundColor(Theme.textMuted))
            .textFieldStyle(.plain)
            .font(fieldFont)
            .foregroundColor(Theme.text)
            .focused($focused)
            .padding(.horizontal, 14)
            .frame(width: width, height: 40)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .fill(Theme.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .strokeBorder(
                        focused ? Theme.ember.opacity(0.6) : (isHovered ? Theme.lineStrong : Theme.border),
                        lineWidth: focused ? 1.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous))
            .onHover { isHovered = $0 }
            .onTapGesture { focused = true }
            .opacity(isEnabled ? 1.0 : 0.45)
            .animation(.easeInOut(duration: 0.18), value: isHovered)
            .animation(.easeInOut(duration: 0.18), value: focused)
            .accessibilityLabel(L(label))
    }
}

/// Multi-line text editor with elevated fill, border, and ember focus ring.
struct EmberTextArea: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var height: CGFloat = 96
    @FocusState private var focused: Bool
    @Local private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(fieldFont)
                .foregroundColor(Theme.text)
                .focused($focused)
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
            if text.isEmpty {
                Text(verbatim: placeholder)
                    .font(fieldFont)
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                .fill(Theme.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                .strokeBorder(
                    focused ? Theme.ember.opacity(0.6) : (isHovered ? Theme.lineStrong : Theme.border),
                    lineWidth: focused ? 1.5 : 1
                )
        )
        .onHover { isHovered = $0 }
        .opacity(isEnabled ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .animation(.easeInOut(duration: 0.18), value: focused)
        .accessibilityLabel(L(label))
    }
}

private struct CheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.maxY - rect.height * 0.25))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.28))
        return path
    }
}

/// Square check box: ember fill when on, elevated outline when off, min 40x40 hit target.
struct EmberCheckbox: View {
    let label: String
    @Binding var isOn: Bool

    @Local private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    private let darkWarmText = Color(red: 27 / 255.0, green: 17 / 255.0, blue: 10 / 255.0)

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? Theme.ember : Theme.elevated)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isOn ? Theme.ember : (isHovered ? Theme.lineStrong : Theme.border),
                        lineWidth: 1
                    )
                if isOn {
                    CheckMark()
                        .stroke(darkWarmText, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: 20, height: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.ember.opacity(0.6), lineWidth: 1.5)
                    .padding(-3)
                    .opacity(isFocused ? 1 : 0)
            )
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDimStyle())
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .accessibilityLabel(L(label))
        .accessibilityValue(isOn ? "on" : "off")
    }
}
