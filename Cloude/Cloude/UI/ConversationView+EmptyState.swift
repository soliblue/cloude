import SwiftUI

struct EmptyConversationView: View {
    private static let characters = [
        "claude-painter",
        "claude-builder",
        "claude-scientist",
        "claude-boxer",
        "claude-explorer",
    ]

    @State private var character: String

    init() {
        _character = State(initialValue: Self.characters.randomElement()!)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(character)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
