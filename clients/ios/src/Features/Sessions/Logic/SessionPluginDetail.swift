import Foundation

nonisolated struct SessionPluginDetail: Decodable {
    let summary: SessionPlugin
    let description: String?
    let skills: [SessionPluginSkill]
    let apps: [SessionApp]
    let mcpServers: [String]
    let hooks: [SessionPluginHook]
}
