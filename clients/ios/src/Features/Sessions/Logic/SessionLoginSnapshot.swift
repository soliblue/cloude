import Foundation

nonisolated struct SessionLoginSnapshot: Codable, Equatable {
    let status: String
    let loginId: String?
    let userCode: String?
    let verificationUrl: String?
    let error: String?

    var verificationURL: URL? {
        if status == "pending", let verificationUrl, let url = URL(string: verificationUrl),
            url.scheme?.lowercased() == "https",
            url.host?.lowercased() == "auth.openai.com", url.user == nil, url.password == nil
        {
            return url
        }
        return nil
    }
}
