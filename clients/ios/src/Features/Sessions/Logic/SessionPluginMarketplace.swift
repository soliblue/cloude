import Foundation

nonisolated struct SessionPluginMarketplace: Decodable, Sendable {
    let name: String
    let path: String?
    let plugins: [SessionPlugin]
}
