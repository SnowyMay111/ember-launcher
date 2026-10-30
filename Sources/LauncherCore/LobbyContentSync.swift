import Foundation

/// A single piece of content (mod, shader pack, or resource pack) offered for lobby sync,
/// built from what the host currently has installed and enabled.
public struct LobbyContentDraft: Sendable, Equatable {
    public var kind: LobbyItemKind
    public var projectID: String
    public var versionID: String
    public var title: String

    public init(kind: LobbyItemKind, projectID: String, versionID: String, title: String) {
        self.kind = kind
        self.projectID = projectID
        self.versionID = versionID
        self.title = title
    }
}

public enum LobbyContentDrafts {
    /// Builds the draft content list for a lobby from the host's installed mods and content records.
    /// Enabled mods without a Modrinth record cannot be shared, so they are only counted.
    public static func make(mods: [InstalledMod], content: [ContentRecord]) -> (drafts: [LobbyContentDraft], unsynced: Int) {
        var drafts: [LobbyContentDraft] = []
        var seen = Set<String>()
        var unsynced = 0

        for mod in mods where mod.isEnabled {
            if let record = mod.record, !record.versionId.isEmpty {
                if seen.insert(record.versionId).inserted {
                    drafts.append(LobbyContentDraft(
                        kind: .mod,
                        projectID: record.projectId,
                        versionID: record.versionId,
                        title: record.title
                    ))
                }
            } else {
                unsynced += 1
            }
        }

        for record in content {
            let kind: LobbyItemKind
            switch record.kind {
            case .shader: kind = .shader
            case .resourcepack: kind = .resourcepack
            default: continue
            }
            guard !record.versionId.isEmpty, seen.insert(record.versionId).inserted else { continue }
            drafts.append(LobbyContentDraft(
                kind: kind,
                projectID: record.projectId,
                versionID: record.versionId,
                title: record.title
            ))
        }

        return (drafts, unsynced)
    }
}

/// Which parts of the host's content list a guest wants applied to their own instance.
public struct LobbyContentSyncOptions: Sendable, Equatable {
    public var syncShaders: Bool
    public var syncResourcePacks: Bool
    public var activate: Bool

    public init(syncShaders: Bool = false, syncResourcePacks: Bool = true, activate: Bool = true) {
        self.syncShaders = syncShaders
        self.syncResourcePacks = syncResourcePacks
        self.activate = activate
    }
}

public struct LobbyContentSyncResult: Sendable, Equatable {
    public var mods: LobbyModSyncResult
    public var packsInstalled: Int
    public var packsAlreadyPresent: Int
    public var packsUnavailable: Int

    public init(mods: LobbyModSyncResult, packsInstalled: Int = 0, packsAlreadyPresent: Int = 0, packsUnavailable: Int = 0) {
        self.mods = mods
        self.packsInstalled = packsInstalled
        self.packsAlreadyPresent = packsAlreadyPresent
        self.packsUnavailable = packsUnavailable
    }
}

/// Makes a guest's lobby instance carry the host's shared content: mods via `LobbySyncer`,
/// plus shader packs and resource packs the guest has opted into.
public final class LobbyContentSyncer: Sendable {
    private let content: ContentInstaller

    public init(content: ContentInstaller) {
        self.content = content
    }

    public func sync(
        _ items: [LobbyItem],
        options: LobbyContentSyncOptions,
        into instance: String,
        progress: (@Sendable (_ done: Int, _ total: Int) -> Void)? = nil
    ) async throws -> LobbyContentSyncResult {
        let modIDs = items.filter { $0.kind == .mod }.map(\.versionID)
        let packItems = items.filter { item in
            (item.kind == .shader && options.syncShaders) || (item.kind == .resourcepack && options.syncResourcePacks)
        }

        let modTotal = modIDs.count
        let packTotal = packItems.count
        let total = modTotal + packTotal

        let modSyncer = LobbySyncer(manager: content.modManager)
        let modResult = try await modSyncer.sync(
            LobbyModList(versionIDs: modIDs),
            into: instance,
            progress: { done, _ in
                progress?(done, total)
            }
        )

        var result = LobbyContentSyncResult(mods: modResult)
        guard !packItems.isEmpty else { return result }

        let versions = try await content.client.versions(ids: packItems.map(\.versionID))
        let versionByID = Dictionary(versions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var records = content.loadContentRecords(instance: instance)
        let fm = FileManager.default
        var lastShaderFileName: String?
        var syncedResourcePackFileNames: [String] = []

        for (index, item) in packItems.enumerated() {
            defer { progress?(modTotal + index + 1, total) }

            guard let version = versionByID[item.versionID],
                  let file = version.primaryFile,
                  Self.isSafePackName(file.filename)
            else {
                result.packsUnavailable += 1
                continue
            }

            let kind: ContentKind = item.kind == .shader ? .shader : .resourcepack
            let dir = content.contentDirectory(for: kind, in: instance)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let target = dir.appendingPathComponent(file.filename)

            if fm.fileExists(atPath: target.path) {
                result.packsAlreadyPresent += 1
            } else {
                try await content.downloader.download(url: file.url, to: target, sha1: file.sha1, size: file.size)
                result.packsInstalled += 1
            }

            records.removeAll { $0.fileName == file.filename }
            records.append(ContentRecord(
                fileName: file.filename,
                projectId: version.projectId,
                versionId: version.id,
                title: item.title,
                versionNumber: version.versionNumber,
                kind: kind
            ))

            if item.kind == .shader {
                lastShaderFileName = file.filename
            } else {
                syncedResourcePackFileNames.append(file.filename)
            }
        }

        try content.saveContentRecords(records, instance: instance)

        if options.activate {
            let gameDirectory = content.store.gameDirectory(for: instance)
            if lastShaderFileName != nil {
                _ = try? await content.ensureShaderSupport(into: instance)
            }
            if let shaderFileName = lastShaderFileName {
                try? PackActivation.enableShaderPack(fileName: shaderFileName, gameDirectory: gameDirectory)
            }
            for fileName in syncedResourcePackFileNames {
                try? PackActivation.enableResourcePack(fileName: fileName, gameDirectory: gameDirectory)
            }
        }

        return result
    }

    /// A pack file name from the network must stay inside the content folder.
    static func isSafePackName(_ name: String) -> Bool {
        !name.isEmpty && name.hasSuffix(".zip") && !name.contains("/") && !name.contains("\\") && !name.hasPrefix(".")
    }
}
