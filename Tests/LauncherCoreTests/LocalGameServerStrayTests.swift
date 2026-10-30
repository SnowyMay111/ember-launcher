import Foundation
import Testing
@testable import LauncherCore

struct LocalGameServerStrayTests {
    @Test func stopsOrphanedServerOfTheSameFolder() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 60; true", "-jar", dir.appendingPathComponent("fake-server.jar").path]
        try process.run()
        #expect(process.isRunning)

        await LocalGameServer.stopStrayProcesses(in: dir)
        process.waitUntilExit()
        #expect(!process.isRunning)
    }

    @Test func leavesOtherFoldersAlone() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let other = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 60; true", "-jar", other.appendingPathComponent("fake-server.jar").path]
        try process.run()
        defer { process.terminate() }

        await LocalGameServer.stopStrayProcesses(in: dir)
        #expect(process.isRunning)
    }
}
