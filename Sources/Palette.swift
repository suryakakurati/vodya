import SwiftUI

/// A named set of colour slots. `Theme` exposes these to the views; switching
/// palette is just swapping this struct.
struct Palette {
    var name: String
    var base: Color
    var mantle: Color
    var surface0: Color
    var surface1: Color
    var surface2: Color
    var text: Color
    var subtext1: Color
    var subtext0: Color
    var overlay1: Color
    var overlay0: Color
    var accent: Color
    var accentAlt: Color
    var glow: Color
    /// Optional artwork drawn behind the card; the card lays a scrim over it.
    var backgroundImage: String? = nil
}

struct PaletteEntry: Identifiable {
    let id: String
    let palette: Palette
    var name: String { palette.name }
}

enum Palettes {
    static func color(_ value: UInt32, _ opacity: Double = 1) -> Color {
        Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    /// Default: soft petal pink over a deep plum, with misty lilac text.
    static let petal = Palette(
        name: "Petal",
        base: color(0x2B2239),
        mantle: color(0x221B2E),
        surface0: color(0x3A2E4B),
        surface1: color(0x4D3D62),
        surface2: color(0x5F4D74),
        text: color(0xF1EBF8),
        subtext1: color(0xDDD3E9),
        subtext0: color(0xC6B9D8),
        overlay1: color(0xA295B8),
        overlay0: color(0x817297),
        accent: color(0xF8CADD),
        accentAlt: color(0xCBD6F2),
        glow: color(0xF3B6D3),
        backgroundImage: "vodya-background"
    )

    /// The darker, bluer scheme the app shipped with first.
    static let softPurple = Palette(
        name: "Soft Purple",
        base: color(0x1B1430),
        mantle: color(0x151029),
        surface0: color(0x281E44),
        surface1: color(0x372A5C),
        surface2: color(0x473A70),
        text: color(0xF0EBFF),
        subtext1: color(0xCFC6EA),
        subtext0: color(0xB4A8D6),
        overlay1: color(0x8477AB),
        overlay0: color(0x6B5E92),
        accent: color(0xD3C2FF),
        accentAlt: color(0xFFC6EA),
        glow: color(0xC0A8FF)
    )

    /// Cool mist, pulled from the hoodie and strap in the figure art.
    static let mist = Palette(
        name: "Mist",
        base: color(0x1C212B),
        mantle: color(0x161A22),
        surface0: color(0x273040),
        surface1: color(0x374555),
        surface2: color(0x475768),
        text: color(0xE9EEF7),
        subtext1: color(0xCBD4E2),
        subtext0: color(0xA9B6C8),
        overlay1: color(0x7F8DA0),
        overlay0: color(0x5F6D7E),
        accent: color(0xCBD6F2),
        accentAlt: color(0x9FB2CE),
        glow: color(0xA9C0DC)
    )

    static let mono = Palette(
        name: "Mono",
        base: color(0x1A1A1D),
        mantle: color(0x141416),
        surface0: color(0x26262A),
        surface1: color(0x35353B),
        surface2: color(0x44444B),
        text: color(0xF2F2F5),
        subtext1: color(0xD2D2D8),
        subtext0: color(0xAAAAB2),
        overlay1: color(0x7E7E88),
        overlay0: color(0x5E5E68),
        accent: color(0xE8E8EE),
        accentAlt: color(0xB9B9C2),
        glow: color(0x909099)
    )

    static let all: [PaletteEntry] = [
        PaletteEntry(id: "petal", palette: petal),
        PaletteEntry(id: "softPurple", palette: softPurple),
        PaletteEntry(id: "mist", palette: mist),
        PaletteEntry(id: "mono", palette: mono),
    ]

    static let accentIDs = ["auto", "pink", "lavender", "mist", "gold"]

    static func accentColor(_ id: String) -> Color? {
        switch id {
        case "pink": return color(0xF8CADD)
        case "lavender": return color(0xD3C2FF)
        case "mist": return color(0xCBD6F2)
        case "gold": return color(0xF0DCBE)
        default: return nil
        }
    }

    static func named(_ id: String) -> Palette {
        all.first { $0.id == id }?.palette ?? petal
    }

    static func resolve(name: String, accent: String) -> Palette {
        var palette = named(name)
        if let override = accentColor(accent) {
            palette.accent = override
            palette.glow = override.opacity(0.55)
        }
        return palette
    }
}
