import SwiftUI

enum ThemeColor {
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
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
