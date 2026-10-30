import Testing
import Foundation
@testable import LauncherCore

struct ZipArchiveTests {
    private func makeArchive(symlink: Bool) throws -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try "x".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        if symlink {
            try fm.createSymbolicLink(atPath: dir.appendingPathComponent("link").path, withDestinationPath: "/etc/hosts")
        }
        let archive = dir.appendingPathComponent("out.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-q", "-y", "-r", archive.path, "a.txt"] + (symlink ? ["link"] : [])
        process.currentDirectoryURL = dir
        try process.run()
        process.waitUntilExit()
        return archive
    }

    @Test func detectsSymlinkEntry() throws {
        #expect(try ZipArchive.hasSymlinks(makeArchive(symlink: true)))
    }

    @Test func plainArchiveHasNoSymlinks() throws {
        #expect(try !ZipArchive.hasSymlinks(makeArchive(symlink: false)))
    }

    /// 64 MB of zeros compress to a few dozen KB, like a zip bomb.
    private func makeBomb() throws -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(count: 64 * 1024 * 1024).write(to: dir.appendingPathComponent("zeros.bin"))
        let archive = dir.appendingPathComponent("bomb.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-q", "-9", archive.path, "zeros.bin"]
        process.currentDirectoryURL = dir
        try process.run()
        process.waitUntilExit()
        return archive
    }

    @Test func extractStopsAtRealSizeLimit() throws {
        let archive = try makeBomb()
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: out) }
        #expect(throws: ZipArchiveError.self) {
            try ZipArchive.extract(archive, to: out, maxBytes: 8 * 1024 * 1024)
        }
    }

    @Test func extractWithinLimitSucceeds() throws {
        let archive = try makeBomb()
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: out) }
        try ZipArchive.extract(archive, to: out, maxBytes: 128 * 1024 * 1024)
        #expect(FileManager.default.fileExists(atPath: out.appendingPathComponent("zeros.bin").path))
    }
}
