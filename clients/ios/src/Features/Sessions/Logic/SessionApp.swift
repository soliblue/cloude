import Foundation

nonisolated struct SessionApp: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let installUrl: String?
    let toolSummaries: [SessionAppTool]?

    var installURL: URL? {
        if let installUrl, let url = URL(string: installUrl), url.scheme?.lowercased() == "https",
            url.host?.isEmpty == false, url.user == nil, url.password == nil
        {
            return url
        }
        return nil
    }
}
