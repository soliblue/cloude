// Theme+Palettes.swift

import SwiftUI

extension AppTheme {
    var palette: ThemePalette {
        switch self {
        case .monet:
            return ThemePalette(background: 0xFFFFFF, secondary: 0xF2F2F7)
        case .turner:
            return ThemePalette(background: 0xFDF6E3, secondary: 0xEEE8D5)
        case .malevich:
            return ThemePalette(background: 0x000000, secondary: 0x0A0A0A)
        case .bauder:
            return ThemePalette(background: 0x131A24, secondary: 0x1A2332)
        case .majorelle:
            return ThemePalette(background: 0x0C0F1F, secondary: 0x141A35)
        case .klimt:
            return ThemePalette(background: 0x141008, secondary: 0x221A0C)
        }
    }
}
