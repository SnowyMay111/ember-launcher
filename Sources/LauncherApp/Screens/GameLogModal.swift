import AppKit
import LauncherCore
import SwiftUI

/// The game console: the log of the last run, followed live while the game runs, with the crash diagnosis above it.
struct GameLogModal: View {
    let name: String
    @EnvironmentObject var app: AppState
    @EnvironmentObject var player: PlayController
    @Local private var text = ""
    @Local private var copied = false

    private static let maxLines = 400

    private var logURL: URL {
        app.store.instanceDirectory(for: name).appendingPathComponent("launcher.log")
    }

    private var diagnosis: CrashDiagnosis? {
        player.diagnosisInstance == name ? player.diagnosis : nil
    }

    var body: some View {
        EmberModal(title: "Game log", width: 760) {
            VStack(alignment: .leading, spacing: 16) {
                if let diagnosis { DiagnosisBlock(diagnosis: diagnosis) }
                console
            }
        } footer: {
            SecondaryPill(title: "Open folder") { app.openFolder(name) }
            SecondaryPill(title: copied ? "Copied" : "Copy log") { copy() }
            PrimaryPill(title: "Close") { app.modal = nil }
                .keyboardShortcut(.cancelAction)
        }
    }

    private var console: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(verbatim: text.isEmpty ? L("No log yet. Press Play to start the game.") : text)
                    .style(.init(size: 12, weight: .regular, mono: true, tracking: 0, color: text.isEmpty ? Theme.muted : Theme.text))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                Color.clear.frame(height: 1).id("end")
            }
            .frame(height: diagnosis == nil ? 340 : 200)
            .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.black45))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
            .onChange(of: text) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
        }
        .task { await follow() }
    }

    /// Reads the log, then picks up whatever the game appends; starts over when a new run recreates the file.
    private func follow() async {
        var follower = LogFollower(url: logURL)
        var seenRun = player.runCount
        text = Self.clip(follower.poll())
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            if player.runCount != seenRun {
                seenRun = player.runCount
                follower = LogFollower(url: logURL)
                text = ""
            }
            let added = follower.poll()
            if !added.isEmpty { text = Self.clip(text + added) }
        }
    }

    /// Only the last lines are shown, so a chatty game cannot slow the window down; Copy log and Open folder reach the rest.
    private static func clip(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.count > maxLines ? lines.suffix(maxLines).joined(separator: "\n") : text
    }

    private func copy() {
        let full = GameLog.tail(of: logURL)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(full.isEmpty ? text : full, forType: .string)
        copied = true
    }
}

private struct DiagnosisBlock: View {
    let diagnosis: CrashDiagnosis

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr: "What went wrong").style(.eyebrow)
            Text(verbatim: diagnosis.kind.title).style(.cardTitle)
            if let culprit = diagnosis.culprit {
                Text(verbatim: L("Suspect: %@", culprit)).style(.row)
            }
            Text(verbatim: diagnosis.detail)
                .style(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: diagnosis.kind.advice)
                .style(.init(size: 14, weight: .regular, color: Theme.text))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.white04))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }
}
