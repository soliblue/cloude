import SwiftUI

struct EmptyConversationView: View {
    private static let characters = [
        "baby-claude",
        "chef-claude",
        "grandpa-claude",
        "cowboy-claude",
        "wizard-claude",
        "ninja-claude",
        "artist-claude",
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
                .frame(width: 160, height: 160)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
