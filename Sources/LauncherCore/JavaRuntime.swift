import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum JavaRuntimeError: Error, LocalizedError, Sendable {
    case unsupportedPlatform(String)
    case componentNotFound(String)
    case javaBinaryNotFound(String)
    case rosettaRequired

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform(let platform):
            return "Platform '\(platform)' not found in Java runtime manifest"
        case .componentNotFound(let component):
            return "Java runtime component '\(component)' not found"
        case .javaBinaryNotFound(let path):
            return "Java binary not found in '\(path)'"
        case .rosettaRequired:
            return "This version needs Rosetta. Run in Terminal: softwareupdate --install-rosetta --agree-to-license"
        }
    }
}

public struct JavaRuntimeResolution: Sendable {
    public let component: String
    public let platform: String
    public let directoryName: String
    public let requiresRosetta: Bool

    public init(component: String, platform: String, directoryName: String, requiresRosetta: Bool) {
        self.component = component
        self.platform = platform
        self.directoryName = directoryName
        self.requiresRosetta = requiresRosetta
    }
}

public enum JavaRuntime {
    public static func resolve(
        component: String,
        hostIsArm64: Bool
    ) -> JavaRuntimeResolution {
        let arm64Components: Set<String> = ["java-runtime-gamma", "java-runtime-delta", "java-runtime-epsilon", "gamma-snapshot"]
        let isArm64Runtime = arm64Components.contains(component)
        return resolve(component: component, hasArm64Natives: isArm64Runtime, hostIsArm64: hostIsArm64)
    }

    public static func resolve(
        component: String,
        hasArm64Natives: Bool = false,
        hostIsArm64: Bool = {
            #if arch(arm64)
            return true
            #else
            return false
            #endif
        }()
    ) -> JavaRuntimeResolution {
        if hostIsArm64 {
            let arm64Components: Set<String> = [
                "java-runtime-gamma",
                "java-runtime-delta",
                "java-runtime-epsilon",
                "gamma-snapshot"
            ]
            var targetComponent = component
            if targetComponent == "java-runtime-alpha" || targetComponent == "java-runtime-beta" {
                targetComponent = "java-runtime-gamma"
            }
            if hasArm64Natives && arm64Components.contains(targetComponent) {
                return JavaRuntimeResolution(
                    component: targetComponent,
                    platform: "mac-os-arm64",
                    directoryName: targetComponent,
                    requiresRosetta: false
                )
            } else {
                return JavaRuntimeResolution(
                    component: component,
                    platform: "mac-os",
                    directoryName: "\(component)-x64",
                    requiresRosetta: true
                )
            }
        } else {
            return JavaRuntimeResolution(
                component: component,
                platform: "mac-os",
                directoryName: component,
                requiresRosetta: false
            )
        }
    }
}

public final class JavaRuntimeManager: Sendable {
    public let paths: LauncherPaths
    public let downloader: Downloader

    public init(paths: LauncherPaths, downloader: Downloader = Downloader()) {
        self.paths = paths
        self.downloader = downloader
    }

    public func ensureRuntime(
        component: String,
        hasArm64Natives: Bool = false,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        let resolution = JavaRuntime.resolve(component: component, hasArm64Natives: hasArm64Natives)
        if resolution.requiresRosetta {
            let rosettaPath = "/Library/Apple/usr/share/rosetta/rosetta"
            if !FileManager.default.fileExists(atPath: rosettaPath) {
                throw JavaRuntimeError.rosettaRequired
            }
        }

        let runtimeDir = paths.runtimes.appendingPathComponent(resolution.directoryName, isDirectory: true)
        let marker = runtimeDir.appendingPathComponent(".installed")
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: marker.path) {
            if let javaURL = findJavaBinary(in: runtimeDir) {
                return javaURL
            }
        }

        let allManifestURL = URL(string: "https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json")!
        let allData = try await downloader.fetchJSON([String: [String: [RuntimeComponentEntry]]].self, from: allManifestURL)

        guard let platformComponents = allData[resolution.platform] else {
            throw JavaRuntimeError.unsupportedPlatform(resolution.platform)
        }

        guard let entries = platformComponents[resolution.component], let firstEntry = entries.first else {
            throw JavaRuntimeError.componentNotFound(resolution.component)
        }

        let manifestRef = firstEntry.manifest
        let runtimeManifest = try await downloader.fetchJSON(RuntimeManifest.self, from: manifestRef.url)

        try paths.ensureDirectories()
        try fileManager.createDirectory(at: runtimeDir, withIntermediateDirectories: true, attributes: nil)

        var downloadItems: [DownloadItem] = []
        var executableURLs: [URL] = []
        var symlinks: [(dest: URL, target: String)] = []

