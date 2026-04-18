import SwiftUI

extension Color {
    static var themeBackground: Color { Color(hex: AppTheme.current.palette.background) }
    static var themeSecondary: Color { Color(hex: AppTheme.current.palette.secondary) }
    static func themeBackground(_ theme: AppTheme) -> Color { Color(hex: theme.palette.background) }
    static func themeSecondary(_ theme: AppTheme) -> Color { Color(hex: theme.palette.secondary) }
    static func themeTertiary(_ theme: AppTheme) -> Color { Color(hex: theme.palette.tertiary) }

    static let pastelGreen = AppColor.success
    static let pastelRed = AppColor.danger

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
