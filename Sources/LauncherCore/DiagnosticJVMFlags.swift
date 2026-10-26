import Foundation

public enum DiagnosticJVMFlags {
    public static func logURL(instanceDirectory: URL) -> URL {
        instanceDirectory
            .appendingPathComponent("logs", isDirectory: true)
            .appendingPathComponent("gc_telemetry.log")
    }

    public static func prepare(instanceDirectory: URL) {
        let logsDir = instanceDirectory.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    }

    public static func arguments(
        instanceDirectory: URL,
        javaMajor: Int?,
        userArguments: [String]
    ) -> [String] {
        guard let javaMajor, javaMajor >= 11 else { return [] }
        let hasCustomLog = userArguments.contains { arg in
            arg.contains("-Xlog") || arg.contains("-Xloggc")
        }
        guard !hasCustomLog else { return [] }
        let logPath = logURL(instanceDirectory: instanceDirectory).path
        return ["-Xlog:gc*:file=\(logPath):uptime,level,tags:filecount=2,filesize=5M"]
    }
}
