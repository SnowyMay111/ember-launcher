import Foundation
import Testing
@testable import LauncherCore

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LocalGameServerTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: nil
    )
    return directory
}

private func makeExecutableScript(in directory: URL, contents: String) throws -> URL {
    let script = directory.appendingPathComponent("java")
    try contents.data(using: .utf8)!.write(to: script)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: script.path
    )
    return script
}

private func makeRunningServer(in directory: URL) throws -> LocalGameServer {
    let script = try makeExecutableScript(
        in: directory,
        contents: """
        #!/bin/sh
        printf '%s\\n' '[12:00:00] [Server thread/INFO]: Done (1.5s)! For help, type "help"'
        while IFS= read -r command
        do
            if [ "$command" = "stop" ]; then
                exit 0
            fi
        done
        """
    )
    return LocalGameServer(
        directory: directory,
        javaExecutable: script,
        minecraftVersion: "1.20.1"
    )
}

struct LocalGameServerTests {
    @Test func testReadyLine() {
        #expect(
            LocalGameServer.isReadyLine(
                "[12:00:00] [Server thread/INFO]: Done (1.5s)! For help, type \"help\""
            )
        )
        #expect(
            !LocalGameServer.isReadyLine(
                "[12:00:00] [Server thread/INFO]: Starting minecraft server"
            )
        )
        #expect(
            !LocalGameServer.isReadyLine(
                "[12:00:00] [Server thread/INFO]: Done (1.5s)! For help, type help"
            )
        )
    }

    @Test func testLaunchArguments() {
        let jar = URL(fileURLWithPath: "/tmp/fabric-server.jar")
        #expect(
            LocalGameServer.launchArguments(launcherJar: jar, memoryMB: 1024)
                == ["-Xmx1024M", "-jar", jar.path, "nogui"]
        )
    }

    @Test func testStartSendAndStop() async throws {
        let directory = try makeTemporaryDirectory()
        let server = try makeRunningServer(in: directory)
        let jar = directory.appendingPathComponent("server.jar")

        try await server.start(launcherJar: jar)
        #expect(server.isRunning)

        try server.send(command: "whitelist reload")
        try server.reloadWhitelist()

        await server.stop()
        #expect(!server.isRunning)

        var isNotRunning = false
        do {
            try server.send(command: "list")
        } catch let error as LocalGameServerError {
            isNotRunning = error == .notRunning
        } catch {
            isNotRunning = false
        }
        #expect(isNotRunning)
    }

    @Test func testExitedEarly() async throws {
        let directory = try makeTemporaryDirectory()
        let script = try makeExecutableScript(
            in: directory,
            contents: """
            #!/bin/sh
            exit 0
            """
        )
        let server = LocalGameServer(
            directory: directory,
            javaExecutable: script,
            minecraftVersion: "1.20.1"
        )

        var exitedCode: Int32?
        do {
            try await server.start(
                launcherJar: directory.appendingPathComponent("server.jar"),
                timeout: 2
            )
        } catch let error as LocalGameServerError {
            if case .exitedEarly(let code) = error {
                exitedCode = code
            }
        } catch {
        }

        #expect(exitedCode == 0)
    }

    @Test func testStartTimeout() async throws {
        let directory = try makeTemporaryDirectory()
        let script = try makeExecutableScript(
            in: directory,
            contents: """
            #!/bin/sh
            sleep 2
            """
        )
        let server = LocalGameServer(
            directory: directory,
            javaExecutable: script,
            minecraftVersion: "1.20.1"
        )

        var timedOut = false
        do {
            try await server.start(
                launcherJar: directory.appendingPathComponent("server.jar"),
                timeout: 1
            )
        } catch let error as LocalGameServerError {
            timedOut = error == .startTimedOut
        } catch {
            timedOut = false
        }

        #expect(timedOut)
        await server.stop(timeout: 1)
    }
}
