import SwiftUI

extension Color {
    static var themeBackground: Color { Color(hex: AppTheme.current.palette.background) }
    static var themeSecondary: Color { Color(hex: AppTheme.current.palette.secondary) }
    static var themeSurface: Color { Color(hex: AppTheme.current.palette.surface) }
    static var themeGray6: Color { Color(hex: AppTheme.current.palette.gray6) }
    static var themeGroupedSecondary: Color { Color(hex: AppTheme.current.palette.groupedSecondary) }
    static var themeTertiary: Color { Color(hex: AppTheme.current.palette.tertiary) }
    static var themeFill: Color { Color(hex: AppTheme.current.palette.fill) }
    static var themeSystemBackground: Color { Color(hex: AppTheme.current.palette.systemBackground) }

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
