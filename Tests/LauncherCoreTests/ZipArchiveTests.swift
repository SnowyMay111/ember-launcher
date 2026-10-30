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
}
