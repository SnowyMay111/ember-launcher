import SwiftUI

enum HomeLaunchPlayState { case idle, launching, ready }

private func homeHex(_ value: UInt32, opacity: Double = 1) -> Color {
    Color(
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255,
        opacity: opacity
    )
}

/// The dark rounded card behind the version select and the settings button: hover, keyboard focus and press looks.
private struct HomeLaunchCard<Content: View>: View {
    let hoverTint: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Local private var hovering = false

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(hovering ? homeHex(hoverTint ? 0x171513 : 0x151514) : homeHex(0x111110))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(hovering ? homeHex(hoverTint ? 0x39322e : 0x302e2b) : homeHex(0x222220), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Theme.ember.opacity(0.7), lineWidth: isFocused ? 2 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5)
            .onHover { hovering = $0 && isEnabled }
            .animation(.easeOut(duration: 0.2), value: hovering)
    }
}

/// Press feedback only: the card draws its own hover, focus and background.
private struct HomeLaunchPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct HomeLaunchPanel<MenuContent: View>: View {
    typealias PlayState = HomeLaunchPlayState

    let versionName: String
    let playState: PlayState
    let playTitle: String
    let playSubtitle: String
    let isDisabled: Bool
    let onPlay: () -> Void
    let onSettings: () -> Void
    let versionMenu: () -> MenuContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var isFocused
    @Local private var playHovering = false
    @Local private var pulse = false

    init(
        versionName: String,
        playState: PlayState,
        playTitle: String,
        playSubtitle: String,
        isDisabled: Bool,
        onPlay: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        @ViewBuilder versionMenu: @escaping () -> MenuContent
    ) {
        self.versionName = versionName
        self.playState = playState
        self.playTitle = playTitle
        self.playSubtitle = playSubtitle
        self.isDisabled = isDisabled
        self.onPlay = onPlay
        self.onSettings = onSettings
        self.versionMenu = versionMenu
    }

    var body: some View {
        GeometryReader { geo in
            let first = (geo.size.width - 28 - 64) / 2.05
            HStack(spacing: 14) {
                versionSelect.frame(width: first, height: 78)
                settingsButton.frame(width: 64, height: 78)
                playButton.frame(width: first * 1.05, height: 78)
            }
        }
        .frame(height: 78)
    }

    private var versionSelect: some View {
        EmberDropdown(minWidth: 340, content: versionMenu) { _ in
            HomeLaunchCard(hoverTint: false) {
                HStack(spacing: 16) {
                    ZStack(alignment: .bottom) {
                        Rectangle().fill(homeHex(0x22201d)).frame(width: 36, height: 36)
                        ZStack(alignment: .bottom) {
                            Rectangle().fill(homeHex(0x706d4f))
                            Rectangle().fill(homeHex(0x42442d)).frame(height: 5)
                        }
                        .frame(width: 14, height: 14)
                        .frame(width: 36, height: 36)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(verbatim: L("Version"))
                            .font(Theme.font(size: 12, weight: .medium))
                            .foregroundColor(homeHex(0x6f6b65))
                        Text(verbatim: versionName)
                            .font(Theme.font(size: 12, weight: .semibold))
                            .foregroundColor(homeHex(0xe8e3dc))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(homeHex(0x77726d))
                }
                .padding(.horizontal, 22)
            }
        }
        .accessibilityLabel("Version")
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            HomeLaunchCard(hoverTint: true) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(homeHex(0x77726d))
            }
        }
        .buttonStyle(HomeLaunchPressStyle())
        .accessibilityLabel("Instance settings")
        .help("Instance settings")
    }

    private var ink: Color { homeHex(0x1b110a) }

    private var playButton: some View {
        Button(action: onPlay) {
            HStack(spacing: 17) {
                ZStack {
                    Circle().strokeBorder(homeHex(0x301b0e, opacity: 0.28), lineWidth: 1)
                    Image(systemName: playState == .idle ? "play.fill" : "arrow.down")
                        .font(.system(size: playState == .idle ? 11 : 13, weight: .bold))
                        .foregroundColor(ink)
                        .opacity(playState == .launching && pulse ? 0.35 : 1)
                        .offset(y: playState == .launching && pulse ? 2 : 0)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: playTitle)
                        .font(Theme.font(size: 15, weight: .semibold))
                        .foregroundColor(ink)
                    Text(verbatim: playSubtitle)
                        .font(Theme.font(size: 12, weight: .medium))
                        .foregroundColor(homeHex(0x23150c, opacity: 0.58))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(playBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(playState == .ready ? homeHex(0xc9cda0) : Theme.ember, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.35), .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.25)),
                        lineWidth: 1
                    )
                    .padding(1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.8), lineWidth: isFocused ? 2 : 0)
            )
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .shadow(color: Theme.ember.opacity(0.16), radius: playHovering ? 42 : 34, y: playHovering ? 15 : 10)
        .offset(y: playHovering && !reduceMotion && !isDisabled ? -2 : 0)
        .onHover { playHovering = $0 }
        .animation(.easeOut(duration: 0.2), value: playHovering)
        .onAppear(perform: syncPulse)
        .onChange(of: playState) { _ in syncPulse() }
        .accessibilityLabel(Text(verbatim: playTitle))
    }

    @ViewBuilder private var playBackground: some View {
        if playState == .ready {
            RoundedRectangle(cornerRadius: 15, style: .continuous).fill(homeHex(0xb4b885))
        } else {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(LinearGradient(colors: [Theme.ember, Theme.emberDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private func syncPulse() {
        guard playState == .launching, !reduceMotion else {
            withAnimation(nil) { pulse = false }
            return
        }
        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
    }
}
