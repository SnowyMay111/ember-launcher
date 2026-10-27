import SwiftUI

/// Dialog panel on the glass: title, content, and a right-aligned button row.
struct VoxelModal<Content: View, Footer: View>: View {
    let title: String
    var eyebrow: String? = nil
    var width: CGFloat = 540
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    @EnvironmentObject var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Local private var isAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let eyebrow = eyebrow {
                        Text(tr: eyebrow).style(.eyebrow)
                    }
                    Text(tr: title)
                        .font(Theme.font(size: 25, weight: .semibold))
                        .tracking(-1)
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    app.modal = nil
                } label: {
                    Circle()
                        .fill(Color(hex: 0x201e20))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("×")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: 0x8e878e))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Close"))
            }
            .padding(.top, 25)
            .padding(.horizontal, 27)
            .padding(.bottom, 20)

            // Content
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)

            // Footer
            Rectangle()
                .fill(Color(hex: 0x252225))
                .frame(height: 1)
            HStack(spacing: Theme.Space.m) {
                footer()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 27)
            .padding(.vertical, 17)
        }
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: 0x111011))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(hex: 0x342e34), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.7), radius: 35, x: 0, y: 20)
        .shadow(color: Theme.violet.opacity(0.08), radius: 35, x: 0, y: 0)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: reduceMotion ? 0 : (isAppeared ? 0 : 12))
        .scaleEffect(reduceMotion ? 1 : (isAppeared ? 1 : 0.98))
        .onAppear {
            withAnimation(.easeOut(duration: 0.28)) {
                isAppeared = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L(title))
    }
}

/// Mono caption above a control.
struct ModalField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(tr: label).style(.eyebrow)
            content()
        }
    }
}

/// Cancel button; Esc triggers it too.
struct ModalCancel: View {
    @EnvironmentObject var app: AppState
    var title = "Cancel"
    @Local private var isHovered = false

    var body: some View {
        Button {
            app.modal = nil
        } label: {
            Text(tr: title)
                .style(.init(
                    size: 12,
                    weight: .medium,
                    color: isHovered ? Color(hex: 0xb7b0b7) : Color(hex: 0x797279)
                ))
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .keyboardShortcut(.cancelAction)
    }
}

/// Dropdown: our own list opened from a field-like label (or a pill).
struct VoxelMenu<Content: View>: View {
    let label: String
    let value: String
    var isPill = false
    var minWidth: CGFloat? = nil
    var compact = false
    @ViewBuilder var content: () -> Content
    @Local private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        EmberDropdown(minWidth: minWidth, content: content) { isOpen in
            pill(isOpen: isOpen)
        }
        .onHover { isHovered = $0 }
        .fixedSize()
        .accessibilityLabel(L(label))
    }

    private func pill(isOpen: Bool) -> some View {
        let lit = isHovered || isOpen
        return HStack(spacing: 10) {
            Text(verbatim: value)
                .style(.init(
                    size: compact ? 10 : 14,
                    weight: compact ? .medium : .regular,
                    color: compact ? Color(hex: 0xb2aca4) : .white
                ))
                .lineLimit(1)
            Spacer(minLength: 0)
            ChevronDownIcon()
                .stroke(compact ? Color(hex: 0xb2aca4) : Theme.muted,
                        style: StrokeStyle(lineWidth: compact ? 1.4 : 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: compact ? 9 : 12, height: compact ? 9 : 12)
                .rotationEffect(.degrees(isOpen ? 180 : 0))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isOpen)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, compact ? 13 : (isPill ? 20 : 14))
        .frame(minWidth: minWidth)
        .frame(height: compact ? 32 : (isPill ? 44 : 40))
        .background(
            Group {
                if compact {
                    Capsule()
                        .fill(lit ? Color(hex: 0x171513) : .clear)
                } else {
                    RoundedRectangle(cornerRadius: isPill ? 22 : Theme.radiusInput, style: .continuous)
                        .fill(lit ? Theme.surface : Theme.elevated)
                }
            }
        )
        .overlay(
            Group {
                if compact {
                    Capsule()
                        .strokeBorder(lit ? Color(hex: 0x37322f) : .clear, lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: isPill ? 22 : Theme.radiusInput, style: .continuous)
                        .strokeBorder(lit ? Theme.line : Theme.border, lineWidth: 1)
                }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: compact ? 16 : (isPill ? 22 : Theme.radiusInput), style: .continuous))
    }
}

/// Group menu with a "New group…" entry that shows a text field.
struct GroupPicker: View {
    @EnvironmentObject var app: AppState
    @Binding var group: String
    @Local private var isNew = false

    var body: some View {
        HStack(spacing: 10) {
            VoxelMenu(label: "Group", value: isNew ? L("New group…") : L(group), minWidth: 160) {
                ForEach(app.groupNames, id: \.self) { name in
                    Button {
                        group = name
                        isNew = false
                    } label: {
                        HStack {
                            Text(L(name))
                            if !isNew && group == name {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.ember)
                            }
                        }
                    }
                }
                Divider()
                Button {
                    group = ""
                    isNew = true
                } label: {
                    HStack {
                        Text(L("New group…"))
                        if isNew {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(Theme.ember)
                        }
                    }
                }
            }
            if isNew {
                VoxelInput(label: "Group name", text: $group, width: 200)
            }
        }
    }
}

typealias ModalShell<Content: View, Footer: View> = VoxelModal<Content, Footer>
