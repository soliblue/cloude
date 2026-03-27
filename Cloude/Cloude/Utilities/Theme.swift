// Theme.swift

import SwiftUI

enum DS {
    enum Text {
        static let m: CGFloat = 13
        static let s: CGFloat = 10
    }

    enum Icon {
        static let s: CGFloat = 14
        static let m: CGFloat = 16
        static let l: CGFloat = 19
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 6
        static let m: CGFloat = 9
        static let l: CGFloat = 12
    }

    enum Size {
        static let m: CGFloat = 28
        static let l: CGFloat = 44
        static let xxl: CGFloat = 200
    }

    enum Scale {
        static let s: CGFloat = 0.6
        static let m: CGFloat = 0.9
        static let l: CGFloat = 1.2
    }

    enum Stroke {
        static let s: CGFloat = 0.6
        static let m: CGFloat = 1.2
        static let l: CGFloat = 1.8
    }

    enum Duration {
        static let s: Double = 0.2
        static let m: Double = 0.5
        static let l: Double = 0.8
    }

    enum Opacity {
        static let s: Double = 0.15
        static let m: Double = 0.4
        static let l: Double = 0.7
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
