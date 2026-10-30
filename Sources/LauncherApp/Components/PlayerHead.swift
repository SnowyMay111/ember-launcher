import SwiftUI
import AppKit

/// Skin head of a Minecraft player (minotar.net, pixel-crisp). Falls back to `PixelAvatar` when the name is empty or the skin cannot be loaded.
struct PlayerHead: View {
    let name: String
    var size: CGFloat = 38

    @Local private var image: NSImage?

    private static var cache: [String: NSImage] = [:]

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                PixelAvatar(size: size)
            }
        }
        .task(id: cleanName) { await load() }
    }

    private func load() async {
        let key = cleanName.lowercased()
        guard !key.isEmpty, key.count <= 16,
              key.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }) else {
            image = nil
            return
        }
        if let cached = Self.cache[key] {
            image = cached
            return
        }
        guard let url = URL(string: "https://minotar.net/helm/\(key)/128") else { return }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let loaded = NSImage(data: data) else {
            image = nil
            return
        }
        Self.cache[key] = loaded
        image = loaded
    }
}
