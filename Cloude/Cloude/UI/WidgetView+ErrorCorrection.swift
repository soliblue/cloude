import SwiftUI

struct ErrorCorrectionWidget: View {
    let data: [String: Any]
    @State private var revealed: Set<Int> = []

    private var instruction: String? { data["instruction"] as? String }
    private var segments: [(text: String, correction: String?)] {
        guard let arr = data["segments"] as? [[String: Any]] else { return [] }
        return arr.compactMap { seg in
            guard let text = seg["text"] as? String else { return nil }
            return (text: text, correction: seg["correction"] as? String)
        }
    }
    private var errorCount: Int { segments.filter { $0.correction != nil }.count }
    private var foundCount: Int { revealed.count }
    private var allFound: Bool { foundCount == errorCount }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "exclamationmark.triangle", title: "Error Correction", color: .red) {
                WidgetButton(icon: "arrow.counterclockwise", color: .red, enabled: !revealed.isEmpty) {
                    revealed = []
                }
                WidgetButton(icon: "eye", color: .red, enabled: !allFound) {
                    revealed = Set(segments.indices.filter { segments[$0].correction != nil })
                }
            }

            if let instruction {
                Text(instruction)
                    .font(.system(size: 14, weight: .medium))
            }

            FlowLayout(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    segmentView(index: index, segment: segment)
                }
            }

            WidgetProgressBadge(
                icon: allFound ? "checkmark.circle.fill" : "circle",
                text: "\(foundCount)/\(errorCount) found"
            )
        }
    }

    @ViewBuilder
    private func segmentView(index: Int, segment: (text: String, correction: String?)) -> some View {
        let isRevealed = revealed.contains(index)

        if isRevealed, let correction = segment.correction {
            VStack(spacing: 2) {
                Text(segment.text)
                    .font(.system(size: 15))
                    .strikethrough(true, color: .red)
                    .foregroundColor(.red.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                Text(correction)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if segment.correction != nil {
            Button {
                withAnimation(.quickTransition) {
                    _ = revealed.insert(index)
                }
            } label: {
                Text(segment.text)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
        } else {
            Text(segment.text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
