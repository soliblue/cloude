import SwiftUI
import UIKit

struct KeyboardDismissExemptArea: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        KeyboardDismissGesture.shared.exempt(view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
