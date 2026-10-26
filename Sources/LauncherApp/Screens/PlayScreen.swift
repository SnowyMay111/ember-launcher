import SwiftUI

struct PlayScreen: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        if let item = app.current {
            VStack(spacing: 0) {
                CubeIcon()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.white.opacity(0.4), radius: 22)
                    .accessibilityHidden(true)

                Text(verbatim: L("Last played") + " · " + item.lastPlayedAgo)
                    .style(.eyebrow)
                    .padding(.top, 26)

                VStack(spacing: -12) {
                    Text(verbatim: item.name).style(.hero)
                    GradientText(
                        text: item.versionLine,
                        style: .hero,
                        gradient: LinearGradient(colors: [Color(white: 0.878), Theme.muted], startPoint: .top, endPoint: .bottom)
                    )
                }
                .padding(.top, 14)

                Text(verbatim: L("%d mods · %@ played", item.modCount, item.playtimeText))
                    .style(.body16)
                    .padding(.top, 14)

                HStack(spacing: 12) {
                    PrimaryPill(title: "Play", showsPlay: true)
                    SecondaryPill(title: "Instance settings")
                }
                .padding(.top, 26)

                Spacer(minLength: 24)

                HStack(spacing: 12) {
                    StatCard(label: "Mods", value: "\(item.modCount)")
                    StatCard(label: "Playtime", value: item.playtimeText)
                    StatCard(label: "Memory", value: settings.memoryText)
                }
                .frame(maxWidth: 880)
            }
            .padding(.top, 36)
            .padding(.bottom, 28)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
        }
    }
}
