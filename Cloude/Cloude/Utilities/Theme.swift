import SwiftUI

enum TTSMode: String, CaseIterable {
    case off = "Off"
    case standard = "Standard"
    case natural = "Natural"

    var icon: String {
        switch self {
        case .off: return "speaker.slash"
        case .standard: return "speaker.wave.2"
        case .natural: return "waveform"
        }
    }

    var description: String {
        switch self {
        case .off: return "Disabled"
        case .standard: return "Built-in voice"
        case .natural: return "Kokoro AI"
        }
    }
}

enum KokoroVoice: String, CaseIterable {
    case af_heart = "af_heart"
    case af_bella = "af_bella"
    case af_nicole = "af_nicole"
    case af_sarah = "af_sarah"
    case af_sky = "af_sky"
    case am_adam = "am_adam"
    case am_michael = "am_michael"
    case bf_emma = "bf_emma"
    case bf_isabella = "bf_isabella"
    case bm_george = "bm_george"
    case bm_lewis = "bm_lewis"

    var label: String {
        switch self {
        case .af_heart: return "Heart"
        case .af_bella: return "Bella"
        case .af_nicole: return "Nicole"
        case .af_sarah: return "Sarah"
        case .af_sky: return "Sky"
        case .am_adam: return "Adam"
        case .am_michael: return "Michael"
        case .bf_emma: return "Emma"
        case .bf_isabella: return "Isabella"
        case .bm_george: return "George"
        case .bm_lewis: return "Lewis"
        }
    }

    var accent: String {
        rawValue.hasPrefix("a") ? "US" : "UK"
    }

    var gender: String {
        rawValue.dropFirst().first == "f" ? "Female" : "Male"
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
    case oceanDark = "Ocean Dark"
    case oceanLight = "Ocean Light"
    case midnight = "Midnight"
    case solarizedDark = "Solarized Dark"
    case solarizedLight = "Solarized Light"
    case monokai = "Monokai"
    case nord = "Nord"
    case dracula = "Dracula"
    case githubLight = "GitHub Light"

    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "Ocean Dark") ?? .oceanDark
    }

    var colorScheme: ColorScheme {
        switch self {
        case .oceanLight, .solarizedLight, .githubLight: return .light
        default: return .dark
        }
    }

    var icon: String {
        switch self {
        case .oceanDark: return "water.waves"
        case .oceanLight: return "sun.and.horizon"
        case .midnight: return "moon.stars.fill"
        case .solarizedDark: return "sun.dust.fill"
        case .solarizedLight: return "sun.max.fill"
        case .monokai: return "paintpalette.fill"
        case .nord: return "snowflake"
        case .dracula: return "moon.haze.fill"
        case .githubLight: return "doc.plaintext"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .oceanDark:
            return ThemePalette(
                background: 0x152233, secondary: 0x1C2B3D, surface: 0x263750,
                gray6: 0x1C2B3D, groupedSecondary: 0x1C2B3D, tertiary: 0x223350,
                fill: 0x2E4058, systemBackground: 0x152233)
        case .oceanLight:
            return ThemePalette(
                background: 0xFFFFFF, secondary: 0xF2F2F7, surface: 0xE5E5EA,
                gray6: 0xF2F2F7, groupedSecondary: 0xF2F2F7, tertiary: 0xE5E5EA,
                fill: 0xD1D1D6, systemBackground: 0xFFFFFF)
        case .midnight:
            return ThemePalette(
                background: 0x000000, secondary: 0x0A0A0A, surface: 0x161616,
                gray6: 0x0A0A0A, groupedSecondary: 0x0A0A0A, tertiary: 0x121212,
                fill: 0x1C1C1E, systemBackground: 0x000000)
        case .solarizedDark:
            return ThemePalette(
                background: 0x002B36, secondary: 0x073642, surface: 0x094753,
                gray6: 0x073642, groupedSecondary: 0x073642, tertiary: 0x094753,
                fill: 0x1A5C6B, systemBackground: 0x002B36)
        case .solarizedLight:
            return ThemePalette(
                background: 0xFDF6E3, secondary: 0xEEE8D5, surface: 0xDDD6C1,
                gray6: 0xEEE8D5, groupedSecondary: 0xEEE8D5, tertiary: 0xDDD6C1,
                fill: 0xD0C8AD, systemBackground: 0xFDF6E3)
        case .monokai:
            return ThemePalette(
                background: 0x272822, secondary: 0x2D2E27, surface: 0x3E3D32,
                gray6: 0x2D2E27, groupedSecondary: 0x2D2E27, tertiary: 0x3E3D32,
                fill: 0x49483E, systemBackground: 0x272822)
        case .nord:
            return ThemePalette(
                background: 0x2E3440, secondary: 0x3B4252, surface: 0x434C5E,
                gray6: 0x3B4252, groupedSecondary: 0x3B4252, tertiary: 0x434C5E,
                fill: 0x4C566A, systemBackground: 0x2E3440)
        case .dracula:
            return ThemePalette(
                background: 0x282A36, secondary: 0x313347, surface: 0x3D4058,
                gray6: 0x313347, groupedSecondary: 0x313347, tertiary: 0x3D4058,
                fill: 0x44475A, systemBackground: 0x282A36)
        case .githubLight:
            return ThemePalette(
                background: 0xFFFFFF, secondary: 0xF6F8FA, surface: 0xE1E4E8,
                gray6: 0xF6F8FA, groupedSecondary: 0xF6F8FA, tertiary: 0xE1E4E8,
                fill: 0xD1D5DA, systemBackground: 0xFFFFFF)
        }
    }
}
