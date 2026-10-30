import SwiftUI
import LauncherCore

struct SettingsScreen: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var updates: UpdateController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.windowWidth) private var windowWidth

    enum Section: String, CaseIterable, Identifiable {
        case general = "General"
        case java = "Java & memory"
        case downloads = "Downloads"
        case appearance = "Appearance"
        case ai = "AI"
        case about = "About Ember"

        var id: String { rawValue }

        var tag: String {
            switch self {
            case .general: "GENERAL"
            case .java: "JAVA & MEMORY"
            case .downloads: "DOWNLOADS"
            case .appearance: "APPEARANCE"
            case .ai: "AI ASSISTANT"
            case .about: "ABOUT EMBER"
            }
        }

        var headline: String {
            switch self {
            case .general: "Everything feels good."
            case .java: "Runtime is balanced."
            case .downloads: "Ready when you are."
            case .appearance: "Make it feel like home."
            case .ai: "Ready to create."
            case .about: "Ember \(LauncherInfo.version)"
            }
        }

        var description: String {
            switch self {
            case .general: "Your profile, worlds, and launcher behavior in one calm place."
            case .java: "Java 21 is healthy and memory is balanced for this Mac."
            case .downloads: "Choose where game files live and how quietly they arrive."
            case .appearance: "Tune motion and atmosphere without changing how Ember works."
            case .ai: "Build pack suggestions and mod setups tailored to your play."
            case .about: "A warm, native home for every Minecraft world."
            }
        }
    }

    @Local private var selectedSection: Section = .general

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

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                PageHeader(
                    eyebrow: "YOUR SPACE",
                    title: "Settings",
                    subtitle: "A few thoughtful choices to make Ember feel like yours.",
                    alignment: .leading
                )
                .padding(.bottom, 28)

                // Split layout
                HStack(alignment: .top, spacing: 28) {
                    // Navigation sidebar
                    VStack(spacing: 6) {
                        ForEach(Section.allCases) { sec in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedSection = sec
                                }
                            } label: {
                                HStack {
                                    Text(tr: sec.rawValue)
                                        .font(Theme.font(size: 13, weight: .medium))
                                        .foregroundColor(selectedSection == sec ? Theme.ember : Theme.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedSection == sec ? Color(red: 24/255, green: 21/255, blue: 20/255) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedSection == sec ? Color(red: 60/255, green: 48/255, blue: 40/255) : Color.clear, lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 190)

                    // Main content
                    VStack(alignment: .leading, spacing: 18) {
                        // Comfort card (only for sections other than about, which has its own unified card)
                        if selectedSection != .about {
                            comfortCard(for: selectedSection)
                        }

                        // Section body
                        sectionBody(for: selectedSection)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: 1120, alignment: .topLeading)
            .padding(.top, 36)
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Comfort Card

    private func comfortCard(for sec: Section) -> some View {
        HStack(spacing: 18) {
            // Orb
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 170/255, green: 103/255, blue: 191/255).opacity(0.22),
                                Color(red: 229/255, green: 139/255, blue: 78/255).opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 171/255, green: 115/255, blue: 195/255),
                                Color(red: 233/255, green: 154/255, blue: 97/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(45))
                    .shadow(color: Theme.ember.opacity(0.3), radius: 10)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(sec.tag)
                    .font(Theme.font(size: 9, weight: .medium, mono: true))
                    .tracking(1.4)
                    .foregroundColor(Color(red: 142/255, green: 105/255, blue: 126/255))

                Text(sec.headline)
                    .font(Theme.font(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)

                Text(sec.description)
                    .font(Theme.font(size: 11, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Circle()
                .fill(Color(red: 32/255, green: 39/255, blue: 25/255))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(Theme.font(size: 11, weight: .bold))
                        .foregroundColor(Theme.success)
                )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 15)
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
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color(red: 58/255, green: 45/255, blue: 55/255), lineWidth: 1)
        )
    }

    // MARK: - Section Body

    @ViewBuilder
    private func sectionBody(for sec: Section) -> some View {
        switch sec {
        case .general:
            SettingsGroup(title: "PLAYER") {
                SettingsRow(title: "Display name", detail: "Used for offline and local worlds.") {
                    EmberInput(label: "Nickname", text: $settings.nickname, width: 220)
                }
            }

            SettingsGroup(title: "BEHAVIOR") {
                SettingsRow(title: "Automatic updates", detail: "Keep Ember and game metadata current.") {
                    EmberToggle(label: "Automatic updates", isOn: $settings.autoUpdate)
                }
                SettingsRow(title: "Close launcher after start", detail: "Save resources while Minecraft is running.", isLast: true) {
                    EmberToggle(label: "Close launcher on start", isOn: $settings.closeOnStart)
                }
            }

        case .java:
            SettingsGroup(title: "PERFORMANCE") {
                SettingsRow(title: "Java runtime", detail: "Mojang Java 21 · Apple Silicon") {
                    MonoBadge(text: "Managed")
                }

                VStack(spacing: 0) {
                    SettingsRow(title: "Memory allocation", detail: "Ember keeps enough memory free for the rest of your Mac.", isLast: true) {
                        MemoryStepper(memoryGB: $settings.memoryGB)
                    }

                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        MemoryPresetsGrid(memoryGB: $settings.memoryGB)
                        Text(recommendedMemoryText)
                            .style(.init(size: 11.5, weight: .regular, color: Theme.textSecondary))
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
                        EmberInput(label: "Window width", text: $settings.windowWidth, width: 90, alignment: .center)
                        Text(verbatim: "×").style(.init(size: 14, weight: .regular, color: Theme.muted))
                        EmberInput(label: "Window height", text: $settings.windowHeight, width: 90, alignment: .center)
                    }
                }
            }

        case .downloads:
            SettingsGroup(title: "FILES & NETWORK") {
                SettingsRow(title: "Show snapshots", detail: "Include snapshot versions in the list.", isLast: true) {
                    EmberToggle(label: "Show snapshots", isOn: $settings.showSnapshots)
                }
            }

        case .appearance:
            SettingsGroup(title: "ATMOSPHERE") {
                SettingsRow(title: "Living background", detail: "Glows, particles and world ambience.", isLast: true) {
                    EmberToggle(label: "Background animations", isOn: $settings.backgroundAnimations)
                }
            }

        case .ai:
            SettingsGroup(title: "AI ASSISTANT") {
                SettingsRow(title: "AI provider", detail: "Builds pack suggestions from your description.") {
                    EmberMenu(label: "AI provider", value: settings.aiProvider.displayName, minWidth: 150) {
                        ForEach(AIProviderKind.allCases, id: \.self) { kind in
                            Button(kind.displayName) { settings.aiProvider = kind }
                        }
                    }
                }
                SettingsRow(title: "API key", detail: "Your own key. Kept safely in the macOS Keychain.") {
                    AIKeyField()
                }
                SettingsRow(title: "AI model", detail: "Leave empty to use the default.", isLast: true) {
                    EmberInput(label: "AI model", text: $settings.aiModel, width: 220, placeholder: settings.aiProvider.defaultModel)
                }
            }

        case .about:
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 18) {
                    EmberLogo(size: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "ABOUT EMBER")
                            .font(Theme.font(size: 9, weight: .medium, mono: true))
                            .tracking(1.4)
                            .foregroundColor(Color(red: 142/255, green: 105/255, blue: 126/255))

                        Text(verbatim: "Ember \(LauncherInfo.version)")
                            .font(Theme.font(size: 16, weight: .bold))
                            .foregroundColor(Theme.text)

                        Text(verbatim: "A warm, native home for every Minecraft world.")
                            .font(Theme.font(size: 12, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer()

                    Circle()
                        .fill(Color(red: 32/255, green: 39/255, blue: 25/255))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(Theme.font(size: 11, weight: .bold))
                                .foregroundColor(Theme.success)
                        )
                }
                .padding(22)

                Divider().background(Theme.border)

                SettingsRow(title: L("Version %@", LauncherInfo.version), detail: updateDetail) {
                    SecondaryPill(title: updates.checkStatus == .checking ? "Checking…" : "Check for updates", action: updates.checkNow)
                }

                SettingsRow(title: "Automatic updates", detail: "Keep the launcher up to date.", isLast: true) {
                    EmberToggle(label: "Update automatically", isOn: $settings.autoUpdate)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            .glass()
        }
    }
}
