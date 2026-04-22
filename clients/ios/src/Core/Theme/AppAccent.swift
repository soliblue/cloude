import SwiftUI

enum AppAccent: String, CaseIterable {
    case clay = "Clay"
    case sky = "Sky"
    case mint = "Mint"
    case violet = "Violet"
    case rose = "Rose"
    case gold = "Gold"

    var color: Color {
        switch self {
        case .clay: return Color(hex: 0xCC7257)
        case .sky: return Color(hex: 0x4C8DFF)
        case .mint: return Color(hex: 0x57B89A)
        case .violet: return Color(hex: 0x8A63D2)
        case .rose: return Color(hex: 0xD5678F)
        case .gold: return Color(hex: 0xC99A34)
        }
    }
}
