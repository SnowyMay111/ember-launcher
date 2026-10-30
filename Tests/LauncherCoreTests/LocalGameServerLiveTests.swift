import Foundation
import Testing
@testable import LauncherCore

/// Starts a real Fabric server; downloads Java and the server, so it only runs with EMBER_LIVE=1.
struct LocalGameServerLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["EMBER_LIVE"] == "1"))
    func testRealFabricServerStartsAndStops() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ember-live-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let java = try await JavaRuntimeManager(paths: LauncherPaths())
            .ensureRuntime(component: "java-runtime-delta", hasArm64Natives: true)
        let server = LocalGameServer(directory: directory, javaExecutable: java, minecraftVersion: "1.21.1")
        let jar = try await server.prepareLauncherJar()
        try LocalServerFiles.writeEula(in: directory)
        try LocalServerFiles.writeServerProperties(in: directory, port: 41555, maxPlayers: 4, motd: "live")
        try LocalServerFiles.writeWhitelist(in: directory, names: ["Steve"])

        try await server.start(launcherJar: jar, memoryMB: 2048, timeout: 300)
        #expect(server.isRunning)
        try server.reloadWhitelist()
        await server.stop()
        #expect(!server.isRunning)
    }
}