        for (path, fileEntry) in runtimeManifest.files {
            let destURL = runtimeDir.appendingPathComponent(path)
            switch fileEntry.type {
            case "directory":
                try fileManager.createDirectory(at: destURL, withIntermediateDirectories: true, attributes: nil)
            case "file":
                if let raw = fileEntry.downloads?.raw {
                    downloadItems.append(DownloadItem(url: raw.url, dest: destURL, sha1: raw.sha1, size: raw.size))
                }
                if fileEntry.executable == true {
                    executableURLs.append(destURL)
                }
            case "link":
                if let target = fileEntry.target {
                    symlinks.append((dest: destURL, target: target))
                }
            default:
                break
            }
        }

        try await downloader.downloadAll(downloadItems) { prog in
            progress?(prog)
        }

        for execURL in executableURLs {
            if fileManager.fileExists(atPath: execURL.path) {
                try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: execURL.path)
            }
        }

        for link in symlinks {
            let parent = link.dest.deletingLastPathComponent()
            try? fileManager.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
            if fileManager.fileExists(atPath: link.dest.path) || (try? fileManager.destinationOfSymbolicLink(atPath: link.dest.path)) != nil {
                try? fileManager.removeItem(at: link.dest)
            }
            try fileManager.createSymbolicLink(atPath: link.dest.path, withDestinationPath: link.target)
        }

        try Data().write(to: marker)

        guard let javaURL = findJavaBinary(in: runtimeDir) else {
            throw JavaRuntimeError.javaBinaryNotFound(runtimeDir.path)
        }

        return javaURL
    }

    /// Azul Zulu 8 for Apple Silicon (Mojang ships no arm64 Java 8): the Java that versions up to 1.16 use together with the arm64 LWJGL 2.
    public func ensureNativeLegacyJava(progress: (@Sendable (DownloadProgress) -> Void)? = nil) async throws -> URL {
        let runtimeDir = paths.runtimes.appendingPathComponent("jre-legacy-arm64", isDirectory: true)
        let marker = runtimeDir.appendingPathComponent(".installed")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: marker.path), let javaURL = findJavaBinary(in: runtimeDir) {
            return javaURL
        }

        struct Listing: Decodable { let package_uuid: String; let download_url: URL }
        struct Detail: Decodable { let sha256_hash: String?; let download_url: URL }
        let listURL = URL(string: "https://api.azul.com/metadata/v1/zulu/packages/?java_version=8&os=macos&arch=aarch64&java_package_type=jre&archive_type=zip&latest=true&release_status=ga&availability_types=CA&javafx_bundled=false&page_size=1")!
        guard let listing = try await downloader.fetchJSON([Listing].self, from: listURL).first else {
            throw JavaRuntimeError.componentNotFound("Zulu 8 for arm64")
        }
        let detail = try await downloader.fetchJSON(Detail.self, from: URL(string: "https://api.azul.com/metadata/v1/zulu/packages/\(listing.package_uuid)")!)
        guard detail.download_url.host == "cdn.azul.com" else {
            throw JavaRuntimeError.componentNotFound("Zulu 8 for arm64")
        }

        try paths.ensureDirectories()
        // Unique per call so overlapping installs don't wipe each other's in-progress download.
        let work = paths.runtimes.appendingPathComponent("jre-legacy-arm64.download-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: work, withIntermediateDirectories: true, attributes: nil)
        defer { try? fileManager.removeItem(at: work) }

        let archive = work.appendingPathComponent("zulu.zip")
        try await downloader.download(url: detail.download_url, to: archive, sha1: nil, size: nil)
        #if canImport(CryptoKit)
        if let expected = detail.sha256_hash, !expected.isEmpty {
            let actual = SHA256.hash(data: try Data(contentsOf: archive, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
            guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
                throw JavaRuntimeError.javaBinaryNotFound("Zulu 8 download failed its checksum")
            }
        }
        #endif

        let unpacked = work.appendingPathComponent("unpacked", isDirectory: true)
        try ZipArchive.extract(archive, to: unpacked)
        try? fileManager.removeItem(at: runtimeDir)
        try fileManager.moveItem(at: unpacked, to: runtimeDir)
        try Data().write(to: marker)
        guard let javaURL = findJavaBinary(in: runtimeDir) else {
            throw JavaRuntimeError.javaBinaryNotFound(runtimeDir.path)
        }
        return javaURL
    }

    private func findJavaBinary(in rootURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "java" {
                let parentDirName = fileURL.deletingLastPathComponent().lastPathComponent
                if parentDirName == "bin" {
                    return fileURL
                }
            }
        }
        return nil
    }
}

private struct RuntimeComponentEntry: Decodable {
    struct ManifestRef: Decodable {
        let sha1: String?
        let size: Int?
        let url: URL
    }
    let manifest: ManifestRef
}

private struct RuntimeManifest: Decodable {
    struct FileDownloads: Decodable {
        struct RawArtifact: Decodable {
            let sha1: String?
            let size: Int?
            let url: URL
        }
        let raw: RawArtifact?
    }

    struct FileEntry: Decodable {
        let type: String
        let downloads: FileDownloads?
        let executable: Bool?
        let target: String?
    }

    let files: [String: FileEntry]
}
