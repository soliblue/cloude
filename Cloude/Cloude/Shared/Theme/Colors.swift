import SwiftUI

extension Color {
    static var themeBackground: Color { Color(hex: AppTheme.current.palette.background) }
    static var themeSecondary: Color { Color(hex: AppTheme.current.palette.secondary) }
    static var themeTertiary: Color { Color(hex: AppTheme.current.palette.tertiary) }
    static func themeBackground(_ theme: AppTheme) -> Color { Color(hex: theme.palette.background) }
    static func themeSecondary(_ theme: AppTheme) -> Color { Color(hex: theme.palette.secondary) }
    static func themeTertiary(_ theme: AppTheme) -> Color { Color(hex: theme.palette.tertiary) }

    static let pastelGreen = AppColor.success
    static let pastelRed = AppColor.danger

    static func fromName(_ name: String?, default defaultColor: Color = AppColor.blue) -> Color {
        AppColor.named(name, default: defaultColor)
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
