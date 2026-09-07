import Foundation

nonisolated struct SessionPluginMarketplaceError: Decodable, Sendable {
    let marketplacePath: String
    let message: String
}
