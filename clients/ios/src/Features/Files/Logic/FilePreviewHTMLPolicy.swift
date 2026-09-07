import Foundation

enum FilePreviewHTMLPolicy {
    static let documentURL = URL(string: "afto-preview://document/index.html")!

    static let contentRules = """
        [{"trigger":{"url-filter":".*"},"action":{"type":"block"}},
         {"trigger":{"url-filter":"^about:blank$"},"action":{"type":"ignore-previous-rules"}},
         {"trigger":{"url-filter":"^data:"},"action":{"type":"ignore-previous-rules"}},
         {"trigger":{"url-filter":"^afto-preview://document/index[.]html([#].*)?$"},"action":{"type":"ignore-previous-rules"}}]
        """

    static func document(_ data: Data) -> String {
        """
        <!doctype html><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:; media-src data:; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
        <meta http-equiv="x-dns-prefetch-control" content="off">
        \(String(decoding: data, as: UTF8.self))
        """
    }

    static func allowsNavigation(to url: URL?) -> Bool {
        if let url {
            return url.absoluteString == "about:blank" || url.absoluteString == documentURL.absoluteString
                || url.absoluteString.hasPrefix(documentURL.absoluteString + "#")
        }
        return false
    }
}
