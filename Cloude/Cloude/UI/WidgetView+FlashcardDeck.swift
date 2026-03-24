import SwiftUI

struct FlashcardDeckWidget: View {
    let data: [String: Any]
    @State private var currentIndex = 0
    @State private var flipped = false

    private var title: String? { data["title"] as? String }
    private var cards: [(front: String, back: String)] {
        guard let arr = data["cards"] as? [[String: Any]] else { return [] }
        return arr.compactMap { card in
            guard let front = card["front"] as? String,
                  let back = card["back"] as? String else { return nil }
            return (front: front, back: back)
        }
    }

    private var currentCard: (front: String, back: String)? {
        cards.indices.contains(currentIndex) ? cards[currentIndex] : nil
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "rectangle.stack", title: title, color: .indigo) {
                Text("\(currentIndex + 1)/\(cards.count)")
                    .font(.caption2.weight(.medium).monospaced())
                    .foregroundColor(.secondary)
            }

            if let card = currentCard {
                HStack(spacing: 10) {
                    Button {
                        flipped = false
                        currentIndex = currentIndex > 0 ? currentIndex - 1 : cards.count - 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.indigo)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { flipped.toggle() }
                    } label: {
                        VStack(spacing: 6) {
                            Text(flipped ? "ANSWER" : "QUESTION")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(flipped ? .indigo.opacity(0.5) : .secondary.opacity(0.4))
                                .tracking(1.5)

                            Text(flipped ? card.back : card.front)
                                .font(.subheadline.weight(flipped ? .semibold : .regular))
                                .foregroundColor(flipped ? .indigo : .primary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color.themeGray6.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .id(currentIndex)

                    Button {
                        flipped = false
                        currentIndex = currentIndex < cards.count - 1 ? currentIndex + 1 : 0
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.indigo)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
