import Foundation
import LauncherCore

/// The "Describe with AI" flow: the model suggests mods, then the chosen ones are installed into a new Fabric instance.
extension AppState {
    /// Asks the chosen AI provider for a mod list that fits the description. Nothing is installed yet.
    func planPack(description: String, minecraftVersion: String, settings: SettingsStore) async throws -> ModpackPlan {
        #if DEBUG
        // Test hook for debug builds: a saved reply from this file replaces the provider call.
        if let path = ProcessInfo.processInfo.environment["VOXEL_AI_ANSWER_FILE"],
           let text = try? String(contentsOfFile: path, encoding: .utf8) {
            return try await ModpackPlanner(client: SavedAnswerClient(text: text)).plan(description: description, minecraftVersion: minecraftVersion)
        }
        #endif
        guard let key = settings.aiAPIKey() else { throw AIError.missingKey }
        let client = try makeAIClient(kind: settings.aiProvider, apiKey: key, model: settings.aiModel)
        return try await ModpackPlanner(client: client).plan(description: description, minecraftVersion: minecraftVersion)
    }

    /// Creates a Fabric instance, selects it and installs the chosen mods one by one.
    func buildPack(
        name: String,
        minecraftVersion: String,
        group: String?,
        memoryMB: Int,
        mods: [PlannedMod],
        progress: @escaping @Sendable (String, Int, Int) -> Void
    ) async throws -> ModpackBuildReport {
        let created = try createInstance(name: name, minecraftVersion: minecraftVersion, loader: .fabric, group: group, memoryMB: memoryMB)
        let report = await ModpackBuilder(mods: ModManager(store: store)).install(mods, into: created, progress: progress)
        reload()
        return report
    }
}
