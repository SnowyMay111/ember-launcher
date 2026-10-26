import LauncherCore
import SwiftUI

private enum OptimizationSession {
    static var preset: OptimizationPreset = .maxFPS_PvP
    static var enableShaders = false
    static var enableLoD = false
    static var enableFrameGen = false
}

struct OptimizationModal: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var player: PlayController

    let instance: LibraryInstance

    @Local private var preset: OptimizationPreset
    @Local private var enableShaders: Bool
    @Local private var enableLoD: Bool
    @Local private var enableFrameGen: Bool
    @Local private var lockFps: Bool
    @Local private var isInstalling = false
    @Local private var report: OptimizationApplyReport?
    @Local private var errorText = ""

    init(instance: LibraryInstance) {
        self.instance = instance
        _preset = Local(wrappedValue: OptimizationSession.preset)
        _enableShaders = Local(wrappedValue: OptimizationSession.enableShaders)
        _enableLoD = Local(wrappedValue: OptimizationSession.enableLoD)
        _enableFrameGen = Local(wrappedValue: OptimizationSession.enableFrameGen)
        _lockFps = Local(wrappedValue: instance.lockFpsToMonitor)
    }

    private var plan: OptimizationPlan {
        let loader = OptimizationLoader(instanceLoader: instance.loader.rawValue) ?? .fabric
        let context = OptimizationContext(
            mcVersion: instance.minecraftVersion,
            loader: loader,
            os: .current,
            preset: preset,
            enableShaders: enableShaders,
            enableLoD: enableLoD,
            enableFrameGen: enableFrameGen
        )
        return OptimizationRuleEngine.plan(for: context)
    }

    var body: some View {
        VoxelModal(title: "Optimize", width: 560) {
            VStack(alignment: .leading, spacing: 18) {
                Text(verbatim: instance.versionLine).style(.secondary)

                if instance.loader != .fabric {
                    Text(tr: "Optimization needs the Fabric loader.").style(.secondary)
                } else if player.isBusy {
                    Text(tr: "Close the game first.").style(.secondary)
                } else {
                    ModalField(label: "Preset") {
                        VoxelMenu(label: "Preset", value: presetTitle(preset), minWidth: 200) {
                            ForEach(OptimizationPreset.allCases, id: \.self) { item in
                                Button(presetTitle(item)) {
                                    preset = item
                                    OptimizationSession.preset = item
                                }
                            }
                        }
                    }

                    HStack(spacing: 20) {
                        ModalField(label: "Shaders") {
                            VoxelToggle(label: "Shaders", isOn: Binding(
                                get: { enableShaders },
                                set: {
                                    enableShaders = $0
                                    OptimizationSession.enableShaders = $0
                                }
                            ))
                        }
                        ModalField(label: "Distant chunks (LoD)") {
                            VoxelToggle(label: "Distant chunks (LoD)", isOn: Binding(
                                get: { enableLoD },
                                set: {
                                    enableLoD = $0
                                    OptimizationSession.enableLoD = $0
                                }
                            ))
                        }
                        ModalField(label: "Frame generation") {
                            VStack(alignment: .leading, spacing: 4) {
                                VoxelToggle(label: "Frame generation", isOn: Binding(
                                    get: { enableFrameGen },
                                    set: {
                                        enableFrameGen = $0
                                        OptimizationSession.enableFrameGen = $0
                                    }
                                ))
                                .disabled(OptimizationOS.current == .macOS)
                            }
                        }
                    }

                    if OptimizationOS.current == .macOS {
                        Text(tr: "Frame generation is not available on macOS.").style(.secondary)
                    }

                    ModalField(label: "Lock FPS to the screen refresh rate") {
                        VoxelToggle(label: "Lock FPS to the screen refresh rate", isOn: Binding(
                            get: { lockFps },
                            set: { newValue in
                                lockFps = newValue
                                try? app.setLockFps(instance.name, newValue)
                            }
                        ))
                    }

                    previewSection

                    if let report {
                        reportSection(report)
                    }

                    if !errorText.isEmpty {
                        Text(verbatim: errorText).style(.secondary)
                    }
                }
            }
        } footer: {
            ModalCancel()
            if instance.loader == .fabric && !player.isBusy {
                PrimaryPill(title: isInstalling ? "Installing…" : "Install", action: install)
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr: "Preview").style(.eyebrow)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !plan.slugs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tr: "Will install").style(.init(size: 13, weight: .bold, color: Theme.text))
                            Text(verbatim: plan.slugs.map(prettifySlug).joined(separator: ", "))
                                .style(.secondary)
                        }
                    }

                    if !plan.blocked.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tr: "Will not install").style(.init(size: 13, weight: .bold, color: Theme.text))
                            ForEach(plan.blocked, id: \.slug) { item in
                                Text(verbatim: "\(prettifySlug(item.slug)): \(item.localizedReason)")
                                    .style(.secondary)
                            }
                        }
                    }

                    if !plan.notices.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tr: "Notices").style(.init(size: 13, weight: .bold, color: Theme.text))
                            ForEach(plan.notices, id: \.code) { notice in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(verbatim: notice.kind == .warning ? "⚠️" : "ℹ️")
                                    Text(verbatim: notice.localizedMessage)
                                        .style(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.black45))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
            }
            .frame(maxHeight: 160)
        }
    }

    private func reportSection(_ report: OptimizationApplyReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr: "Result").style(.eyebrow)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: L("Installed: %d", report.installed.count)).style(.secondary)
                if !report.alreadyInstalled.isEmpty {
                    Text(verbatim: L("Already installed: %d", report.alreadyInstalled.count)).style(.secondary)
                }
                if !report.skippedNoVersion.isEmpty {
                    Text(verbatim: L("No compatible version: %@", report.skippedNoVersion.map(prettifySlug).joined(separator: ", "))).style(.secondary)
                }
                if !report.failed.isEmpty {
                    Text(verbatim: L("Failed: %@", report.failed.map { "\($0.slug) (\($0.message))" }.joined(separator: ", "))).style(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).fill(Theme.black45))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous).strokeBorder(Theme.lineStrong, lineWidth: 1))
        }
    }

    private func presetTitle(_ preset: OptimizationPreset) -> String {
        switch preset {
        case .maxFPS_PvP: return L("Max FPS (PvP)")
        case .balancedLoD: return L("Balanced + LoD")
        case .shadersVisual: return L("Shaders & visuals")
        case .heavyModpack: return L("Heavy modpack")
        }
    }

    private func prettifySlug(_ slug: String) -> String {
        slug.split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func install() {
        guard !player.isBusy else {
            errorText = L("Close the game first.")
            return
        }
        guard !isInstalling else { return }
        isInstalling = true
        errorText = ""
        report = nil

        let currentPlan = plan
        let instanceName = instance.name
        let lockFpsValue = lockFps
        Task {
            do {
                try app.setLockFps(instanceName, lockFpsValue)
                let modManager = ModManager(store: app.store)
                let installer = OptimizationInstaller(modManager: modManager)
                let result = try await installer.apply(currentPlan, to: instanceName)
                report = result
                isInstalling = false
                app.reload()
            } catch {
                errorText = error.localizedDescription
                isInstalling = false
            }
        }
    }
}
