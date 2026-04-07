import SwiftUI
import UIKit

extension Image {
    static func safeSymbol(_ name: String?, fallback: String = "bubble.left") -> Image {
        guard let name = name, !name.isEmpty else {
            return Image(systemName: fallback)
        }
        if UIImage(systemName: name) != nil {
            return Image(systemName: name)
        }
        return Image(systemName: fallback)
    }
}
