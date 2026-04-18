import SwiftUI

enum AppColor {
    static let blue = Color.blue
    static let green = Color.green
    static let red = Color.red
    static let purple = Color.purple
    static let orange = Color.orange
    static let cyan = Color.cyan
    static let pink = Color.pink
    static let yellow = Color.yellow
    static let teal = Color.teal
    static let indigo = Color.indigo
    static let mint = Color.mint
    static let brown = Color.brown
    static let gray = Color.gray

    static let rust = Color(hex: 0xDE7630)
    static let success = Color(hex: 0x7AB87A)
    static let danger = Color(hex: 0xB54E5E)

    static func named(_ name: String?, default defaultColor: Color = AppColor.blue) -> Color {
        switch name?.lowercased() {
        case "blue": return blue
        case "green": return green
        case "red": return red
        case "purple": return purple
        case "orange": return orange
        case "cyan": return cyan
        case "magenta", "pink": return pink
        case "yellow": return yellow
        case "teal": return teal
        case "indigo": return indigo
        case "mint": return mint
        case "brown": return brown
        case "gray", "grey": return gray
        default: return defaultColor
        }
    }
}
