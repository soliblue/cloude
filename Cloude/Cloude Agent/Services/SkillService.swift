import Foundation
import CloudeShared

struct SkillService {
    static func loadSkills(from projectRoot: String?) -> [Skill] {
        guard let root = projectRoot else { return [] }

        let skillsDir = root.appendingPathComponent(".claude/skills")
        guard FileManager.default.fileExists(atPath: skillsDir) else { return [] }

        do {
            let entries = try FileManager.default.contentsOfDirectory(atPath: skillsDir)
            return entries.compactMap { entry -> Skill? in
                let entryPath = skillsDir.appendingPathComponent(entry)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: entryPath, isDirectory: &isDir) else { return nil }

                if isDir.boolValue {
                    let skillFile = entryPath.appendingPathComponent("SKILL.md")
                    return parseSkillFile(at: skillFile)
                } else if entry.hasSuffix(".md") {
                    return parseSkillFile(at: entryPath)
                }
                return nil
            }.filter { $0.userInvocable }
        } catch {
            Log.error("Failed to read skills directory: \(error)")
            return []
        }
    }

    private static func parseSkillFile(at path: String) -> Skill? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }

        guard content.hasPrefix("---") else { return nil }
        guard let endIndex = content.range(of: "\n---\n", range: content.index(content.startIndex, offsetBy: 3)..<content.endIndex) else { return nil }

        let frontmatter = String(content[content.index(content.startIndex, offsetBy: 4)..<endIndex.lowerBound])

        var name: String?
        var description: String?
        var userInvocable = true
        var icon: String?
        var aliases: [String] = []
        var parameters: [SkillParameter] = []
        var argumentHint: String?

        var inMetadata = false

        for line in frontmatter.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed == "metadata:" {
                inMetadata = true
                continue
            }

            if inMetadata {
                if line.hasPrefix("  "), let colonIndex = trimmed.firstIndex(of: ":") {
                    let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    switch key {
                    case "icon":
                        icon = value
                    case "aliases":
                        let trimmedVal = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                        aliases = trimmedVal.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    default:
                        break
                    }
                    continue
                }
                inMetadata = false
            }

            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            switch key {
            case "name": name = value
            case "description": description = value
            case "user-invocable": userInvocable = value == "true"
            case "argument-hint": argumentHint = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            default: break
            }
        }

        if parameters.isEmpty, let argumentHint, !argumentHint.isEmpty {
            let required = argumentHint.contains("<") && argumentHint.contains(">")
            parameters = [SkillParameter(name: "input", placeholder: argumentHint, required: required)]
        }

        guard let n = name, let d = description else { return nil }
        return Skill(name: n, description: d, userInvocable: userInvocable, icon: icon, aliases: aliases, parameters: parameters)
    }
}
