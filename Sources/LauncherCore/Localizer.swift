import Foundation

/// Переводы интерфейса. Ключ = английский текст, поэтому английский не требует файла.
/// Другие языки лежат отдельными JSON-файлами `<код>.json` в одной папке: `{"Play": "Играть"}`.
/// Удалил файл, и язык пропал; нет файла или ключа, остаётся английский.
public final class Localizer {
    private let table: [String: String]
    public let language: String?

    /// - Parameters:
    ///   - directory: папка с `<код>.json` (может не существовать).
    ///   - preferredLanguages: например `["ru-RU", "en-US"]`, как отдаёт система.
    public init(directory: URL?, preferredLanguages: [String]) {
        var found: (code: String, table: [String: String])?
        if let directory {
            for tag in preferredLanguages {
                let base = tag.split(separator: "-").first.map(String.init)?.lowercased() ?? tag.lowercased()
                if base == "en" { break }
                let candidates = [tag, base]
                if let hit = candidates.lazy.compactMap({ Localizer.load(directory, $0) }).first {
                    found = (base, hit)
                    break
                }
            }
        }
        table = found?.table ?? [:]
        language = found?.code
    }

    public func tr(_ key: String) -> String {
        table[key] ?? key
    }

    public func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), arguments: args)
    }

    /// Коды языков, файлы которых лежат в папке (для будущего выбора языка).
    public static func availableLanguages(in directory: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.sorted()
    }

    private static func load(_ directory: URL, _ code: String) -> [String: String]? {
        let url = directory.appendingPathComponent("\(code).json")
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return nil }
        return dict
    }
}
