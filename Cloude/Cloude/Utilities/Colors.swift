import SwiftUI
import UIKit

extension Color {
    static let oceanBackground = Color(light: .white, dark: Color(hex: 0x0F111A))
    static let oceanSecondary = Color(light: Color(UIColor.secondarySystemBackground), dark: Color(hex: 0x1B1E2B))
    static let oceanSurface = Color(light: Color(UIColor.tertiarySystemBackground), dark: Color(hex: 0x292D3E))
    static let oceanGray6 = Color(light: Color(UIColor.systemGray6), dark: Color(hex: 0x1B1E2B))
    static let oceanGroupedSecondary = Color(light: Color(UIColor.secondarySystemGroupedBackground), dark: Color(hex: 0x1B1E2B))

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
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
