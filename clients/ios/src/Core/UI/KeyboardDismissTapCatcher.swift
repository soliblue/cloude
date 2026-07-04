import SwiftUI
import UIKit

struct KeyboardDismissTapCatcher: ViewModifier {
    @State private var keyboardVisible = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if keyboardVisible {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder), to: nil, from: nil,
                                for: nil)
                        }
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillShowNotification)
            ) { _ in keyboardVisible = true }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillHideNotification)
            ) { _ in keyboardVisible = false }
    }
}

extension View {
    func dismissesKeyboardOnTap() -> some View {
        modifier(KeyboardDismissTapCatcher())
    }
}
