import Foundation

extension App {
    func handleWindowDeepLink(host: String, url: URL) {
        switch host {
        case "window":
            dismissTransientUI()
            if url.path == "/new" {
                createWindow(tab: (url.queryValue(named: "tab") ?? url.queryValue(named: "type")).flatMap(WindowTab.init(rawValue:)))
            } else if url.path == "/close" {
                closeActiveWindow()
            } else if url.path == "/edit" {
                openEditActiveWindow()
            } else if let indexValue = url.queryValue(named: "index"),
                      let index = Int(indexValue) {
                selectWindow(index: index)
            }
        case "tab":
            dismissTransientUI()
            if let tab = (url.queryValue(named: "tab") ?? url.queryValue(named: "type")).flatMap(WindowTab.init(rawValue:)) {
                setActiveWindowTab(tab)
            }
        default:
            break
        }
    }
}
