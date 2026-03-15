import SwiftUI

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .vanGogh
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

struct ThemePalette {
    let background: UInt
    let secondary: UInt
    let surface: UInt
    let gray6: UInt
    let groupedSecondary: UInt
    let tertiary: UInt
    let fill: UInt
    let systemBackground: UInt
}

enum AppTheme: String, CaseIterable {
    case monet = "Monet"
    case turner = "Turner"
    case morisot = "Morisot"
    case sorolla = "Sorolla"
    case cezanne = "Cézanne"
    case saffron = "Saffron"
    case celadon = "Celadon"
    case wedgwood = "Wedgwood"
    case hokusai = "Hokusai"
    case caravaggio = "Caravaggio"
    case whistler = "Whistler"
    case hiroshige = "Hiroshige"
    case vanGogh = "Van Gogh"
    case gaudi = "Gaudí"
    case klimt = "Klimt"
    case hundertwasser = "Hundertwasser"
    case majorelle = "Majorelle"
    case rothko = "Rothko"
    case malevich = "Malevich"

    static var current: AppTheme {
        if let raw = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: raw) {
            return theme
        }
        return .majorelle
    }

    var colorScheme: ColorScheme {
        switch self {
        case .monet, .turner, .morisot, .sorolla, .cezanne, .saffron, .celadon, .wedgwood: return .light
        default: return .dark
        }
    }

    var palette: ThemePalette {
        switch self {
        case .monet:
            return ThemePalette(
                background: 0xFFFFFF, secondary: 0xF2F2F7, surface: 0xE5E5EA,
                gray6: 0xF2F2F7, groupedSecondary: 0xF2F2F7, tertiary: 0xE5E5EA,
                fill: 0xD1D1D6, systemBackground: 0xFFFFFF)
        case .turner:
            return ThemePalette(
                background: 0xFDF6E3, secondary: 0xEEE8D5, surface: 0xDDD6C1,
                gray6: 0xEEE8D5, groupedSecondary: 0xEEE8D5, tertiary: 0xDDD6C1,
                fill: 0xD0C8AD, systemBackground: 0xFDF6E3)
        case .morisot:
            return ThemePalette(
                background: 0xF3EDF6, secondary: 0xE8DFF0, surface: 0xD9CDE5,
                gray6: 0xE8DFF0, groupedSecondary: 0xE8DFF0, tertiary: 0xD9CDE5,
                fill: 0xC4B3D4, systemBackground: 0xF3EDF6)
        case .sorolla:
            return ThemePalette(
                background: 0xF5F8FC, secondary: 0xE8EEF6, surface: 0xDAE3F0,
                gray6: 0xE8EEF6, groupedSecondary: 0xE8EEF6, tertiary: 0xDAE3F0,
                fill: 0xC5D2E3, systemBackground: 0xF5F8FC)
        case .cezanne:
            return ThemePalette(
                background: 0xF4F2EC, secondary: 0xE8E4D8, surface: 0xDAD4C4,
                gray6: 0xE8E4D8, groupedSecondary: 0xE8E4D8, tertiary: 0xDAD4C4,
                fill: 0xC5BDAA, systemBackground: 0xF4F2EC)
        case .saffron:
            return ThemePalette(
                background: 0xF7EFD4, secondary: 0xEDE3BE, surface: 0xDFD3A6,
                gray6: 0xEDE3BE, groupedSecondary: 0xEDE3BE, tertiary: 0xDFD3A6,
                fill: 0xC9BA85, systemBackground: 0xF7EFD4)
        case .celadon:
            return ThemePalette(
                background: 0xE4EDE6, secondary: 0xD5E2D8, surface: 0xC2D4C6,
                gray6: 0xD5E2D8, groupedSecondary: 0xD5E2D8, tertiary: 0xC2D4C6,
                fill: 0xA5BAA9, systemBackground: 0xE4EDE6)
        case .wedgwood:
            return ThemePalette(
                background: 0xDDE6F0, secondary: 0xCDD8E8, surface: 0xBBC9DD,
                gray6: 0xCDD8E8, groupedSecondary: 0xCDD8E8, tertiary: 0xBBC9DD,
                fill: 0xA0B4CC, systemBackground: 0xDDE6F0)
        case .hokusai:
            return ThemePalette(
                background: 0x2E3440, secondary: 0x3B4252, surface: 0x434C5E,
                gray6: 0x3B4252, groupedSecondary: 0x3B4252, tertiary: 0x434C5E,
                fill: 0x4C566A, systemBackground: 0x2E3440)
        case .caravaggio:
            return ThemePalette(
                background: 0x282A36, secondary: 0x313347, surface: 0x3D4058,
                gray6: 0x313347, groupedSecondary: 0x313347, tertiary: 0x3D4058,
                fill: 0x44475A, systemBackground: 0x282A36)
        case .whistler:
            return ThemePalette(
                background: 0x272822, secondary: 0x2D2E27, surface: 0x3E3D32,
                gray6: 0x2D2E27, groupedSecondary: 0x2D2E27, tertiary: 0x3E3D32,
                fill: 0x49483E, systemBackground: 0x272822)
        case .hiroshige:
            return ThemePalette(
                background: 0x002B36, secondary: 0x073642, surface: 0x094753,
                gray6: 0x073642, groupedSecondary: 0x073642, tertiary: 0x094753,
                fill: 0x1A5C6B, systemBackground: 0x002B36)
        case .vanGogh:
            return ThemePalette(
                background: 0x152233, secondary: 0x1C2B3D, surface: 0x263750,
                gray6: 0x1C2B3D, groupedSecondary: 0x1C2B3D, tertiary: 0x223350,
                fill: 0x2E4058, systemBackground: 0x152233)
        case .gaudi:
            return ThemePalette(
                background: 0x0E1A12, secondary: 0x162118, surface: 0x1E3328,
                gray6: 0x162118, groupedSecondary: 0x162118, tertiary: 0x1E3328,
                fill: 0x2B4A38, systemBackground: 0x0E1A12)
        case .klimt:
            return ThemePalette(
                background: 0x141008, secondary: 0x221A0C, surface: 0x352912,
                gray6: 0x221A0C, groupedSecondary: 0x221A0C, tertiary: 0x352912,
                fill: 0x4E3D1C, systemBackground: 0x141008)
        case .hundertwasser:
            return ThemePalette(
                background: 0x1A0E0A, secondary: 0x2A1810, surface: 0x3D2618,
                gray6: 0x2A1810, groupedSecondary: 0x2A1810, tertiary: 0x3D2618,
                fill: 0x5A3A24, systemBackground: 0x1A0E0A)
        case .majorelle:
            return ThemePalette(
                background: 0x0C0F1F, secondary: 0x141A35, surface: 0x1E2750,
                gray6: 0x141A35, groupedSecondary: 0x141A35, tertiary: 0x1E2750,
                fill: 0x2A3568, systemBackground: 0x0C0F1F)
        case .rothko:
            return ThemePalette(
                background: 0x140A0E, secondary: 0x241218, surface: 0x3A1C26,
                gray6: 0x241218, groupedSecondary: 0x241218, tertiary: 0x3A1C26,
                fill: 0x522A38, systemBackground: 0x140A0E)
        case .malevich:
            return ThemePalette(
                background: 0x000000, secondary: 0x0A0A0A, surface: 0x161616,
                gray6: 0x0A0A0A, groupedSecondary: 0x0A0A0A, tertiary: 0x121212,
                fill: 0x1C1C1E, systemBackground: 0x000000)
        }
    }
}
