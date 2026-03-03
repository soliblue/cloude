import SwiftUI

struct StepRevealWidget: View {
    let data: [String: Any]
    @State private var revealedCount = 0

    private var title: String? { data["title"] as? String }
    private var steps: [String] { data["steps"] as? [String] ?? [] }
    private var allRevealed: Bool { revealedCount >= steps.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.indigo)
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { revealedCount = 0 }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(revealedCount > 0 ? .indigo : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(revealedCount == 0)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { revealedCount = steps.count }
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(!allRevealed ? .indigo : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(allRevealed)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { revealedCount += 1 }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(!allRevealed ? .indigo : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(allRevealed)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(index < revealedCount ? .indigo : .secondary.opacity(0.3))
                            .frame(width: 20)

                        if index < revealedCount {
                            Text(step)
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 18)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(10)
                    .background(Color.oceanGray6.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack(spacing: 4) {
                Image(systemName: allRevealed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10))
                Text("\(revealedCount)/\(steps.count) revealed")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(Color.oceanGray6.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
