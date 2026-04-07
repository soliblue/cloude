import SwiftUI

extension AppTheme {
    var palette: ThemePalette {
        switch self {
        case .monet:
            return ThemePalette(background: 0xFFFFFF, secondary: 0xF2F2F7, tertiary: 0xE5E5ED)
        case .turner:
            return ThemePalette(background: 0xFDF6E3, secondary: 0xEEE8D5, tertiary: 0xE2DCC8)
        case .malevich:
            return ThemePalette(background: 0x000000, secondary: 0x0A0A0A, tertiary: 0x141414)
        case .bauder:
            return ThemePalette(background: 0x131A24, secondary: 0x1A2332, tertiary: 0x222C40)
        case .majorelle:
            return ThemePalette(background: 0x0C0F1F, secondary: 0x141A35, tertiary: 0x1C254B)
        case .klimt:
            return ThemePalette(background: 0x141008, secondary: 0x221A0C, tertiary: 0x302210)
        }
    }
}
