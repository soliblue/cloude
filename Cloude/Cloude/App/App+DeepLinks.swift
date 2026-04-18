import Foundation
import CloudeShared

extension App {
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "cloude",
              let host = url.host else { return }
        AppLogger.bootstrapInfo("handle deep link url=\(url.absoluteString)")

        if host == "screenshot" {
            captureScreenshot()
        } else {
            handleWorkspaceDeepLink(host: host, url: url)
            handleGitDeepLink(host: host, url: url)
            handleWindowDeepLink(host: host, url: url)
            handleSettingsDeepLink(host: host, url: url)
            handleWhiteboardDeepLink(host: host, url: url)
        }
    }
}

extension URL {
    func queryValue(named name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    func boolQueryValue(named name: String) -> Bool? {
        guard let value = queryValue(named: name)?.lowercased() else { return nil }
        switch value {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return nil
        }
    }
}
