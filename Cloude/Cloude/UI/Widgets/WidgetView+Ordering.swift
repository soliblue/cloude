import SwiftUI

struct OrderingWidget: View {
    let data: [String: Any]
    @State private var shuffledItems: [String] = []
    @State private var selectedOrder: [String] = []
    @State private var checked = false
    @State private var revealed = false
    @State private var initialized = false

    private var instruction: String? { data["instruction"] as? String }
    private var correctOrder: [String] { data["items"] as? [String] ?? [] }
    private var isCorrect: Bool { selectedOrder == correctOrder }
    private var hasInput: Bool { !selectedOrder.isEmpty }
    private var hasWrong: Bool { checked && !isCorrect }
    private var remaining: [String] { shuffledItems.filter { !selectedOrder.contains($0) } }
    private var allPlaced: Bool { selectedOrder.count == correctOrder.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.teal)
                Text("Ordering")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedOrder = []
                            checked = false
                            revealed = false
                            shuffledItems = correctOrder.shuffled()
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasInput || checked ? .teal : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasInput && !checked)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedOrder = correctOrder
                            revealed = true
                            checked = true
                        }
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasWrong && !revealed ? .teal : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasWrong || revealed)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            checked = true
                        }
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(allPlaced ? .teal : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!allPlaced)
                }
            }

            if let instruction {
                Text(instruction)
                    .font(.system(size: 14, weight: .medium))
            }

            if !remaining.isEmpty && !checked {
                FlowLayout(spacing: 8) {
                    ForEach(remaining, id: \.self) { item in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedOrder.append(item)
                            }
                        } label: {
                            Text(item)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.oceanGray6.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !selectedOrder.isEmpty {
                VStack(spacing: 4) {
                    ForEach(Array(selectedOrder.enumerated()), id: \.offset) { index, item in
                        orderRow(index: index, item: item)
                    }
                }
            }

            if checked {
                HStack(spacing: 4) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(isCorrect ? "Correct!" : "\(correctOrder.indices.filter { correctOrder[$0] == selectedOrder[$0] }.count)/\(correctOrder.count) in place")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(Color.oceanGray6.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            if !initialized {
                shuffledItems = correctOrder.shuffled()
                initialized = true
            }
        }
    }

    private func orderRow(index: Int, item: String) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(checked ? (correctOrder[index] == item ? .green : .red) : .teal)
                .frame(width: 20)

            Text(item)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)

            if checked && !revealed {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if index > 0 { selectedOrder.swapAt(index, index - 1) }
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(index > 0 ? .teal : .secondary.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if index < selectedOrder.count - 1 { selectedOrder.swapAt(index, index + 1) }
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(index < selectedOrder.count - 1 ? .teal : .secondary.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                    .disabled(index >= selectedOrder.count - 1)
                }
            }

            if !checked {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedOrder.removeAll { $0 == item }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(rowBackground(index: index, item: item))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func rowBackground(index: Int, item: String) -> Color {
        if !checked { return Color.teal.opacity(0.08) }
        return correctOrder[index] == item ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
    }
}
