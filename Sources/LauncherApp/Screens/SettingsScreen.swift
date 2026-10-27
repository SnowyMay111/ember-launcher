import SwiftUI
import LauncherCore

struct SettingsScreen: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var updates: UpdateController

    private var updateDetail: String {
        switch updates.checkStatus {
        case .checking: return L("Checking…")
        case .failed(let message): return message
        case .upToDate: return L("You're up to date.")
        case .idle:
            if let info = updates.info { return L("Version %@ is available.", info.version) }
            return "Looks for a newer version on GitHub."
        }
    }

    private var recommendedMemoryText: String {
        let range = JVMArgumentsBuilder.memoryRecommendation(isModded: false).recommendedRangeMB
        return L("Recommended: %d-%d GB", range.lowerBound / 1024, range.upperBound / 1024)
    }

    // MARK: - Layout state
    private enum SettingsSection: String, CaseIterable {
        case general = "General"
        case java = "Java & memory"
        case downloads = "Downloads"
        case ai = "AI"
        case about = "About"
    }

    @Local private var activeSection: SettingsSection = .general
    @Local private var offsets: [SettingsSection: CGFloat] = [:]
    @Local private var jump: SettingsSection?
    @Local private var isJumping = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let scrollSpace = "settings-scroll"

    private struct SectionOffsetKey: PreferenceKey {
        static var defaultValue: [SettingsSection: CGFloat] = [:]
        static func reduce(value: inout [SettingsSection: CGFloat], nextValue: () -> [SettingsSection: CGFloat]) {
            value.merge(nextValue()) { $1 }
        }
    }

    private var animates: Bool { !reduceMotion && settings.backgroundAnimations }

    @Environment(\.windowWidth) private var windowWidth

    @ViewBuilder
    private func sectionContent(_ section: SettingsSection) -> some View {
        switch section {
        case .general:
            EmberHealthCard(settings: settings)

            SettingsGroup(title: "General") {
                SettingsRow(title: "Nickname", detail: "Name you play under. Offline mode.") {
                    VoxelInput(label: "Nickname", text: $settings.nickname, width: 220)
                }
                SettingsRow(title: "Close launcher on start", detail: "Hide the launcher while you play.") {
                    VoxelToggle(label: "Close launcher on start", isOn: $settings.closeOnStart)
                }
                SettingsRow(title: "Background animations", detail: "Glows, particles and the moving scene. Turn off to save battery.", isLast: true) {
                    VoxelToggle(label: "Background animations", isOn: $settings.backgroundAnimations)
                }
            }

        case .java:
            SettingsGroup(title: "Java & memory") {
                SettingsRow(title: "Java", detail: "Runtime used to start the game.") {
                    MonoBadge(text: "Java 21")
                }
                VStack(spacing: 0) {
                    SettingsRow(title: "Memory", detail: "Ember keeps some memory free for the rest of your system.", isLast: true) {
                        MemoryStepper(memoryGB: $settings.memoryGB)
                    }
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        MemoryPresetsGrid(memoryGB: $settings.memoryGB)
                        Text(recommendedMemoryText)
                            .style(.init(size: 12.5, weight: .regular, color: Theme.textSecondary))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .background(Theme.surface)
                }
                .overlay(alignment: .bottom) {
                    Theme.border.frame(height: 1)
                }
                SettingsRow(title: "Window size", detail: "Game window size at launch.", isLast: true) {
                    HStack(spacing: 10) {
                        VoxelInput(label: "Window width", text: $settings.windowWidth, width: 90, alignment: .center)
                        Text(verbatim: "×").style(.init(size: 14, weight: .regular, color: Theme.muted))
                        VoxelInput(label: "Window height", text: $settings.windowHeight, width: 90, alignment: .center)
                    }
                }
            }

        case .downloads:
            SettingsGroup(title: "Downloads") {
                SettingsRow(title: "Show snapshots", detail: "Include snapshot versions in the list.", isLast: true) {
                    VoxelToggle(label: "Show snapshots", isOn: $settings.showSnapshots)
                }
            }

        case .ai:
            SettingsGroup(title: "AI") {
                SettingsRow(title: "AI provider", detail: "Builds pack suggestions from your description.") {
                    VoxelMenu(label: "AI provider", value: settings.aiProvider.displayName, minWidth: 150) {
                        ForEach(AIProviderKind.allCases, id: \.self) { kind in
                            Button(kind.displayName) { settings.aiProvider = kind }
                        }
                    }
                }
                SettingsRow(title: "API key", detail: "Your own key. Kept in the macOS Keychain.") {
                    AIKeyField()
                }
                SettingsRow(title: "AI model", detail: "Leave empty to use the default.", isLast: true) {
                    VoxelInput(label: "AI model", text: $settings.aiModel, width: 220, placeholder: settings.aiProvider.defaultModel)
                }
            }

        case .about:
            SettingsGroup(title: "About") {
                SettingsRow(title: L("Version %@", LauncherInfo.version), detail: updateDetail) {
                    SecondaryPill(title: updates.checkStatus == .checking ? "Checking…" : "Check for updates", action: updates.checkNow)
                }
                SettingsRow(title: "Update automatically", detail: "Keep the launcher up to date.", isLast: true) {
                    VoxelToggle(label: "Update automatically", isOn: $settings.autoUpdate)
                }
            }
        }
    }

    private func navButton(_ sec: SettingsSection, fillsWidth: Bool) -> some View {
        Button(action: { goTo(sec) }) {
            Text(tr: sec.rawValue)
                .style(.init(size: 13.5, weight: .medium, tracking: -0.01, color: activeSection == sec ? Theme.ember : Theme.textSecondary))
                .lineLimit(1)
                .padding(.vertical, 11)
                .padding(.horizontal, 13)
                .frame(maxWidth: fillsWidth ? CGFloat.infinity : nil, alignment: .leading)
                .background(activeSection == sec ? Theme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func goTo(_ sec: SettingsSection) {
        activeSection = sec
        isJumping = true
        jump = sec
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { isJumping = false }
    }

    /// The section whose top edge was passed last wins; the first one when none was.
    private func updateActive(_ tops: [SettingsSection: CGFloat]) {
        offsets = tops
        guard !isJumping else { return }
        let current = SettingsSection.allCases.last { (tops[$0] ?? .greatestFiniteMagnitude) <= 160 } ?? .general
        if current != activeSection { activeSection = current }
    }

    private var savedNote: some View {
        HStack(spacing: Theme.Space.xs) {
            Image(systemName: "checkmark.circle")
                .font(Theme.font(size: 12))
            Text(tr: "Changes save automatically")
                .style(.init(size: 12, weight: .regular, color: Theme.textMuted))
        }
        .foregroundColor(Theme.textMuted)
        .padding(.leading, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One section drawn like a page of its own; it fades in and rises as it comes into view.
    private func page(_ sec: SettingsSection, viewportHeight: CGFloat) -> some View {
        let top = offsets[sec] ?? (sec == .general ? 0 : .greatestFiniteMagnitude)
        let shown = !animates || top < viewportHeight - 80
        return VStack(alignment: .leading, spacing: Theme.Space.l) {
            sectionContent(sec)
            if sec == .about { savedNote.padding(.top, Theme.Space.s) }
        }
        .frame(maxWidth: .infinity, minHeight: max(viewportHeight - 40, 0), alignment: .topLeading)
        .opacity(shown ? 1 : 0.35)
        .offset(y: shown ? 0 : 14)
        .animation(animates ? .easeOut(duration: 0.35) : nil, value: shown)
        .id(sec)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: SectionOffsetKey.self, value: [sec: proxy.frame(in: .named(Self.scrollSpace)).minY])
            }
        )
    }

    private var sections: some View {
        GeometryReader { viewport in
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 48) {
                        ForEach(SettingsSection.allCases, id: \.self) { page($0, viewportHeight: viewport.size.height) }
                    }
                    .padding(.bottom, 40)
                }
                .coordinateSpace(name: Self.scrollSpace)
                .onPreferenceChange(SectionOffsetKey.self) { updateActive($0) }
                .onChange(of: jump) { _, target in
                    guard let target else { return }
                    withAnimation(animates ? .easeInOut(duration: 0.45) : nil) {
                        reader.scrollTo(target, anchor: .top)
                    }
                    jump = nil
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(eyebrow: "YOUR SPACE", title: "Settings", subtitle: "A few thoughtful choices to make Voxel feel like yours.", alignment: .leading)
                .padding(.bottom, 34)

            if windowWidth < 760 {
                VStack(alignment: .leading, spacing: 16) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(SettingsSection.allCases, id: \.self) { navButton($0, fillsWidth: false) }
                        }
                    }
                    sections
                }
            } else {
                HStack(alignment: .top, spacing: 32) {
                    VStack(spacing: 5) {
                        ForEach(SettingsSection.allCases, id: \.self) { navButton($0, fillsWidth: true) }
                    }
                    .frame(width: 190)

                    sections
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: 1120)
        .padding(.top, 40)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
    }
}
