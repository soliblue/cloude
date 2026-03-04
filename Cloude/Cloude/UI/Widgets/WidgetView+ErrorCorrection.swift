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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.red)
                Text("Error Correction")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { revealed = [] }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(!revealed.isEmpty ? .red : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(revealed.isEmpty)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            revealed = Set(segments.indices.filter { segments[$0].correction != nil })
                        }
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(!allFound ? .red : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(allFound)
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

            HStack(spacing: 4) {
                Image(systemName: allFound ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10))
                Text("\(foundCount)/\(errorCount) found")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(Color.oceanGray6.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                Text(correction)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if segment.correction != nil {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    _ = revealed.insert(index)
                }
            } label: {
                Text(segment.text)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
        } else {
            Text(segment.text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }
}
