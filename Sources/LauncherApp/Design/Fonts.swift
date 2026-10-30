import Foundation
import CoreText

public enum FontLoader {
    private static let registrationLock = NSLock()
    nonisolated(unsafe) private static var isRegistered = false

    public static func registerAll() {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        guard !isRegistered else { return }
        isRegistered = true

        var fontURLs: [URL] = []

        if let subdirectoryURLs = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") {
            fontURLs.append(contentsOf: subdirectoryURLs)
        }

        if let folderURL = Bundle.module.url(forResource: "Fonts", withExtension: nil),
           let contents = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
            fontURLs.append(contentsOf: contents.filter { $0.pathExtension.lowercased() == "ttf" })
        }

        var registered = Set<URL>()
        for url in fontURLs where registered.insert(url).inserted {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
