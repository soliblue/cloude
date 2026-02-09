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
        case .natural: return "Kokoro AI (~86 MB download)"
        }
    }
}

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}
