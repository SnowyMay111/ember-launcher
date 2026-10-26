import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PageHeader(eyebrow: "Settings", title: "Preferences", subtitle: "Applies to every instance.")

                VStack(spacing: 0) {
                    SettingsRow(title: "Nickname", detail: "Name you play under. Offline mode.") {
                        VoxelInput(label: "Nickname", text: $settings.nickname, width: 220)
                    }
                    SettingsRow(title: "Memory", detail: "Maximum RAM given to the game.") {
                        VoxelSlider(label: "Memory", value: $settings.memoryGB, range: SettingsStore.memoryRange, valueText: settings.memoryText)
                    }
                    SettingsRow(title: "Java", detail: "Runtime used to start the game.") {
                        VoxelInput(label: "Java", text: $settings.java, width: 220)
                    }
                    SettingsRow(title: "Window size", detail: "Game window size at launch.") {
                        HStack(spacing: 10) {
                            VoxelInput(label: "Window width", text: $settings.windowWidth, width: 90, alignment: .center)
                            Text(verbatim: "×").style(.init(size: 14, weight: .regular, color: Theme.muted))
                            VoxelInput(label: "Window height", text: $settings.windowHeight, width: 90, alignment: .center)
                        }
                    }
                    SettingsRow(title: "Close launcher on start", detail: "Hide the launcher while you play.") {
                        VoxelToggle(label: "Close launcher on start", isOn: $settings.closeOnStart)
                    }
                    SettingsRow(title: "Show snapshots", detail: "Include snapshot versions in the list.") {
                        VoxelToggle(label: "Show snapshots", isOn: $settings.showSnapshots)
                    }
                    SettingsRow(title: "Update automatically", detail: "Keep the launcher up to date.", isLast: true) {
                        VoxelToggle(label: "Update automatically", isOn: $settings.autoUpdate)
                    }
                }
                .glass()
                .frame(maxWidth: 760)
                .padding(.top, 32)
            }
            .padding(.top, 40)
            .padding(.bottom, 40)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
        }
    }
}
