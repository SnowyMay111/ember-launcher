import SwiftUI
import LauncherCore

struct SettingsScreen: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var updates: UpdateController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.windowWidth) private var windowWidth

    enum Section: String, CaseIterable, Identifiable {
        case general = "General"
        case game = "Game"
        case server = "Server"
        case downloads = "Downloads"
        case appearance = "Appearance"
        case ai = "AI"
        case about = "About Ember"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .server: "server.rack"
            case .game: "gamecontroller"
            case .downloads: "arrow.down.circle"
            case .appearance: "paintpalette"
            case .ai: "sparkles"
            case .about: "info.circle"
            }
        }

        /// Cards of the section with the rows they hold: search looks through these titles.
        var cards: [(title: String, rows: [String])] {
            switch self {
            case .general: [("Player", ["Display name"]), ("Language", ["Language"]), ("Behavior", ["Automatic updates", "Close launcher after start"])]
            case .server: [("Hosting", ["Open Minecraft with my server", "Server in the menu bar", "Back up new servers"])]
            case .game: [("Java and memory", ["Java runtime", "Java path", "Java arguments", "Memory allocation"]), ("Game window", ["Window size"])]
            case .downloads: [("Files and network", ["Show snapshots", "Mod catalog"]), ("Storage", ["Data folder", "Game files", "Game versions and libraries", "Java runtimes"])]
            case .appearance: [("Atmosphere", ["Living background"])]
            case .ai: [("AI assistant", ["AI provider", "API key", "AI model", "Custom model ID"])]
            case .about: [("About Ember", ["Check for updates", "Automatic updates"])]
            }
        }

        func matches(_ query: String) -> Bool {
            SettingsSearch.matches(rawValue, query: query)
                || cards.contains { card in
                    SettingsSearch.matches(card.title, query: query) || card.rows.contains { SettingsSearch.matches($0, query: query) }
                }
        }
    }

    @Local private var selectedSection: Section = .general
    @Local private var query = ""

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

    /// The language the running app was started with; a different pick needs a restart.
    private var launchLanguage: String {
        localizer.language ?? (UserDefaults.standard.string(forKey: SettingsStore.appLanguageKey) == "en" ? "en" : "system")
    }

    private func languageName(_ code: String) -> String {
        switch code {
        case "en": "English"
        case "ru": "Русский"
        case "uk": "Українська"
        default: L("System")
        }
    }

    private func relaunch() {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "app" else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; open -n \"\(url.path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    private var visibleSections: [Section] {
        isSearching ? Section.allCases.filter { $0.matches(query) } : [selectedSection]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 28) {
                navigation
                    .frame(width: 210)

                VStack(alignment: .leading, spacing: 16) {
                    updateBanner
                    if visibleSections.isEmpty {
                        Text(verbatim: L("No settings match “%@”.", query))
                            .font(Theme.font(size: 13, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.top, 8)
                    }
                    ForEach(visibleSections) { section in
                        sectionBody(for: section)
                    }
                }
                .environment(\.settingsQuery, query)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: 1120, alignment: .topLeading)
            .padding(.top, 24)
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Navigation

    private var navigation: some View {
        VStack(alignment: .leading, spacing: 6) {
            EmberInput(label: "Search settings", text: $query, placeholder: L("Search settings"))
                .padding(.bottom, 8)
            ForEach(Section.allCases) { section in
                let isSelected = !isSearching && selectedSection == section
                let dimmed = isSearching && !section.matches(query)
                Button {
                    query = ""
                    withAnimation(.easeInOut(duration: 0.18)) { selectedSection = section }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.icon)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 20)
                            .foregroundColor(isSelected ? Theme.ember : Theme.textSecondary)
                        Text(tr: section.rawValue)
                            .font(Theme.font(size: 14, weight: .medium))
                            .foregroundColor(isSelected ? Theme.text : Theme.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? Theme.elevated : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Theme.lineStrong : Color.clear, lineWidth: 1)
                    )
                    .opacity(dimmed ? 0.35 : 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Update banner

    @ViewBuilder
    private var updateBanner: some View {
        if !isSearching, let text = updateBannerText {
            HStack(spacing: 14) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.ember)
                Text(verbatim: text)
                    .font(Theme.font(size: 14, weight: .medium))
                    .foregroundColor(Theme.text)
                Spacer(minLength: 12)
                if case .downloading(let fraction) = updates.state {
                    ProgressView(value: fraction).frame(width: 120).tint(Theme.ember)
                } else {
                    PrimaryPill(title: updates.state == .ready ? L("Restart") : L("Update"), height: 36, horizontalPadding: 22) {
                        updates.pillAction()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.ember.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.ember.opacity(0.45), lineWidth: 1))
            )
        }
    }

    private var updateBannerText: String? {
        switch updates.state {
        case .available(let info): return L("Version %@ is available.", info.version)
        case .downloading: return L("Downloading the update…")
        case .ready: return L("The update is ready.")
        case .idle, .failed: return nil
        }
    }

    // MARK: - Cards

    private func card<Content: View>(_ title: String, rows: [String], @ViewBuilder _ content: @escaping () -> Content) -> some View {
        SettingsCard(title: title, rows: rows, content: content)
    }

    // MARK: - Section Body

    @ViewBuilder
    private func sectionBody(for sec: Section) -> some View {
        switch sec {
        case .general:
            card("Player", rows: ["Display name"]) {
                SettingsRow(title: "Display name", detail: "Used for offline and local worlds.", isLast: true) {
                    EmberInput(label: "Nickname", text: $settings.nickname, width: 220)
                }
            }

            card("Language", rows: ["Language"]) {
                SettingsRow(title: "Language", detail: "Follows your Mac by default. Ember restarts to apply a change.", isLast: true) {
                    HStack(spacing: 10) {
                        EmberMenu(label: "Language", value: languageName(settings.appLanguage), minWidth: 160) {
                            ForEach(["system", "en", "ru", "uk"], id: \.self) { code in
                                Button(languageName(code)) { settings.appLanguage = code }
                            }
                        }
                        if settings.appLanguage != launchLanguage {
                            SecondaryPill(title: L("Restart"), height: 34) { relaunch() }
                        }
                    }
                }
            }

            card("Behavior", rows: ["Automatic updates", "Close launcher after start"]) {
                SettingsRow(title: "Automatic updates", detail: "Keep Ember and game metadata current.") {
                    EmberToggle(label: "Automatic updates", isOn: $settings.autoUpdate)
                }
                SettingsRow(title: "Close launcher after start", detail: "Save resources while Minecraft is running.", isLast: true) {
                    EmberToggle(label: "Close launcher on start", isOn: $settings.closeOnStart)
                }
            }

        case .server:
            card("Hosting", rows: ["Open Minecraft with my server", "Server in the menu bar", "Back up new servers"]) {
                SettingsRow(title: "Open Minecraft with my server", detail: "Join your own server as soon as it starts. Off: start the server first, then press Join when you want to play.") {
                    EmberToggle(label: "Open Minecraft with my server", isOn: $settings.joinOwnServer)
                }
                SettingsRow(title: "Server in the menu bar", detail: "Show an Ember icon with the server's status while it runs. The server keeps running when you close the window.") {
                    EmberToggle(label: "Server in the menu bar", isOn: $settings.serverMenuBar)
                }
                SettingsRow(title: "Back up new servers", detail: "New servers copy the world each time they stop. You can change it for every server in Servers.", isLast: true) {
                    EmberToggle(label: "Back up new servers", isOn: $settings.defaultServerBackup)
                }
            }

        case .game:
            card("Java and memory", rows: ["Java runtime", "Java path", "Java arguments", "Memory allocation"]) {
                SettingsRow(title: "Java runtime", detail: "Mojang Java 21 · Apple Silicon") {
                    MonoBadge(text: "Managed")
                }
                SettingsRow(title: "Java path", detail: "Use your own Java instead of the managed one. Leave empty for the managed one.") {
                    EmberInput(label: "Java path", text: $settings.javaPath, width: 260, placeholder: "/Library/Java/…/bin/java")
                }
                SettingsRow(title: "Java arguments", detail: "Added to every instance, separated by spaces. Instance settings can add more.") {
                    EmberInput(label: "Java arguments", text: $settings.globalJavaArgs, width: 260, placeholder: "-XX:+UseG1GC")
                }

                VStack(spacing: 0) {
                    SettingsRow(title: "Memory allocation", detail: "Ember keeps enough memory free for the rest of your Mac.", isLast: true) {
                        MemoryStepper(memoryGB: $settings.memoryGB)
                    }

                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        MemoryPresetsGrid(memoryGB: $settings.memoryGB)
                        Text(recommendedMemoryText)
                            .style(.init(size: 12, weight: .regular, color: Theme.textSecondary))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .background(Theme.surface)
                }
            }

            card("Game window", rows: ["Window size"]) {
                SettingsRow(title: "Window size", detail: "Game window size at launch.", isLast: true) {
                    HStack(spacing: 10) {
                        EmberInput(label: "Window width", text: $settings.windowWidth, width: 90, alignment: .center)
                        Text(verbatim: "×").style(.init(size: 14, weight: .regular, color: Theme.muted))
                        EmberInput(label: "Window height", text: $settings.windowHeight, width: 90, alignment: .center)
                    }
                }
            }

        case .downloads:
            card("Files and network", rows: ["Show snapshots", "Mod catalog"]) {
                SettingsRow(title: "Show snapshots", detail: "Include snapshot versions in the list.") {
                    EmberToggle(label: "Show snapshots", isOn: $settings.showSnapshots)
                }
                SettingsRow(title: "Mod catalog", detail: "Where Browse looks for mods and modpacks.", isLast: true) {
                    EmberMenu(label: "Mod catalog", value: settings.catalogSource.displayName, minWidth: 170) {
                        ForEach(CatalogSource.allCases, id: \.self) { source in
                            Button(source.displayName) { settings.catalogSource = source }
                        }
                    }
                }
            }

            card("Storage", rows: ["Data folder", "Game files", "Game versions and libraries", "Java runtimes"]) {
                StorageRows()
            }

        case .appearance:
            card("Atmosphere", rows: ["Living background"]) {
                SettingsRow(title: "Living background", detail: "Glows, particles and world ambience.", isLast: true) {
                    EmberToggle(label: "Background animations", isOn: $settings.backgroundAnimations)
                }
            }

        case .ai:
            card("AI assistant", rows: ["AI provider", "API key", "AI model", "Custom model ID"]) {
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
                SettingsRow(title: "AI model", detail: "Pick one from the list.") {
                    EmberMenu(label: "AI model", value: settings.aiModel.isEmpty ? L("Default") : settings.aiModel, minWidth: 220) {
                        Button(L("Default")) { settings.aiModel = "" }
                        ForEach(settings.aiProvider.suggestedModels, id: \.self) { model in
                            Button(model) { settings.aiModel = model }
                        }
                    }
                }
                SettingsRow(title: "Custom model ID", detail: "Any model id your provider offers. Leave empty to use the default.", isLast: true) {
                    EmberInput(label: "Custom model ID", text: $settings.aiModel, width: 220, placeholder: settings.aiProvider.defaultModel)
                }
            }

        case .about:
            card("About Ember", rows: ["Check for updates", "Automatic updates"]) {
                HStack(spacing: 18) {
                    EmberLogo(size: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "Ember \(LauncherInfo.version)")
                            .font(Theme.font(size: 16, weight: .bold))
                            .foregroundColor(Theme.text)
                        Text(tr: "A warm, native home for every Minecraft world.")
                            .font(Theme.font(size: 13, weight: .regular))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                .padding(22)
                .background(Theme.surface)
                .overlay(alignment: .bottom) { Theme.border.frame(height: 1) }

                SettingsRow(title: L("Version %@", LauncherInfo.version), detail: updateDetail) {
                    SecondaryPill(title: updates.checkStatus == .checking ? "Checking…" : "Check for updates", action: updates.checkNow)
                }

                SettingsRow(title: "Automatic updates", detail: "Keep the launcher up to date.", isLast: true) {
                    EmberToggle(label: "Update automatically", isOn: $settings.autoUpdate)
                }
            }
        }
    }
}

/// Group of settings rows under a sentence-case title; hides itself when the search matches none of its rows.
struct SettingsCard<Content: View>: View {
    let title: String
    let rows: [String]
    @ViewBuilder var content: () -> Content
    @Environment(\.settingsQuery) private var query

    var body: some View {
        if SettingsSearch.matches(title, query: query) || rows.contains(where: { SettingsSearch.matches($0, query: query) }) {
            VStack(alignment: .leading, spacing: 0) {
                Text(tr: title)
                    .font(Theme.font(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .overlay(alignment: .bottom) { Theme.border.frame(height: 1) }
                content()
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            .glass()
        }
    }
}

extension CatalogSource {
    var displayName: String {
        switch self {
        case .both: return L("Modrinth + CurseForge")
        case .modrinth: return L("Modrinth only")
        case .curseforge: return L("CurseForge only")
        }
    }
}

/// Where Ember keeps its files and how much room each part takes.
private struct StorageRows: View {
    @EnvironmentObject var app: AppState
    @Local private var sizes: [String: Int64] = [:]

    var body: some View {
        SettingsRow(title: "Data folder", detail: app.paths.root.path) {
            SecondaryPill(title: L("Show in Finder"), height: 34) { NSWorkspace.shared.open(app.paths.root) }
        }
        .task { await measure() }
        sizeRow("Game files", "Worlds, mods and settings of your instances.", key: "instances")
        sizeRow("Game versions and libraries", "Downloaded Minecraft versions, libraries and assets. Re-downloaded when needed.", key: "versions")
        sizeRow("Java runtimes", "Java downloaded by Ember.", key: "runtimes", isLast: true)
    }

    private func sizeRow(_ title: String, _ detail: String, key: String, isLast: Bool = false) -> some View {
        SettingsRow(title: title, detail: detail, isLast: isLast) {
            Text(verbatim: sizes[key].map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "…")
                .font(Theme.font(size: 13, weight: .medium))
                .foregroundColor(Theme.text)
        }
    }

    private func measure() async {
        let paths = app.paths
        let result = await Task.detached {
            [
                "instances": DiskUsage.size(of: paths.instances),
                "versions": DiskUsage.size(of: paths.versions) + DiskUsage.size(of: paths.libraries) + DiskUsage.size(of: paths.assetsRoot),
                "runtimes": DiskUsage.size(of: paths.runtimes),
            ]
        }.value
        sizes = result
    }
}
