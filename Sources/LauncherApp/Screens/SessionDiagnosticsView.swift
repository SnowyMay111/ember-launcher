import LauncherCore
import SwiftUI

struct SessionDiagnosticsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var player: PlayController
    let instance: LibraryInstance

    @Local private var errorText = ""

    private var report: SessionHealthReport? {
        if player.healthInstance == instance.name {
            return player.health
        }
        return nil
    }

    private var smoothnessColor: Color {
        guard let report, report.isConclusive else { return Theme.muted }
        if report.smoothnessScore >= 90 { return .green }
        if report.smoothnessScore >= 70 { return .yellow }
        return .red
    }

    private var smoothnessCaption: String {
        guard let report, report.isConclusive else {
            return L("Not enough data yet. Play at least 2 minutes.")
        }
        if report.smoothnessScore >= 90 { return L("Perfect smoothness") }
        if report.smoothnessScore >= 70 { return L("Some micro-freezes") }
        return L("Lags detected")
    }

    var body: some View {
        VoxelModal(title: "Session health", width: 680) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    headerRing
                    metricsRow
                    diagnosisBlock

                    if let error = player.fixError, !error.isEmpty {
                        Text(verbatim: error).style(.secondary)
                    }

                    if !errorText.isEmpty {
                        Text(verbatim: errorText).style(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 380)
        } footer: {
            ModalCancel(title: "Close")
            if let report, report.isConclusive, !report.oneClickFixes.isEmpty {
                PrimaryPill(
                    title: "Fix automatically in 1 click",
                    isDisabled: player.isBusy || player.fixProgress != nil
                ) {
                    player.applyHealthFixes(report.oneClickFixes, instanceName: instance.name, app: app)
                }
            }
        }
        .task {
            if player.healthInstance != instance.name || player.health == nil {
                player.loadLastReport(for: instance.name)
            }
        }
    }

    private var headerRing: some View {
        let isConclusive = report?.isConclusive == true
        let score = report?.smoothnessScore ?? 0

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Theme.white10, lineWidth: 10)
                if isConclusive {
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100.0)
                        .stroke(smoothnessColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: score)
                }
                Text(verbatim: isConclusive ? "\(score)" : "–")
                    .style(.init(size: 28, weight: .bold, color: Theme.ink))
            }
            .frame(width: 96, height: 96)

            Text(verbatim: smoothnessCaption)
                .style(.init(size: 13, weight: .medium, color: smoothnessColor))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var metricsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                memoryFreezeCard
                worldLoadCard
                ramJavaCard
            }
            VStack(spacing: 10) {
                memoryFreezeCard
                worldLoadCard
                ramJavaCard
            }
        }
    }

    private var memoryFreezeCard: some View {
        let text: String
        if let report {
            let maxPause = String(Int(report.maxGcPauseMs.rounded()))
            text = L("%d freezes (max %@ ms)", report.gcMicroFreezesCount, maxPause)
        } else {
            text = "–"
        }
        return MetricCard(icon: "memorychip", title: "Memory freezes (GC)", value: text)
    }

    private var worldLoadCard: some View {
        let text: String
        if let report {
            if report.maxTickBehindMs > 0 {
                text = L("%d tick drops (max %d ms)", report.serverTickDropsCount, report.maxTickBehindMs)
            } else {
                text = L("%d tick drops", report.serverTickDropsCount)
            }
        } else {
            text = "–"
        }
        return MetricCard(icon: "cube.transparent", title: "World load (chunks/mobs)", value: text)
    }

    private var ramJavaCard: some View {
        let text: String
        if let report {
            let gb = max(1, report.allocatedMemoryMB / 1024)
            let archText: String
            switch report.javaArchitecture {
            case .arm64Native: archText = "ARM64 Native"
            case .rosetta: archText = "Rosetta (x86_64)"
            case .unknown: archText = "unknown"
            default: archText = "x86_64"
            }
            text = "\(gb) GB · \(archText) · \(report.gcProfile)"
        } else {
            let gb = max(1, instance.memoryMB / 1024)
            text = "\(gb) GB"
        }
        return MetricCard(icon: "cpu", title: "RAM & Java", value: text)
    }

    private var diagnosisBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr: "Diagnosis and fix").style(.eyebrow)

            if let report {
                if report.isConclusive && report.detectedIssues.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(tr: "The build runs perfectly, no micro-freezes recorded.")
                            .style(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.white04))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                } else if !report.detectedIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(report.detectedIssues, id: \.code) { issue in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(severityColor(issue.severity))
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 5)
                                Text(verbatim: issue.localizedDescription)
                                    .style(.init(size: 13, weight: .regular, color: Theme.text))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.white04))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                }

                if report.isConclusive && !report.oneClickFixes.isEmpty {
                    fixesActionSection(report.oneClickFixes)
                }

                if let fixReport = player.lastFixReport {
                    fixResultSummary(fixReport)
                }
            } else {
                Text(tr: "Not enough data yet. Play at least 2 minutes.").style(.secondary)
            }
        }
    }

    private func fixesActionSection(_ fixes: [AutoFixAction]) -> some View {
        let summary = fixes.map { $0.localizedTitle(refreshRate: player.displayRefreshRate) }.joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: summary)
                .style(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let progress = player.fixProgress {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.white)
                    if !player.fixLabel.isEmpty {
                        Text(verbatim: player.fixLabel)
                            .style(.eyebrow)
                    }
                }
            }

            if player.isBusy {
                Text(tr: "Close the game first.").style(.secondary)
            }
        }
    }

    private func fixResultSummary(_ report: AutoFixReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr: "Result").style(.eyebrow)
            Text(verbatim: L("Fixed issues: %d", report.applied.count))
                .style(.init(size: 13, weight: .medium, color: .green))

            if !report.skipped.isEmpty {
                ForEach(report.skipped, id: \.reason) { item in
                    Text(verbatim: L("Skipped: %@", item.reason))
                        .style(.secondary)
                }
            }

            Text(tr: "Changes apply the next time you start the game.")
                .style(.secondary)

            if let backup = report.backupPath {
                Text(verbatim: L("Backup saved to %@", backup))
                    .style(.eyebrow)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.black45))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
    }

    private func severityColor(_ severity: DiagnosticSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .yellow
        case .info: return Theme.muted
        }
    }
}

private struct MetricCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.muted)
                Text(tr: title)
                    .style(.eyebrow)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(verbatim: value)
                .style(.init(size: 14, weight: .semibold, color: Theme.ink))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.white04))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }
}
