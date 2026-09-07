import Foundation
import WebKit

@MainActor final class FilePreviewHTMLController: NSObject, WKNavigationDelegate {
    let view: WKWebView
    private var loadTask: Task<Void, Never>?
    private var content: Data?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        view = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        view.navigationDelegate = self
        view.allowsLinkPreview = false
    }

    func load(_ data: Data) {
        if content != data {
            content = data
            loadTask?.cancel()
            loadTask = Task { [weak self] in
                let rules = try? await WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: "AftoOfflineHTML-v1", encodedContentRuleList: FilePreviewHTMLPolicy.contentRules)
                if let self, !Task.isCancelled, let rules {
                    view.configuration.userContentController.removeAllContentRuleLists()
                    view.configuration.userContentController.add(rules)
                    view.loadHTMLString(
                        FilePreviewHTMLPolicy.document(data), baseURL: FilePreviewHTMLPolicy.documentURL)
                } else if let self, !Task.isCancelled {
                    view.loadHTMLString(
                        "<p>Preview unavailable. Use Show source to read this file.</p>",
                        baseURL: FilePreviewHTMLPolicy.documentURL)
                }
            }
        }
    }

    func stop() {
        loadTask?.cancel()
        view.stopLoading()
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(
            navigationAction.targetFrame?.isMainFrame == true
                && navigationAction.navigationType != .formSubmitted
                && navigationAction.navigationType != .formResubmitted
                && FilePreviewHTMLPolicy.allowsNavigation(to: navigationAction.request.url) ? .allow : .cancel)
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        decisionHandler(
            navigationResponse.isForMainFrame
                && FilePreviewHTMLPolicy.allowsNavigation(to: navigationResponse.response.url)
                ? .allow : .cancel)
    }
}
