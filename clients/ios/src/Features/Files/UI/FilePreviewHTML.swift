import SwiftUI
import WebKit

struct FilePreviewHTML: UIViewRepresentable {
    let data: Data

    func makeCoordinator() -> FilePreviewHTMLController { FilePreviewHTMLController() }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.view.accessibilityLabel = "Offline HTML preview"
        return context.coordinator.view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { context.coordinator.load(data) }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: FilePreviewHTMLController) { coordinator.stop() }
}
