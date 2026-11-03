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

    @Test func windowSizeGoesToTheGameAfterItsOwnArguments() {
        let result = LaunchOverrides(windowWidth: "1710", windowHeight: " 1080 ").apply(to: command)
        #expect(result.arguments == command.arguments + ["--width", "1710", "--height", "1080"])
    }

    @Test func badOrDuplicateWindowSizeIsLeftOut() {
        #expect(LaunchOverrides(windowWidth: "abc", windowHeight: "1080").apply(to: command).arguments == command.arguments)
        #expect(LaunchOverrides(windowWidth: "0", windowHeight: "0").apply(to: command).arguments == command.arguments)
        let sized = LaunchCommand(executable: command.executable, arguments: command.arguments + ["--width", "854"],
                                  workingDirectory: command.workingDirectory, logURL: command.logURL)
        #expect(LaunchOverrides(windowWidth: "1710", windowHeight: "1080").apply(to: sized).arguments == sized.arguments)
    }

    @Test func borderlessAddsTheLWJGL2FlagBeforeOtherJVMArguments() {
        let result = LaunchOverrides(jvmArguments: "-Dfoo=bar", borderless: true).apply(to: command)
        #expect(result.arguments == ["-Dorg.lwjgl.opengl.Window.undecorated=true", "-Dfoo=bar"] + command.arguments)
        #expect(LaunchOverrides().apply(to: command).arguments == command.arguments)
    }

    @Test func diskUsageOfMissingFolderIsZero() {
        #expect(DiskUsage.size(of: URL(fileURLWithPath: "/no/such/folder")) == 0)
    }
}
