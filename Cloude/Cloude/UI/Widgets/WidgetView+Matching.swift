import SwiftUI

struct MatchingWidget: View {
    let data: [String: Any]
    @State private var shuffledRight: [String] = []
    @State private var selectedLeft: String? = nil
    @State private var matched: [String: String] = [:]
    @State private var initialized = false

    private var instruction: String? { data["instruction"] as? String }
    private var pairs: [(left: String, right: String)] {
        guard let arr = data["pairs"] as? [[String: Any]] else { return [] }
        return arr.compactMap { pair in
            guard let left = pair["left"] as? String,
                  let right = pair["right"] as? String else { return nil }
            return (left: left, right: right)
        }
    }
    private var correctMap: [String: String] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.left, $0.right) })
    }
    private var allMatched: Bool { matched.count == pairs.count }
    private var allCorrect: Bool { matched.allSatisfy { correctMap[$0.key] == $0.value } }
    private var hasWrong: Bool { allMatched && !allCorrect }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "line.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.pink)
                Text("Matching")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            matched = [:]
                            selectedLeft = nil
                            shuffledRight = pairs.map(\.right).shuffled()
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(!matched.isEmpty ? .pink : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(matched.isEmpty)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            matched = correctMap
                            selectedLeft = nil
                        }
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasWrong ? .pink : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasWrong)
                }
            }

            if let instruction {
                Text(instruction)
                    .font(.system(size: 14, weight: .medium))
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 6) {
                    ForEach(pairs.map(\.left), id: \.self) { item in
                        leftItem(item)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    ForEach(shuffledRight, id: \.self) { item in
                        rightItem(item)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if allMatched {
                HStack(spacing: 4) {
                    Image(systemName: allCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(allCorrect ? "All correct!" : "\(matched.filter { correctMap[$0.key] == $0.value }.count)/\(pairs.count) correct")
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
                shuffledRight = pairs.map(\.right).shuffled()
                initialized = true
            }
        }
    }

    private func leftItem(_ item: String) -> some View {
        let isMatched = matched[item] != nil
        let isSelected = selectedLeft == item
        let isCorrect = isMatched && matched[item] == correctMap[item]

        return Button {
            if !isMatched {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedLeft = isSelected ? nil : item
                }
            }
        } label: {
            Text(item)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isMatched ? (isCorrect ? .green : .red) : .primary)
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(
                    isMatched ? (isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1)) :
                    isSelected ? Color.pink.opacity(0.15) : Color.oceanGray6.opacity(0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.pink : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
    }

    private func rightItem(_ item: String) -> some View {
        let isMatched = matched.values.contains(item)
        let matchedLeft = matched.first { $0.value == item }?.key
        let isCorrect = matchedLeft != nil && correctMap[matchedLeft!] == item

        return Button {
            if !isMatched, let left = selectedLeft {
                withAnimation(.easeInOut(duration: 0.2)) {
                    matched[left] = item
                    selectedLeft = nil
                }
            }
        } label: {
            Text(item)
                .font(.system(size: 13))
                .foregroundColor(isMatched ? (isCorrect ? .green : .red) : .primary)
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(
                    isMatched ? (isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1)) :
                    selectedLeft != nil ? Color.pink.opacity(0.08) : Color.oceanGray6.opacity(0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isMatched || selectedLeft == nil)
    }
}
