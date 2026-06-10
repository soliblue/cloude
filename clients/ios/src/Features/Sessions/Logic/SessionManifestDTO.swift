import Foundation

struct SessionManifestDTO: Codable {
    let skills: [Skill]
    let agents: [Agent]
}
