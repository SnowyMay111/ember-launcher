import Foundation

public struct LauncherPaths: Sendable {
    public let root: URL

    public init(root: URL? = nil) {
        if let root = root {
            self.root = root
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            if let appSupport = appSupport {
                self.root = appSupport.appendingPathComponent("mc-launcher", isDirectory: true)
            } else {
                let home = FileManager.default.homeDirectoryForCurrentUser
                self.root = home
                    .appendingPathComponent("Library", isDirectory: true)
                    .appendingPathComponent("Application Support", isDirectory: true)
                    .appendingPathComponent("mc-launcher", isDirectory: true)
            }
        }
    }

    public var versions: URL {
        root.appendingPathComponent("versions", isDirectory: true)
    }

    public var libraries: URL {
        root.appendingPathComponent("libraries", isDirectory: true)
    }

    public var assetsRoot: URL {
        root.appendingPathComponent("assets", isDirectory: true)
    }

    public var assetsIndexes: URL {
        assetsRoot.appendingPathComponent("indexes", isDirectory: true)
    }

    public var assetsObjects: URL {
        assetsRoot.appendingPathComponent("objects", isDirectory: true)
    }

    public var runtimes: URL {
        root.appendingPathComponent("runtimes", isDirectory: true)
    }

    public var instances: URL {
        root.appendingPathComponent("instances", isDirectory: true)
    }

    public func versionDir(_ id: String) -> URL {
        versions.appendingPathComponent(id, isDirectory: true)
    }

    public func versionJSON(_ id: String) -> URL {
        versionDir(id).appendingPathComponent("\(id).json")
    }

    public func versionJAR(_ id: String) -> URL {
        versionDir(id).appendingPathComponent("\(id).jar")
    }

    public func ensureDirectories() throws {
        let fileManager = FileManager.default
        let dirs = [
            root,
            versions,
            libraries,
            assetsRoot,
            assetsIndexes,
            assetsObjects,
            runtimes,
            instances
        ]
        for dir in dirs {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
