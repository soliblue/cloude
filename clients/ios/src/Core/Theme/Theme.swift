import SwiftUI

enum Theme: String, CaseIterable {
    case malevich = "Malevich"
    case bauder = "Bauder"
    case majorelle = "Majorelle"
    case klimt = "Klimt"

    struct Palette {
        let background: Color
        let surface: Color
        let elevated: Color
        let colorScheme: ColorScheme

        init(background: UInt32, surface: UInt32, elevated: UInt32, colorScheme: ColorScheme) {
            self.background = Color(hex: background)
            self.surface = Color(hex: surface)
            self.elevated = Color(hex: elevated)
            self.colorScheme = colorScheme
        }
    }

    var palette: Palette {
        switch self {
        case .malevich: return Self.malevichPalette
        case .bauder: return Self.bauderPalette
        case .majorelle: return Self.majorellePalette
        case .klimt: return Self.klimtPalette
        }
    }

    private static let malevichPalette = Palette(
        background: 0x000000, surface: 0x0A0A0A, elevated: 0x141414, colorScheme: .dark)
    private static let bauderPalette = Palette(
        background: 0x131A24, surface: 0x1A2332, elevated: 0x222C40, colorScheme: .dark)
    private static let majorellePalette = Palette(
        background: 0x0C0F1F, surface: 0x141A35, elevated: 0x1C254B, colorScheme: .dark)
    private static let klimtPalette = Palette(
        background: 0x141008, surface: 0x221A0C, elevated: 0x302210, colorScheme: .dark)
}
