import SwiftUI

extension Color {
    static var themeBackground: Color { Color(hex: AppTheme.current.palette.background) }
    static var themeSecondary: Color { Color(hex: AppTheme.current.palette.secondary) }
    static func themeBackground(_ theme: AppTheme) -> Color { Color(hex: theme.palette.background) }
    static func themeSecondary(_ theme: AppTheme) -> Color { Color(hex: theme.palette.secondary) }

    static let pastelGreen = Color(hex: 0x7AB87A)
    static let pastelRed = Color(hex: 0xB54E5E)

    static func fromName(_ name: String?, default defaultColor: Color = .blue) -> Color {
        switch name?.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "orange": return .orange
        case "cyan": return .cyan
        case "magenta", "pink": return .pink
        case "yellow": return .yellow
        case "teal": return .teal
        case "indigo": return .indigo
        case "mint": return .mint
        default: return defaultColor
        }
    }

    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
