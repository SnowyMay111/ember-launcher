import SwiftUI

private let fieldFont = Font.custom("Geist-Regular", size: 14)

/// Search pill: height 42, magnifier in muted.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            SearchIcon()
                .stroke(Theme.muted, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            TextField("", text: $text, prompt: Text(verbatim: L(placeholder)).foregroundColor(Theme.muted))
                .textFieldStyle(.plain)
                .font(fieldFont)
                .foregroundColor(.white)
                .focused($focused)
                .accessibilityLabel(L(placeholder))
        }
        .padding(.horizontal, 16)
        .frame(width: 260, height: 42)
        .background(Capsule().fill(Theme.black40))
        .overlay(Capsule().strokeBorder(Theme.lineStrong, lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture { focused = true }
    }
}

/// Text input: height 40, radius 12.
struct VoxelInput: View {
    let label: String
    @Binding var text: String
    var width: CGFloat? = nil
    var alignment: TextAlignment = .leading
    var placeholder = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(verbatim: placeholder).foregroundColor(Theme.muted))
            .textFieldStyle(.plain)
            .font(fieldFont)
            .foregroundColor(.white)
            .multilineTextAlignment(alignment)
            .focused($focused)
            .padding(.horizontal, 14)
            .frame(width: width, height: 40)
            .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.black45))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            .accessibilityLabel(L(label))
    }
}

/// Switch 52×30 with a 22pt knob.
struct VoxelToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Color.white : Theme.black45)
                if !isOn {
                    Capsule().strokeBorder(Theme.lineStrong, lineWidth: 1)
                }
                Circle()
                    .fill(isOn ? Color.black : Theme.muted)
                    .frame(width: 22, height: 22)
                    .padding(4)
            }
            .frame(width: 52, height: 30)
            .frame(minHeight: 36)
            .contentShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L(label))
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? L("On") : L("Off"))
    }
}

/// Native slider, white tint, width 200, value in mono on the right.
struct VoxelSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String

    var body: some View {
        HStack(spacing: 14) {
            Slider(value: Binding(get: { value }, set: { value = $0.rounded() }), in: range)
                .tint(.white)
                .frame(width: 200)
                .accessibilityLabel(L(label))
            Text(verbatim: valueText)
                .style(.init(size: 13, weight: .regular, mono: true, color: Theme.text))
                .frame(minWidth: 44, alignment: .trailing)
        }
    }
}

/// Same look as `VoxelInput`, but the text is hidden (API keys).
struct VoxelSecureInput: View {
    let label: String
    @Binding var text: String
    var width: CGFloat? = nil
    var placeholder = ""
    @FocusState private var focused: Bool

    var body: some View {
        SecureField("", text: $text, prompt: Text(verbatim: placeholder).foregroundColor(Theme.muted))
            .textFieldStyle(.plain)
            .font(fieldFont)
            .foregroundColor(.white)
            .focused($focused)
            .padding(.horizontal, 14)
            .frame(width: width, height: 40)
            .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.black45))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            .accessibilityLabel(L(label))
    }
}

/// Several lines of text in the input look (the AI pack description).
struct VoxelTextArea: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var height: CGFloat = 96
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(fieldFont)
                .foregroundColor(.white)
                .focused($focused)
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
            if text.isEmpty {
                Text(verbatim: placeholder)
                    .font(fieldFont)
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.black45))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
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

/// Square check box: white when on, outline when off.
struct VoxelCheckbox: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? Color.white : Theme.black45)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isOn ? Color.white : Theme.lineStrong, lineWidth: 1)
                if isOn {
                    CheckMark()
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L(label))
        .accessibilityValue(isOn ? "on" : "off")
    }
}
