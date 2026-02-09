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
