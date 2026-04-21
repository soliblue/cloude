import SwiftUI
import WebKit

struct FilePreviewHTML: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs
        let view = WKWebView(frame: .zero, configuration: config)
        if let html = String(data: data, encoding: .utf8) {
            view.loadHTMLString(html, baseURL: nil)
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
