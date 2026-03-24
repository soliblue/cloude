// TextSizeScale.swift

import SwiftUI

enum TextSizeScale {
    static let steps: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2
    ]

    static let defaultStep = 3

    static func size(for step: Int) -> DynamicTypeSize {
        steps[min(max(step, 0), steps.count - 1)]
    }

    static func label(for step: Int) -> String {
        switch size(for: step) {
        case .xSmall: return "XS"
        case .small: return "S"
        case .medium: return "M"
        case .large: return "Default"
        case .xLarge: return "XL"
        case .xxLarge: return "XXL"
        case .xxxLarge: return "XXXL"
        case .accessibility1: return "A1"
        case .accessibility2: return "A2"
        default: return "Default"
        }
    }
}
