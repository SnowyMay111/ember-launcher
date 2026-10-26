import Foundation

public enum JavaRuntimeError: Error, LocalizedError, Sendable {
    case unsupportedPlatform(String)
    case componentNotFound(String)
    case javaBinaryNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform(let platform):
            return "Platform '\(platform)' not found in Java runtime manifest"
        case .componentNotFound(let component):
            return "Java runtime component '\(component)' not found"
        case .javaBinaryNotFound(let path):
            return "Java binary not found in '\(path)'"
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
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        let runtimeDir = paths.runtimes.appendingPathComponent(component, isDirectory: true)
        let marker = runtimeDir.appendingPathComponent(".installed")
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: marker.path) {
            if let javaURL = findJavaBinary(in: runtimeDir) {
                return javaURL
            }
        }

        let allManifestURL = URL(string: "https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json")!
        let allData = try await downloader.fetchJSON([String: [String: [RuntimeComponentEntry]]].self, from: allManifestURL)

        guard let platformComponents = allData["mac-os-arm64"] ?? allData["mac-os"] else {
            throw JavaRuntimeError.unsupportedPlatform("mac-os-arm64")
        }

        guard let entries = platformComponents[component], let firstEntry = entries.first else {
            throw JavaRuntimeError.componentNotFound(component)
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
