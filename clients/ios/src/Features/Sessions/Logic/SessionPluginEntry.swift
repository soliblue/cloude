import Foundation

nonisolated struct SessionPluginEntry: Identifiable {
    let plugin: SessionPlugin
    let marketplace: String
    let marketplacePath: String?
    var id: String { plugin.id }
    var parameters: [String: Any] {
        var value: [String: Any] = ["pluginName": plugin.name]
        if let marketplacePath {
            value["marketplacePath"] = marketplacePath
        } else {
            value["remoteMarketplaceName"] = marketplace
        }
        return value
    }
}
