import Foundation

/// Launcher-wide Java choices from Settings, applied on top of what a build produced.
public struct LaunchOverrides: Equatable, Sendable {
    /// Path to a `java` executable; empty or not executable means "use the managed runtime".
    public var javaPath: String
    /// JVM arguments for every instance, separated by spaces.
    public var jvmArguments: String

    public init(javaPath: String = "", jvmArguments: String = "") {
        self.javaPath = javaPath
        self.jvmArguments = jvmArguments
    }

    public var extraArguments: [String] {
        jvmArguments.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    /// The custom Java when the path points at an executable file.
    public var customJava: URL? {
        let trimmed = javaPath.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, FileManager.default.isExecutableFile(atPath: trimmed) else { return nil }
        return URL(fileURLWithPath: trimmed)
    }

    public func apply(to command: LaunchCommand) -> LaunchCommand {
        LaunchCommand(
            executable: customJava ?? command.executable,
            arguments: extraArguments + command.arguments,
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
