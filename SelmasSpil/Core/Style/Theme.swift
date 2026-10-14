import SwiftUI

/// Semantiske design-tokens. Alle views bruger disse - aldrig hårdkodede farver -
/// så hele spillet skifter udtryk, når StyleSeed opdateres med Selmas farver.
struct Theme: Sendable {
    var seed: StyleSeed

    init(seed: StyleSeed = .neutral) {
        self.seed = seed
    }

    // Farver
    var paper: Color { Color(seed.paper) }
    var ink: Color { Color(seed.ink) }
    var accent: Color { Color(seed.palette.first ?? RGBA(hex: "#BFBBB3")!) }
    var accentSecondary: Color { Color(seed.palette.dropFirst().first ?? RGBA(hex: "#8E8A82")!) }
    var card: Color { paper.opacity(0.9) }
    var inkSoft: Color { ink.opacity(0.55) }
    var selection: Color { Color(seed.palette.count > 2 ? seed.palette[2] : RGBA(hex: "#8E8A82")!) }

    // Scener udenfor (indtil Selma har tegnet himmel og jord)
    var sky: Color { Color(seed.scene.sky) }
    var asphalt: Color { Color(seed.scene.asphalt) }
    var grass: Color { Color(seed.scene.grass) }
    var bush: Color { Color(seed.scene.bush) }

    /// Børnevenlig palet til malerspanden: Selmas egne farver først, dernæst grundfarver.
    var paintPalette: [RGBA] {
        var seen = Set<String>()
        var result: [RGBA] = []
        for c in seed.palette + Theme.basicColors where !seen.contains(c.hex) {
            seen.insert(c.hex)
            result.append(c)
        }
        return result
    }

    // Form
    var cornerRadius: CGFloat { 8 + 24 * seed.roundness }
    var strokeWidth: CGFloat { max(2, CGFloat(seed.strokeWeight) * 0.6) }

    // Typografi - rund og venlig indtil vi har en font fra Selmas bogstaver
    func font(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        if let name = seed.fontName {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    static let basicColors: [RGBA] = [
        "#FF5A5F", "#FF9F1C", "#FFD93D", "#6BCB77", "#4D96FF", "#845EC2", "#FF8FAB",
        "#A0522D", "#FFFFFF", "#2B2B2B",
    ].compactMap { RGBA(hex: $0) }

    /// Hudfarver til figurer, fra helt lys til mørk - vises som egen række i malerspanden.
    static let skinTones: [RGBA] = [
        "#FFE9D6", "#FFDCC2", "#F7CBA6", "#EEC39A", "#E0AC7E", "#C98D5E", "#A86E43", "#8C5A33", "#6B4226", "#4A2E1C",
    ].compactMap { RGBA(hex: $0) }
}

extension Color {
    init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
