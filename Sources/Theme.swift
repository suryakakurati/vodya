import AppKit
import SwiftUI

/// Colour slots are supplied by the active `Palette`; fonts and helpers live here.
enum Theme {
    private(set) static var current: Palette = Palettes.petal

    static func apply(_ palette: Palette) {
        current = palette
    }

    static var base: Color { current.base }
    static var mantle: Color { current.mantle }
    static var surface0: Color { current.surface0 }
    static var surface1: Color { current.surface1 }
    static var surface2: Color { current.surface2 }
    static var text: Color { current.text }
    static var subtext1: Color { current.subtext1 }
    static var subtext0: Color { current.subtext0 }
    static var overlay1: Color { current.overlay1 }
    static var overlay0: Color { current.overlay0 }
    static var accent: Color { current.accent }
    static var accentAlt: Color { current.accentAlt }
    static var glow: Color { current.glow }
    static var backgroundImage: String? { current.backgroundImage }

    /// Parses "#RRGGBB" (the form stored in config.json).
    static func color(hex raw: String) -> Color? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        return Palettes.color(number)
    }

    static func hex(from color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "#F3B6D3" }
        let r = Int((min(max(rgb.redComponent, 0), 1) * 255).rounded())
        let g = Int((min(max(rgb.greenComponent, 0), 1) * 255).rounded())
        let b = Int((min(max(rgb.blueComponent, 0), 1) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // Familiar names the card uses.
    static var lavender: Color { current.accent }
    static var pink: Color { current.accentAlt }
    static var mauve: Color { current.glow }
    static var blue: Color { current.accentAlt }

    private static let regularNames = ["MapleMono-NF-CN-Regular", "MapleMono-NF-CN-Light", "Maple Mono NF CN"]
    private static let boldNames = ["MapleMono-NF-CN-SemiBold", "MapleMono-NF-CN-Bold", "Maple Mono NF CN"]

    /// Maple Mono NF CN (the bar's label font), with a monospaced system fallback.
    static func mono(_ size: CGFloat, bold: Bool = false) -> Font {
        for name in (bold ? boldNames : regularNames) {
            if let font = NSFont(name: name, size: size) {
                return Font(font)
            }
        }
        return Font(NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .semibold : .regular))
    }
}
