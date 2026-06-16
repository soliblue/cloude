import XCTest

@testable import Cloude

final class ChatStreamEventTests: XCTestCase {
    func testDecodesAssistantTextDelta() {
        let event = ChatStreamEvent.decode(data(#"{"seq":7,"event":{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"hello"}}}}"#))

        if case .assistantTextDelta(7, "hello") = event {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected assistant text delta")
        }
    }

    func testDecodesToolResultContentBlocks() {
        let event = ChatStreamEvent.decode(data(#"{"seq":9,"event":{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"tool-1","is_error":true,"content":[{"type":"text","text":"first"},{"type":"text","text":"second"}]}]}}}"#))

        if case .toolResult(9, "tool-1", "first\nsecond", true) = event {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected tool result")
        }
    }

    func testDecodesAssistantFinalToolUseAndContextTokens() {
        let event = ChatStreamEvent.decode(data(#"{"seq":11,"event":{"type":"assistant","parent_tool_use_id":"parent-1","message":{"model":"claude-sonnet-4-20250514","usage":{"input_tokens":10,"cache_read_input_tokens":20,"cache_creation_input_tokens":30},"content":[{"type":"text","text":"done"},{"type":"thinking","thinking":"plan"},{"type":"redacted_thinking"},{"type":"tool_use","id":"tool-1","name":"Read","input":{"file_path":"/tmp/a.swift"}}]}}}"#))

        if case let .assistantFinal(seq, text, thinking, thinkingRedacted, toolUses, model, contextTokens) = event {
            XCTAssertEqual(seq, 11)
            XCTAssertEqual(text, "done")
            XCTAssertEqual(thinking, "plan")
            XCTAssertTrue(thinkingRedacted)
            XCTAssertEqual(toolUses.first?.id, "tool-1")
            XCTAssertEqual(toolUses.first?.parentToolUseId, "parent-1")
            XCTAssertEqual(model, "claude-sonnet-4-20250514")
            XCTAssertEqual(contextTokens, 60)
        } else {
            XCTFail("Expected assistant final")
        }
    }

    private func data(_ string: String) -> Data {
        string.data(using: .utf8)!
    }
}
