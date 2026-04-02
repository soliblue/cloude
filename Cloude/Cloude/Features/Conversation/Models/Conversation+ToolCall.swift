import Foundation
import CloudeShared

enum ToolCallState: String, Codable {
    case executing
    case complete
}

struct ToolCall: Codable, Equatable {
    let name: String
    let input: String?
    let toolId: String
    let parentToolId: String?
    var textPosition: Int?
    var state: ToolCallState
    var resultSummary: String?
    var resultOutput: String?
    var editInfo: EditInfo?

    init(name: String, input: String?, toolId: String = UUID().uuidString, parentToolId: String? = nil, textPosition: Int? = nil, state: ToolCallState = .complete, editInfo: EditInfo? = nil) {
        self.name = name
        self.input = input
        self.toolId = toolId
        self.parentToolId = parentToolId
        self.textPosition = textPosition
        self.state = state
        self.resultSummary = nil
        self.resultOutput = nil
        self.editInfo = editInfo
    }

    init(from stored: StoredToolCall) {
        self.init(name: stored.name, input: stored.input, toolId: stored.toolId, parentToolId: stored.parentToolId, textPosition: stored.textPosition, editInfo: stored.editInfo)
        self.resultOutput = stored.resultContent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        input = try container.decodeIfPresent(String.self, forKey: .input)
        toolId = try container.decode(String.self, forKey: .toolId)
        parentToolId = try container.decodeIfPresent(String.self, forKey: .parentToolId)
        textPosition = try container.decodeIfPresent(Int.self, forKey: .textPosition)
        state = try container.decodeIfPresent(ToolCallState.self, forKey: .state) ?? .complete
        resultSummary = try container.decodeIfPresent(String.self, forKey: .resultSummary)
        resultOutput = try container.decodeIfPresent(String.self, forKey: .resultOutput)
        editInfo = try container.decodeIfPresent(EditInfo.self, forKey: .editInfo)
    }

    private enum CodingKeys: String, CodingKey {
        case name, input, toolId, parentToolId, textPosition, state, resultSummary, resultOutput, editInfo
    }

    var isScript: Bool {
        guard name == "Bash", let input else { return false }
        return BashCommandParser.isScript(input)
    }

    var filePath: String? {
        guard let input else { return nil }
        if ["Read", "Write", "Edit"].contains(name) { return input }
        return nil
    }
}
