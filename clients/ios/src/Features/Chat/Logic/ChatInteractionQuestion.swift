import Foundation

nonisolated struct ChatInteractionQuestion: Identifiable, Equatable {
    let id: String
    let question: String
    let options: [String]
    let isSecret: Bool
    var valueType: String = "string"
    var isRequired: Bool = true
    var defaultValue: String = ""
    var allowsCustomAnswer: Bool = true
    var optionDescriptions: [String: String] = [:]

    func value(_ answer: String) -> Any? {
        if answer.isEmpty { return isRequired ? nil : "" }
        if !allowsCustomAnswer && !options.isEmpty && !options.contains(answer) { return nil }
        switch valueType {
        case "boolean": return answer == "true" ? true : answer == "false" ? false : nil
        case "integer": return Int(answer)
        case "number": return Double(answer).flatMap { $0.isFinite ? $0 : nil }
        case "array": return (try? JSONSerialization.jsonObject(with: Data(answer.utf8))) as? [Any]
        case "object": return (try? JSONSerialization.jsonObject(with: Data(answer.utf8))) as? [String: Any]
        default: return answer
        }
    }
}
