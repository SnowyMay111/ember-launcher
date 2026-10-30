import LauncherCore
import SwiftUI

struct ModDetailPanel: View {
    let hit: ModrinthHit
    @ObservedObject var mods: ModsController

    @EnvironmentObject var app: AppState
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Local private var isAppeared = false

    @ViewBuilder private var headerRow: some View {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr: "MODRINTH PROJECT")
                        .style(.eyebrow)
                        .padding(.bottom, 4)
                    Text(verbatim: hit.title)
                        .font(Theme.font(size: 25, weight: .semibold))
                        .tracking(-1)
                        .foregroundColor(.white)
                        .lineLimit(1)
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
    }

    @ViewBuilder private var titleRow: some View {
            HStack(spacing: 14) {
                AsyncImage(url: hit.iconURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: ModDetailPanel.gradientColors(for: hit.projectId).0),
                                Color(hex: ModDetailPanel.gradientColors(for: hit.projectId).1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: 55, height: 55)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 4) {
                    // Category
                    if let cat = ModDetailPanel.firstValidCategory(from: hit.categories) {
                        Text(cat.uppercased())
                            .font(Theme.font(size: 8, weight: .medium, mono: true))
                            .tracking(0.12)
                            .foregroundColor(Color(hex: 0x8b657f))
                    } else {
                        Text(tr: "MOD")
                            .font(Theme.font(size: 8, weight: .medium, mono: true))
                            .tracking(0.12)
                            .foregroundColor(Color(hex: 0x8b657f))
                    }

                    // Title
                    Text(verbatim: hit.title)
                        .font(Theme.font(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    // Author
                    if !hit.author.isEmpty {
                        Text(L("by %@", hit.author))
                            .font(Theme.font(size: 10))
                            .foregroundColor(Color(hex: 0x686168))
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 20)
    }

    @ViewBuilder private var descriptionText: some View {
            Text(verbatim: hit.description)
                .font(Theme.font(size: 11))
                .foregroundColor(Color(hex: 0x817a81))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)
                .padding(.horizontal, 22)
    }

    @ViewBuilder private var compatStrip: some View {
            if let note = ModDetailPanel.compatibilityNote(mods: mods, hit: hit) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(hex: 0x8fa370))
                        .frame(width: 5, height: 5)
                    Text(note.text)
                        .font(Theme.font(size: 10))
                        .foregroundColor(note.isWarning ? Theme.danger.opacity(0.9) : Color(hex: 0x93a476))
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(note.isWarning ? Color(hex: 0x201514) : Color(hex: 0x171b14))
                )
                .padding(.horizontal, 22)
            }
    }

    @ViewBuilder private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(labelKey: "DOWNLOADS", value: ModsScreen.short(hit.downloads))
            if let follows = hit.follows {
                Rectangle()
                    .fill(Color(hex: 0x282528))
                    .frame(width: 1)
                statCell(labelKey: "FOLLOWERS", value: ModsScreen.short(follows))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color(hex: 0x282528), lineWidth: 1)
        )
        .padding(.vertical, 20)
        .padding(.horizontal, 22)
    }

    @ViewBuilder private var primaryButton: some View {
            Button(action: {
                Task {
                    if mods.kind == .mod {
                        await mods.install(hit)
                    } else {
                        await mods.installContent(hit)
                    }
                }
            }) {
                Text(ModDetailPanel.primaryButtonLabel(mods: mods, hit: hit))
                    .font(Theme.font(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: 0x1b110a))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.emberGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Theme.ember, lineWidth: 1)
                    )
            }
            .buttonStyle(PressDimStyle())
            .disabled(ModDetailPanel.isPrimaryDisabled(mods: mods, hit: hit))
            .opacity(ModDetailPanel.isPrimaryDisabled(mods: mods, hit: hit) ? 0.45 : 1)
            .padding(.horizontal, 22)
    }

    @ViewBuilder private var secondaryRow: some View {
            VStack(spacing: 7) {
                Button(action: {
                    openURL(ModsScreen.projectURL(hit, kind: mods.kind))
                }) {
                    Text(tr: "View on Modrinth")
                        .font(Theme.font(size: 11))
                        .foregroundColor(Color(red: 0xa1/255, green: 0x9a/255, blue: 0xa1/255))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0x17/255, green: 0x15/255, blue: 0x17/255))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(red: 0x29/255, green: 0x26/255, blue: 0x29/255), lineWidth: 1)
                        )
                }
                .buttonStyle(PressDimStyle())
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 22)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            titleRow
            descriptionText
            compatStrip
            statsRow
            primaryButton
            secondaryRow
        }
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
        .accessibilityLabel(L("Modrinth Project"))
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private func statCell(labelKey: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(tr: labelKey)
                .font(Theme.font(size: 8, weight: .medium, mono: true))
                .tracking(0.1)
                .foregroundColor(Color(hex: 0x625c62))
            Text(value)
                .font(Theme.font(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    private static func gradientColors(for projectId: String) -> (UInt32, UInt32) {
        let palettes: [(UInt32, UInt32)] = [
            (0x514161, 0x241d2a),
            (0x6d4634, 0x2b1e18),
            (0x465441, 0x1d251c),
            (0x66517b, 0x2b2432)
        ]
        let idx = ModsScreen.paletteIndex(projectId) % palettes.count
        return palettes[idx]
    }

    private static func firstValidCategory(from categories: [String]) -> String? {
        for cat in categories {
            if !ModsScreen.loaderSlugs.contains(cat) {
                return ModsScreen.prettifyCategory(cat)
            }
        }
        return nil
    }

    private static func compatibilityNote(mods: ModsController, hit: ModrinthHit) -> (text: String, isWarning: Bool)? {
        let kind = mods.kind
        let note: (text: String, isWarning: Bool)?
        if mods.needsFabric {
            note = (L("Needs Fabric"), true)
        } else if kind == .mod {
            note = ModsScreen.compatNote(mods.compat[hit.projectId])
        } else {
            note = ModsScreen.contentNote(mods.contentCompat[hit.projectId])
        }

        guard var n = note else { return nil }

        if let instance = mods.instanceName {
            n.text = n.text + " · " + instance
        }
        return n
    }

    private static func isPrimaryDisabled(mods: ModsController, hit: ModrinthHit) -> Bool {
        let kind = mods.kind
        let canInstall: Bool = {
            if mods.needsFabric { return false }
            if kind == .mod {
                return ModsScreen.canInstall(mods.compat[hit.projectId])
            } else {
                return ModsScreen.canInstall(content: mods.contentCompat[hit.projectId])
            }
        }()
        let installed = kind == .mod ? mods.installedProjectIDs.contains(hit.projectId) : mods.contentProjectIDs.contains(hit.projectId)
        return !canInstall || installed || mods.busy.contains(hit.projectId)
    }

    private static func primaryButtonLabel(mods: ModsController, hit: ModrinthHit) -> String {
        let kind = mods.kind
        let installed = (kind == .mod ? mods.installedProjectIDs.contains(hit.projectId) : mods.contentProjectIDs.contains(hit.projectId))
        if installed {
            return L("Installed")
        }
        if mods.busy.contains(hit.projectId) {
            return L("Installing…")
        }
        if let name = mods.instanceName {
            return L("Install to %@", name)
        }
        return L("Install")
    }
}
