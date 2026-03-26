// Theme.swift

import SwiftUI

enum DS {
    enum Text {
        static let body: CGFloat = 13
        static let caption: CGFloat = 10
        static let footnote: CGFloat = 9
    }

    enum Icon {
        static let toolbar: CGFloat = 14
        static let tab: CGFloat = 16
        static let primary: CGFloat = 16
        static let window: CGFloat = 20
    }

    enum Pill {
        static let spacing: CGFloat = 4
        static let hPadding: CGFloat = 8
        static let vPadding: CGFloat = 4
        static let cornerRadius: CGFloat = 8
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .majorelle
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
}

enum AppTheme: String, CaseIterable {
    case monet = "Monet"
    case turner = "Turner"
    case malevich = "Malevich"
    case bauder = "Bauder"
    case majorelle = "Majorelle"
    case klimt = "Klimt"

    static var current: AppTheme {
        if let raw = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: raw) {
            return theme
        }
        return .majorelle
    }

    var colorScheme: ColorScheme {
        switch self {
        case .monet, .turner: return .light
        default: return .dark
        }
    }
}
