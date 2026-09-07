import Foundation

nonisolated struct SessionMcpServer: Decodable, Identifiable {
    let name: String
    let authStatus: String
    let runtimeStatus: String?
    let pluginId: String?
    let tools: [String: SessionMcpTool]
    var id: String { name }
    var requiresSignIn: Bool { authStatus == "notLoggedIn" || runtimeStatus == "authenticationRequired" }
    var status: String {
        if requiresSignIn { return "Sign in on the remote machine" }
        switch runtimeStatus {
        case "connected": return "Connected"
        case "starting": return "Connecting"
        case "failed": return "Connection failed"
        case "disabled": return "Disabled"
        case "cancelled": return "Connection canceled"
        case "notStarted": return "Not started"
        default: return authStatus == "oAuth" || authStatus == "bearerToken" ? "Authenticated" : "Status unavailable"
        }
    }
}
