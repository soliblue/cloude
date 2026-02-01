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

extension String {
    var isValidSFSymbol: Bool {
        UIImage(systemName: self) != nil
    }
}

extension Optional where Wrapped == String {
    var isValidSFSymbol: Bool {
        guard let self = self, !self.isEmpty else { return false }
        return UIImage(systemName: self) != nil
    }
}
