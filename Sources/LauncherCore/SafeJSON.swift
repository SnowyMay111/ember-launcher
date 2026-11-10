import Foundation

/// Reading the launcher's own list files (mods.json, content.json, the skin index). A file that no longer decodes
/// must not be mistaken for an empty one: the next save would wipe the only record of what the user installed.
public enum SafeJSON {
    /// Decodes a JSON file. A missing file gives nil; one that does not decode is copied aside first, then gives nil.
    public static func read<T: Decodable>(_ type: T.Type, from url: URL, decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let value = try? decoder.decode(type, from: data) { return value }
        preserve(url)
        return nil
    }

    /// Copies an unreadable file next to itself as "<name>.corrupt" and returns the copy's URL.
    @discardableResult
    public static func preserve(_ url: URL) -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let copy = url.appendingPathExtension("corrupt")
        try? fileManager.removeItem(at: copy)
        do {
            try fileManager.copyItem(at: url, to: copy)
            return copy
        } catch {
            return nil
        }
    }
}
