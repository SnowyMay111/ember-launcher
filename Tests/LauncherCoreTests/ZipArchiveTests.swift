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

    @Test func extractKeepsNonASCIIFileNames() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let names = ["中文一.txt", "中文二.txt", "ZI0OD_僵尸.txt"]
        for name in names { try "x".write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8) }
        let archive = dir.appendingPathComponent("out.zip")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.arguments = ["-q", archive.path] + names
        zip.currentDirectoryURL = dir
        zip.environment = ["LC_ALL": "en_US.UTF-8"]
        try zip.run()
        zip.waitUntilExit()

        let out = dir.appendingPathComponent("out", isDirectory: true)
        try ZipArchive.extract(archive, to: out)
        for name in names {
            #expect(fm.fileExists(atPath: out.appendingPathComponent(name).path))
        }
    }

    @Test func extractFallsBackForNamesThatAreNotUTF8() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // A zip whose only entry is named with GBK bytes (no UTF-8 flag), built by hand: one stored entry.
        let name: [UInt8] = Array("ZI_".utf8) + [0xC4, 0xE3, 0xBA, 0xC3] + Array(".txt".utf8)
        let data: [UInt8] = Array("x".utf8)
        func le32(_ v: UInt32) -> [UInt8] { [UInt8(v & 255), UInt8((v >> 8) & 255), UInt8((v >> 16) & 255), UInt8((v >> 24) & 255)] }
        func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 255), UInt8(v >> 8)] }
        let crc: UInt32 = 0x8CDC1683 // CRC-32 of "x"
        var zip: [UInt8] = []
        zip += le32(0x04034b50) + le16(10) + le16(0) + le16(0) + le16(0) + le16(0x21) + le32(crc) + le32(1) + le32(1) + le16(UInt16(name.count)) + le16(0) + name + data
        let centralStart = UInt32(zip.count)
        var central: [UInt8] = le32(0x02014b50) + le16(20) + le16(10) + le16(0) + le16(0) + le16(0) + le16(0x21) + le32(crc) + le32(1) + le32(1)
        central += le16(UInt16(name.count)) + le16(0) + le16(0) + le16(0) + le16(0) + le32(0) + le32(0) + name
        zip += central
        zip += le32(0x06054b50) + le16(0) + le16(0) + le16(1) + le16(1) + le32(UInt32(central.count)) + le32(centralStart) + le16(0)
        let archive = dir.appendingPathComponent("gbk.zip")
        try Data(zip).write(to: archive)

        #expect(try ZipArchive.entries(of: archive).count == 1)
        let out = dir.appendingPathComponent("out", isDirectory: true)
        try ZipArchive.extract(archive, to: out)
        let files = try fm.contentsOfDirectory(atPath: out.path)
        #expect(files.count == 1)
    }
}
