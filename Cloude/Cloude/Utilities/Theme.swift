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
        static let xxs: CGFloat = 6
        static let s: CGFloat = 14
        static let m: CGFloat = 28
        static let l: CGFloat = 36
        static let xl: CGFloat = 44
        static let xxl: CGFloat = 200
    }

    enum Scale {
        static let shrink: CGFloat = 0.6
        static let small: CGFloat = 0.7
        static let compact: CGFloat = 0.8
        static let grow: CGFloat = 1.2
    }

    enum Shadow {
        static let radius: CGFloat = 6
        static let offset: CGFloat = 3
        static let radiusL: CGFloat = 10
        static let offsetL: CGFloat = 5
    }

    enum Stroke {
        static let thin: CGFloat = 0.5
        static let regular: CGFloat = 1
        static let medium: CGFloat = 1.5
        static let thick: CGFloat = 2
    }

    enum Duration {
        static let instant: Double = 0.08
        static let quick: Double = 0.15
        static let normal: Double = 0.2
        static let smooth: Double = 0.25
        static let slow: Double = 0.3
        static let pulse: Double = 0.8
    }

    enum Opacity {
        static let ghost: Double = 0.04
        static let faint: Double = 0.08
        static let subtle: Double = 0.12
        static let light: Double = 0.15
        static let medium: Double = 0.2
        static let strong: Double = 0.3
        static let half: Double = 0.5
        static let heavy: Double = 0.7
        static let full: Double = 0.85
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
