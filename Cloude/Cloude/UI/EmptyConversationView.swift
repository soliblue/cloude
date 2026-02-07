import SwiftUI

struct EmptyConversationView: View {
    private static let characters: [(image: String, greeting: String)] = [
        ("baby-claude", "goo goo ga ga"),
        ("chef-claude", "what are we cooking?"),
        ("grandpa-claude", "back in my day..."),
        ("cowboy-claude", "howdy, partner"),
        ("wizard-claude", "cast a prompt"),
        ("ninja-claude", "lurking in the shadows"),
        ("artist-claude", "let's make something"),
    ]

    @State private var character: (image: String, greeting: String)

    init() {
        let c = Self.characters.randomElement()!
        _character = State(initialValue: c)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(character.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
            Text(character.greeting)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .italic()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
