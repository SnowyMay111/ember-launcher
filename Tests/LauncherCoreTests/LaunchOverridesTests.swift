import Foundation
import Testing
@testable import LauncherCore

@Suite struct LaunchOverridesTests {
    private let command = LaunchCommand(
        executable: URL(fileURLWithPath: "/managed/java"),
        arguments: ["-Xmx2G", "-cp", "x", "Main"],
        workingDirectory: URL(fileURLWithPath: "/game"),
        logURL: URL(fileURLWithPath: "/game/launcher.log")
    )

    @Test func globalArgumentsComeFirstAndMissingJavaIsIgnored() {
        let result = LaunchOverrides(javaPath: "/no/such/java", jvmArguments: " -XX:+UseG1GC   -Dfoo=bar ").apply(to: command)
        #expect(result.arguments == ["-XX:+UseG1GC", "-Dfoo=bar", "-Xmx2G", "-cp", "x", "Main"])
        #expect(result.executable.path == "/managed/java")
    }

    @Test func existingExecutableReplacesManagedJava() {
        let result = LaunchOverrides(javaPath: "/bin/echo").apply(to: command)
        #expect(result.executable.path == "/bin/echo")
        #expect(result.arguments == command.arguments)
    }

    @Test func diskUsageOfMissingFolderIsZero() {
        #expect(DiskUsage.size(of: URL(fileURLWithPath: "/no/such/folder")) == 0)
    }
}
