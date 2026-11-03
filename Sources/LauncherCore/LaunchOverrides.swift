import Foundation

/// Launcher-wide Java choices from Settings, applied on top of what a build produced.
public struct LaunchOverrides: Equatable, Sendable {
    /// Path to a `java` executable; empty or not executable means "use the managed runtime".
    public var javaPath: String
    /// JVM arguments for every instance, separated by spaces.
    public var jvmArguments: String
    /// Game window size in pixels; anything that is not a positive number leaves the game's own default.
    public var windowWidth: String
    public var windowHeight: String
    /// Old Minecraft (LWJGL 2) opens its window without a title bar and borders; newer versions ignore the flag.
    public var borderless: Bool

    public init(javaPath: String = "", jvmArguments: String = "", windowWidth: String = "", windowHeight: String = "", borderless: Bool = false) {
        self.javaPath = javaPath
        self.jvmArguments = jvmArguments
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.borderless = borderless
    }

    /// `--width W --height H` for the game, unless the size is unset or the build already carries one.
    var windowArguments: [String] {
        guard let width = Int(windowWidth.trimmingCharacters(in: .whitespaces)), width > 0,
              let height = Int(windowHeight.trimmingCharacters(in: .whitespaces)), height > 0 else { return [] }
        return ["--width", String(width), "--height", String(height)]
    }

    public var extraArguments: [String] {
        (borderless ? ["-Dorg.lwjgl.opengl.Window.undecorated=true"] : [])
            + jvmArguments.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    /// The custom Java when the path points at an executable file.
    public var customJava: URL? {
        let trimmed = javaPath.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, FileManager.default.isExecutableFile(atPath: trimmed) else { return nil }
        return URL(fileURLWithPath: trimmed)
    }

    public func apply(to command: LaunchCommand) -> LaunchCommand {
        let window = command.arguments.contains("--width") ? [] : windowArguments
        return LaunchCommand(
            executable: customJava ?? command.executable,
            arguments: extraArguments + command.arguments + window,
            workingDirectory: command.workingDirectory,
            logURL: command.logURL
        )
    }
}

public enum DiskUsage {
    /// Total size of the files under `url`; 0 when it does not exist.
    public static func size(of url: URL) -> Int64 {
        guard let walker = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: []
        ) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in walker {
            total += Int64((try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
        return total
    }
}
