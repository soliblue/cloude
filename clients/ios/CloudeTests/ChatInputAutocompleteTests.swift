import XCTest

@testable import Cloude

final class ChatInputAutocompleteTests: XCTestCase {
    func testLatestOpenTriggerWins() {
        XCTAssertEqual(ChatInputAutocomplete.trigger(in: "/build @ios"), .mention("ios"))
        XCTAssertEqual(ChatInputAutocomplete.trigger(in: "@ios /build"), .slash("build"))
    }

    func testWhitespaceClosesTrigger() {
        XCTAssertEqual(ChatInputAutocomplete.trigger(in: "/build now"), .none)
        XCTAssertEqual(ChatInputAutocomplete.trigger(in: "@ios\nnext"), .none)
    }

    func testAgentSuggestionsRankExactPrefixAndContains() {
        let agents = [
            Agent(name: "My Code", description: ""),
            Agent(name: "Codex", description: ""),
            Agent(name: "Code", description: ""),
        ]

        XCTAssertEqual(
            ChatInputAutocomplete.agentSuggestions(agents, query: "code").map(\.title),
            ["Code", "Codex", "My Code"]
        )
    }

    func testApplyReplacesOnlyLastOpenToken() {
        let suggestion = ChatInputSuggestion(kind: .agent, title: "ios", insertText: "@ios ", icon: "person.fill")

        XCTAssertEqual(ChatInputAutocomplete.apply(suggestion, to: "@old hello @i"), "@old hello @ios ")
    }
}
