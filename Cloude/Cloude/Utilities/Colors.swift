import SwiftUI

extension Color {
    static var oceanBackground: Color { Color(hex: AppTheme.current.palette.background) }
    static var oceanSecondary: Color { Color(hex: AppTheme.current.palette.secondary) }
    static var oceanSurface: Color { Color(hex: AppTheme.current.palette.surface) }
    static var oceanGray6: Color { Color(hex: AppTheme.current.palette.gray6) }
    static var oceanGroupedSecondary: Color { Color(hex: AppTheme.current.palette.groupedSecondary) }
    static var oceanTertiary: Color { Color(hex: AppTheme.current.palette.tertiary) }
    static var oceanFill: Color { Color(hex: AppTheme.current.palette.fill) }
    static var oceanSystemBackground: Color { Color(hex: AppTheme.current.palette.systemBackground) }

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
