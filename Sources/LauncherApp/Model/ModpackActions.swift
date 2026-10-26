import AppKit
import LauncherCore
import UniformTypeIdentifiers

/// .mrpack export and import: the file panels, then `LauncherCore.ModpackManager` does the work.
extension AppState {
    private static let mrpackType = UTType(filenameExtension: "mrpack") ?? .zip

    /// Asks where to save, then writes the pack. Returns nil when the panel is cancelled.
    func exportPack(_ name: String) async throws -> MrpackExportReport? {
        let panel = NSSavePanel()
        panel.title = L("Export .mrpack")
        panel.allowedContentTypes = [Self.mrpackType]
        panel.nameFieldStringValue = "\(name).mrpack"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return try await ModpackManager(store: store).export(instance: name, to: url)
    }

    /// Lets the user pick a .mrpack file; nil when cancelled.
    func chooseMrpack() -> URL? {
        let panel = NSOpenPanel()
        panel.title = L("Import .mrpack")
        panel.allowedContentTypes = [Self.mrpackType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Reads the pack's name, versions and size without installing anything.
    func inspectPack(_ url: URL) async throws -> MrpackSummary {
        let store = self.store
        return try await Task.detached { try ModpackManager(store: store).inspect(url) }.value
    }

    /// Creates the instance from the pack, selects it and returns what was installed.
    func importPack(
        _ url: URL,
        name: String,
        group: String?,
        memoryMB: Int,
        progress: @escaping @Sendable (String, Double) -> Void
    ) async throws -> MrpackImportReport {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let report = try await ModpackManager(store: store).importPack(
            from: url,
            name: trimmed.isEmpty ? nil : trimmed,
            group: group,
            memoryMB: memoryMB,
            progress: progress
        )
        reload()
        currentID = report.instanceName
        return report
    }
}
