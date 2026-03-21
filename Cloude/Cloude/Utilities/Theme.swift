// Theme.swift

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
    case vermeer = "Vermeer"
    case turner = "Turner"
    case cezanne = "Cézanne"
    case saffron = "Saffron"
    case celadon = "Celadon"
    case morisot = "Morisot"
    case sorolla = "Sorolla"
    case wedgwood = "Wedgwood"
    case malevich = "Malevich"
    case hokusai = "Hokusai"
    case caravaggio = "Caravaggio"
    case whistler = "Whistler"
    case bauder = "Bauder"
    case vanGogh = "Van Gogh"
    case hiroshige = "Hiroshige"
    case majorelle = "Majorelle"
    case gaudi = "Gaudí"
    case klimt = "Klimt"
    case hundertwasser = "Hundertwasser"
    case mahfouz = "Mahfouz"
    case tawfik = "Tawfik"
    case rothko = "Rothko"

    static var current: AppTheme {
        if let raw = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: raw) {
            return theme
        }
        return .majorelle
    }

    var colorScheme: ColorScheme {
        switch self {
        case .monet, .vermeer, .turner, .morisot, .sorolla, .cezanne, .saffron, .celadon, .wedgwood: return .light
        default: return .dark
        }
    }
}
