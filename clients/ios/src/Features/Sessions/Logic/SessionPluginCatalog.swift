import Foundation

nonisolated struct SessionPluginCatalog: Decodable, Sendable {
    let marketplaces: [SessionPluginMarketplace]
    let marketplaceLoadErrors: [SessionPluginMarketplaceError]?
}
