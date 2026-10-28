import SwiftUI
import CoreText

/// Geist for text and Geist Mono for numbers and small labels.
/// Falls back to the system fonts if the files are not registered.
extension Theme {

    private static let cacheLock = NSLock()
    private static var fontCache: [String: Font] = [:]

    /// CSS-style numeric weight for a SwiftUI weight.
    static func cssWeight(_ weight: Font.Weight) -> Int {
        if weight == .ultraLight || weight == .thin { return 200 }
        if weight == .light { return 300 }
        if weight == .medium { return 500 }
        if weight == .semibold { return 600 }
        if weight == .bold { return 700 }
        if weight == .heavy || weight == .black { return 800 }
        return 400
    }

    /// Гарантирует читаемый минимальный кегль для интерфейса (не менее 12 pt), сохраняя размеры >= 12 без искажений.
    static func readableSize(_ size: CGFloat) -> CGFloat {
        if size < 12 { return 12 }
        return size
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false) -> Font {
        let size = readableSize(size)
        let css = cssWeight(weight)
        let key = "\(size)|\(css)|\(mono)"
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = fontCache[key] { return cached }
        let font = makeFont(size: size, css: css, mono: mono)
        fontCache[key] = font
        return font
    }

    private static func makeFont(size: CGFloat, css: Int, mono: Bool) -> Font {
        if mono {
            let name = css >= 500 ? "GeistMono-Medium" : "GeistMono-Regular"
            let ct = CTFontCreateWithName(name as CFString, size, nil)
            if CTFontCopyPostScriptName(ct) as String == name { return Font(ct) }
            return .system(size: size, weight: css >= 500 ? .medium : .regular, design: .monospaced)
        }
        let name: String
        if css < 450 {
            name = "Geist-Regular"
        } else if css < 550 {
            name = "Geist-Medium"
        } else {
            name = "Geist-SemiBold"
        }
        let ct = CTFontCreateWithName(name as CFString, size, nil)
        if CTFontCopyPostScriptName(ct) as String == name { return Font(ct) }
        return .system(size: size, weight: Font.Weight(rawCSS: css), design: .default)
    }
}

private extension Font.Weight {
    init(rawCSS css: Int) {
        switch css {
        case ..<250: self = .ultraLight
        case ..<350: self = .light
        case ..<450: self = .regular
        case ..<550: self = .medium
        case ..<650: self = .semibold
        case ..<750: self = .bold
        default: self = .heavy
        }
    }
}
