import SwiftUI

enum ThemeColor {
    static let blue = Color(hex: 0x6E9BF0)
    static let green = Color.green
    static let red = Color.red
    static let purple = Color(hex: 0xB98AEF)
    static let orange = Color(hex: 0xDB9A6A)
    static let cyan = Color(hex: 0x78CCE1)
    static let pink = Color(hex: 0xDE97BE)
    static let yellow = Color(hex: 0xD2BF72)
    static let teal = Color(hex: 0x71C4B4)
    static let indigo = Color(hex: 0x98A3F1)
    static let mint = Color(hex: 0x93D4B6)
    static let brown = Color(hex: 0xB89073)
    static let gray = Color(hex: 0x828CA0)

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
