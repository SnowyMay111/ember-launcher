import SwiftUI

/// Dialog panel on the glass: title, content, and a right-aligned button row.
struct VoxelModal<Content: View, Footer: View>: View {
    let title: String
    var width: CGFloat = 540
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tr: title).style(.cardTitle)
            content().padding(.top, 20)
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                footer()
            }
            .padding(.top, 26)
        }
        .padding(26)
        .frame(width: width)
        .background(Theme.surface)
        .glass()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L(title))
    }
}

/// Mono caption above a control.
struct ModalField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr: label).style(.eyebrow)
            content()
        }
    }
}

/// Cancel button; Esc triggers it too.
struct ModalCancel: View {
    @EnvironmentObject var app: AppState
    var title = "Cancel"

    var body: some View {
        SecondaryPill(title: title) { app.modal = nil }
            .keyboardShortcut(.cancelAction)
    }
}

/// Dropdown: the system menu opened from a field-like label (or a pill).
struct VoxelMenu<Content: View>: View {
    let label: String
    let value: String
    var isPill = false
    var minWidth: CGFloat? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu(content: content) {
            HStack(spacing: 10) {
                Text(verbatim: value)
                    .style(.init(size: 14, weight: .regular, color: .white))
                    .lineLimit(1)
                Spacer(minLength: 0)
                ChevronDownIcon()
                    .stroke(Theme.muted, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, isPill ? 20 : 14)
            .frame(minWidth: minWidth)
            .frame(height: isPill ? 44 : 40)
            .background(RoundedRectangle(cornerRadius: isPill ? 22 : Theme.radiusInput, style: .continuous).fill(isPill ? Theme.black40 : Theme.black45))
            .overlay(RoundedRectangle(cornerRadius: isPill ? 22 : Theme.radiusInput, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: isPill ? 22 : Theme.radiusInput, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(L(label))
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
                    Button(L(name)) {
                        group = name
                        isNew = false
                    }
                }
                Divider()
                Button(L("New group…")) {
                    group = ""
                    isNew = true
                }
            }
            if isNew {
                VoxelInput(label: "Group name", text: $group, width: 200)
            }
        }
    }
}
