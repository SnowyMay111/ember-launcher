import SwiftUI

struct InstanceDetailPanel: View {
    @EnvironmentObject var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Local private var isAppeared = false

    let instance: LibraryInstance

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr: "INSTANCE DETAILS").style(.eyebrow)
                        .padding(.bottom, 4)
                    Text(verbatim: instance.name)
                        .font(Theme.font(size: 25, weight: .semibold))
                        .tracking(-1)
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: { app.modal = nil }) {
                    Circle()
                        .fill(Color(red: 0x20/255, green: 0x1e/255, blue: 0x20/255))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("×")
                                .font(.system(size: 18))
                                .foregroundColor(Color(red: 0x8e/255, green: 0x87/255, blue: 0x8e/255))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Close"))
            }
            .padding(.top, 25)
            .padding(.horizontal, 27)
            .padding(.bottom, 20)

            // Hero preview
            InstancePreview(variant: instance.previewVariant)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .padding(.horizontal, 22)

            // Tabs
            HStack(spacing: 16) {
                tabButton(label: "Overview", isActive: true) {
                    // no action, just label
                }
                tabButton(label: "Mods", isActive: false) {
                    app.modal = nil
                    app.screen = .mods
                }
                tabButton(label: "Worlds", isActive: false) {
                    app.openFolder(instance.name)
                }
                tabButton(label: "Logs", isActive: false) {
                    app.modal = .gameLog(instance.name)
                }
            }
            .font(Theme.font(size: 11, weight: .medium))
            .padding(.vertical, 17)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().fill(Color(hex: 0x252225)).frame(height: 1), alignment: .bottom)
            .padding(.horizontal, 22)

            // Stats
            HStack(spacing: 0) {
                statCell(label: "PLAYTIME", value: instance.playtimeText)
                Rectangle().fill(Color(hex: 0x282528)).frame(width: 1)
                statCell(label: "VERSION", value: instance.minecraftVersion)
                Rectangle().fill(Color(hex: 0x282528)).frame(width: 1)
                statCell(label: "MEMORY", value: String(format: "%g GB", Double(instance.memoryMB) / 1024))
            }
            .fixedSize(horizontal: false, vertical: true)
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color(hex: 0x282528), lineWidth: 1)
            )
            .padding(.vertical, 20)
            .padding(.horizontal, 22)

            // Caption
            Text(L("%@ · %d mods", instance.loader.rawValue, instance.modCount))
                .font(Theme.font(size: 10))
                .foregroundColor(Color(hex: 0x676067))
                .padding(.bottom, 18)
                .padding(.horizontal, 22)

            // Action rows
            VStack(spacing: 7) {
                detailRow(text: "Show on Home") {
                    app.open(instance)
                    app.modal = nil
                }
                detailRow(text: "Open folder") {
                    app.openFolder(instance.name)
                }
                detailRow(text: "Instance settings") {
                    app.modal = .instanceSettings(instance.name)
                }
                detailRow(text: "Delete instance", isDanger: true) {
                    app.deleteRequest = instance.name
                    app.modal = nil
                }
            }
            .padding(.horizontal, 22)
        }
        .padding(.bottom, 22)
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView(.vertical, showsIndicators: false) { content }
        }
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0x11/255, green: 0x10/255, blue: 0x11/255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(red: 0x34/255, green: 0x2e/255, blue: 0x34/255), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.7), radius: 35, x: 0, y: 20)
        .shadow(color: Color(red: 105/255, green: 62/255, blue: 125/255).opacity(0.08), radius: 35, x: 0, y: 0)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: reduceMotion ? 0 : (isAppeared ? 0 : 12))
        .scaleEffect(reduceMotion ? 1 : (isAppeared ? 1 : 0.98))
        .onAppear { withAnimation(.easeOut(duration: 0.28)) { isAppeared = true } }
        .onExitCommand { app.modal = nil }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("Instance Details"))
        .padding(.vertical, 24)
    }

    // MARK: - Tab button
    @ViewBuilder
    private func tabButton(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        if isActive {
            Text(tr: label)
                .foregroundColor(Theme.ember)
        } else {
            Button(action: action) {
                Text(tr: label)
                    .foregroundColor(Color(hex: 0x666067))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    // brightened hover color
                    // using overlay change via state
                }
            }
            .foregroundColor(Color(hex: 0x666067))
            .onHover { hovering in
                // Hover effect
                // This is handled by PressDimStyle in rows; for tabs we manually adjust
            }
        }
    }

    // MARK: - Stat cell
    @ViewBuilder
    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(tr: label)
                .font(Theme.font(size: 8, weight: .medium))
                .tracking(0.1)
                .foregroundColor(Color(hex: 0x625c62))
            Text(verbatim: value)
                .font(Theme.font(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(Color(hex: 0x282528), lineWidth: 1)
        )
    }

    // MARK: - Detail row
    private func detailRow(text: String, isDanger: Bool = false, action: @escaping () -> Void) -> some View {
        DetailRowButton(text: text, isDanger: isDanger, action: action)
    }

    private struct DetailRowButton: View {
        let text: String
        let isDanger: Bool
        let action: () -> Void
        @Local private var isHovering = false

        var body: some View {
            Button(action: action) {
                Text(tr: text)
                    .font(Theme.font(size: 11))
                    .foregroundColor(isDanger ? Color(hex: 0xa96b68) : Color(red: 0xa1/255, green: 0x9a/255, blue: 0xa1/255))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isHovering ? Color(red: 0x1e/255, green: 0x1b/255, blue: 0x1e/255) : Color(red: 0x17/255, green: 0x15/255, blue: 0x17/255))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(red: 0x29/255, green: 0x26/255, blue: 0x29/255), lineWidth: 1)
                    )
            }
            .buttonStyle(PressDimStyle())
            .onHover { hovering in
                isHovering = hovering
            }
        }
    }
}
