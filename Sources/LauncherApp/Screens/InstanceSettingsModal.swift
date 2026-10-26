import LauncherCore
import SwiftUI

struct InstanceSettingsModal: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var player: PlayController

    let instance: LibraryInstance

    @Local private var name: String
    @Local private var group: String
    @Local private var memoryGB: Double
    @Local private var gcProfile: GCProfile
    @Local private var javaArgs: String
    @Local private var confirmingDelete = false
    @Local private var isCopying = false
    @Local private var errorText = ""

    init(instance: LibraryInstance) {
        self.instance = instance
        _name = Local(wrappedValue: instance.name)
        _group = Local(wrappedValue: instance.group)
        _memoryGB = Local(wrappedValue: Double(max(1, instance.memoryMB / 1024)))
        _gcProfile = Local(wrappedValue: instance.gcProfile)
        _javaArgs = Local(wrappedValue: instance.javaArgs.joined(separator: " "))
    }

    /// Up to the Mac's memory minus 2 GB for the system, at most 32 GB.
    private var memoryRange: ClosedRange<Double> {
        let installed = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        let top = min(32, max(2, installed - 2))
        return 1...Double(max(top, Int(memoryGB)))
    }

    var body: some View {
        VoxelModal(title: "Instance settings") {
            VStack(alignment: .leading, spacing: 18) {
                Text(verbatim: instance.versionLine).style(.secondary)

                ModalField(label: "Name") {
                    VoxelInput(label: "Name", text: $name)
                }
                ModalField(label: "Group") {
                    GroupPicker(group: $group)
                }
                ModalField(label: "Memory") {
                    VoxelSlider(label: "Memory", value: $memoryGB, range: memoryRange, valueText: L("%d GB", Int(memoryGB)))
                    Text(verbatim: memoryHint).style(.secondary)
                }
                ModalField(label: "Garbage collector") {
                    VoxelMenu(label: "Garbage collector", value: gcProfileTitle(gcProfile), minWidth: 160) {
                        ForEach([GCProfile.auto, .tunedG1GC, .zeroStutterZGC, .none], id: \.self) { profile in
                            Button(gcProfileTitle(profile)) {
                                gcProfile = profile
                            }
                        }
                    }
                    if gcProfile == .auto {
                        Text(verbatim: L("Automatic picks ZGC on Java 21+ with 16 GB or more, G1 otherwise.")).style(.secondary)
                    }
                }
                ModalField(label: "Java arguments") {
                    VoxelInput(label: "Java arguments", text: $javaArgs, placeholder: "-XX:+UseG1GC")
                }

                if confirmingDelete {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(verbatim: L("Move “%@” to the Trash? Its worlds and mods go with it.", instance.name))
                            .style(.init(size: 14, weight: .regular, color: Theme.text))
                        HStack(spacing: 10) {
                            SecondaryPill(title: "Keep it") { confirmingDelete = false }
                            PrimaryPill(title: "Move to Trash", action: trash)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        SecondaryPill(title: "Optimize") { app.modal = .optimize(instance.name) }
                        SecondaryPill(title: "Open folder") { app.openFolder(instance.name) }
                        SecondaryPill(title: isCopying ? "Copying…" : "Duplicate", action: duplicate)
                        SecondaryPill(title: "Delete") { confirmingDelete = true }
                    }
                }

                if !errorText.isEmpty {
                    Text(verbatim: errorText).style(.secondary)
                }
            }
        } footer: {
            ModalCancel()
            PrimaryPill(title: "Save", action: save)
        }
    }

    private func save() {
        let renaming = name.trimmingCharacters(in: .whitespacesAndNewlines) != instance.name
        guard !(renaming && player.isBusy) else {
            errorText = L("Close the game before renaming.")
            return
        }
        let chosen = group.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = chosen.isEmpty || chosen == GroupName.automatic(for: instance.loader) ? nil : chosen
        do {
            try app.updateInstance(
                instance.name,
                newName: name,
                memoryMB: Int(memoryGB) * 1024,
                gcProfile: gcProfile,
                javaArgs: javaArgs.split(whereSeparator: \.isWhitespace).map(String.init),
                group: saved
            )
            app.modal = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private var memoryHint: String {
        let recommendation = JVMArgumentsBuilder.memoryRecommendation(isModded: instance.loader != .vanilla)
        let memoryMB = Int(memoryGB * 1024)
        if memoryMB > recommendation.systemMemoryMB {
            return L("More than this Mac has: the game will swap and freeze.")
        } else if memoryMB > recommendation.overAllocationWarningThresholdMB {
            return L("Too much memory causes long garbage collector pauses and stutters.")
        } else {
            return L("Recommended: %d-%d GB", recommendation.recommendedRangeMB.lowerBound / 1024, recommendation.recommendedRangeMB.upperBound / 1024)
        }
    }

    private func gcProfileTitle(_ profile: GCProfile) -> String {
        switch profile {
        case .auto: return L("Automatic")
        case .tunedG1GC: return L("Balanced (G1)")
        case .zeroStutterZGC: return L("Low pause (ZGC)")
        case .none: return L("Launcher default")
        }
    }

    private func duplicate() {
        guard !isCopying else { return }
        isCopying = true
        errorText = ""
        Task {
            do {
                _ = try await app.duplicateInstance(instance.name)
                app.modal = nil
            } catch {
                errorText = error.localizedDescription
                isCopying = false
            }
        }
    }

    private func trash() {
        guard !player.isBusy else {
            errorText = L("Close the game first.")
            confirmingDelete = false
            return
        }
        do {
            try app.trashInstance(instance.name)
            app.modal = nil
        } catch {
            errorText = error.localizedDescription
            confirmingDelete = false
        }
    }
}
