import AppKit
import Foundation
import WebKit

@main struct FileHTMLTests {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let base = "http://127.0.0.1:\(CommandLine.arguments[1])"
        for value in [
            "https://example.com", "file:///etc/passwd", "data:text/html,bad", "about:blank?x", "javascript:alert(1)",
            "afto-preview://document/index.html?remote=1", "afto-preview://document/other.html",
        ] {
            precondition(!FilePreviewHTMLPolicy.allowsNavigation(to: URL(string: value)))
        }
        precondition(
            FilePreviewHTMLPolicy.allowsNavigation(to: URL(string: "afto-preview://document/index.html#section")))
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        view.load(URLRequest(url: URL(string: "\(base)/control")!))
        for _ in 0..<100 {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "\(base)/counts")!)
            if String(decoding: data, as: UTF8.self).contains("control") { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        let (control, _) = try await URLSession.shared.data(from: URL(string: "\(base)/counts")!)
        precondition(String(decoding: control, as: UTF8.self).contains("control"), "Network control did not load")
        let controller = FilePreviewHTMLController()
        controller.view.frame = NSRect(x: 0, y: 0, width: 640, height: 480)
        precondition(!controller.view.configuration.websiteDataStore.isPersistent)
        precondition(!controller.view.configuration.defaultWebpagePreferences.allowsContentJavaScript)
        controller.load(
            Data(
                """
                <html><head><meta http-equiv="refresh" content="0;url=\(base)/refresh"><base href="\(base)/"><link rel="stylesheet" href="\(base)/style">
                <style>@import url('\(base)/import'); p { color: rgb(1, 2, 3); background-image: url('\(base)/css-image') }</style>
                </head><body><p id="safe">safe artifact</p><a id="anchor" href="#safe">Jump</a>
                <img src="\(base)/image"><img src="relative.png"><iframe src="\(base)/frame"></iframe>
                <object data="\(base)/object"></object><script>window.unsafeRan=true;fetch('\(base)/script')</script>
                <form action="\(base)/form"><input name="secret" value="test"></form>
                <img id="embedded" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7">
                </body></html>
                """.utf8))
        var loaded = false
        for _ in 0..<100 {
            if let result = try? await controller.view.evaluateJavaScript(
                "document.getElementById('safe')?.textContent"), result as? String == "safe artifact"
            {
                loaded = true
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        precondition(loaded, "Contained HTML did not render")
        let color = try await controller.view.evaluateJavaScript(
            "getComputedStyle(document.getElementById('safe')).color")
        precondition(color as? String == "rgb(1, 2, 3)", "Inline styles must render")
        let scripted = try await controller.view.evaluateJavaScript("window.unsafeRan === true")
        precondition(scripted as? Bool == false, "Page script executed")
        let embedded = try await controller.view.evaluateJavaScript("document.getElementById('embedded').naturalWidth")
        precondition(embedded as? Int == 1, "Embedded image blocked")
        _ = try await controller.view.evaluateJavaScript("document.getElementById('anchor').click()")
        try await Task.sleep(for: .milliseconds(200))
        precondition(controller.view.url?.fragment == "safe", "Same-document anchor blocked")
        _ = try await controller.view.evaluateJavaScript("document.forms[0].submit()")
        controller.view.load(URLRequest(url: URL(string: "\(base)/external-navigation")!))
        try await Task.sleep(for: .milliseconds(500))
        let (requests, _) = try await URLSession.shared.data(from: URL(string: "\(base)/counts")!)
        let captured = try JSONDecoder().decode([String].self, from: requests)
        precondition(captured == ["/control"], String(decoding: requests, as: UTF8.self))
        controller.load(Data("<p id='replacement'>replacement</p>".utf8))
        try await Task.sleep(for: .milliseconds(300))
        let replacement = try await controller.view.evaluateJavaScript(
            "document.getElementById('replacement').textContent")
        precondition(replacement as? String == "replacement", "Changed cached content did not reload")
        controller.stop()
        view.stopLoading()
        print(
            "HTML WebKit tests passed: real network control, zero artifact requests, scripts blocked, inline CSS/data image, anchors, navigation and content replacement"
        )
    }
}
