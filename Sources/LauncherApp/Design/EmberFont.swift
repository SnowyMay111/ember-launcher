import SwiftUI
import CoreText

/// Manrope (one variable file, weight axis 200-800) for text and DM Mono (400 / 500) for labels,
/// the two families of the Ember prototype. Falls back to the system fonts if the files are not registered.
extension Theme {
    private static let weightAxis = NSNumber(value: 0x77676874) // 'wght'
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

    static func font(size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false) -> Font {
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
            let name = css >= 500 ? "DMMono-Medium" : "DMMono-Regular"
            let ct = CTFontCreateWithName(name as CFString, size, nil)
            if CTFontCopyPostScriptName(ct) as String == name { return Font(ct) }
            return .system(size: size, weight: css >= 500 ? .medium : .regular, design: .monospaced)
        }
        var descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: "Manrope",
            kCTFontSizeAttribute: size,
        ] as CFDictionary)
        descriptor = CTFontDescriptorCreateCopyWithVariation(descriptor, weightAxis, CGFloat(min(max(css, 200), 800)))
        let ct = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        if CTFontCopyFamilyName(ct) as String == "Manrope" { return Font(ct) }
        return .system(size: size, weight: Font.Weight(rawCSS: css), design: .rounded)
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
