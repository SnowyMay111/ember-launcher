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
        // Not waitUntilExit: on a Swift concurrency thread it can miss the exit and hang the whole test run.
        for _ in 0..<50 where process.isRunning {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        #expect(!process.isRunning)
        if process.isRunning { process.terminate() }
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
