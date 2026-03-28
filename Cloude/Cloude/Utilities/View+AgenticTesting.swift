import SwiftUI

extension View {
    @ViewBuilder
    func agenticID(_ id: String) -> some View {
        accessibilityIdentifier(id)
    }
}
