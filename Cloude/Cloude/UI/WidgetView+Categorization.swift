import SwiftUI

struct CategorizationWidget: View {
    let data: [String: Any]
    @State private var allItems: [String] = []
    @State private var placements: [String: String] = [:]
    @State private var checked = false
    @State private var revealed = false
    @State private var initialized = false
    @State private var selectedCategory: String? = nil

    private var instruction: String? { data["instruction"] as? String }
    private var categories: [(name: String, items: [String])] {
        guard let cats = data["categories"] as? [String: [String]] else { return [] }
        return cats.map { (name: $0.key, items: $0.value) }.sorted { $0.name < $1.name }
    }
    private var correctMap: [String: String] {
        var map: [String: String] = [:]
        for cat in categories {
            for item in cat.items { map[item] = cat.name }
        }
        return map
    }
    private var unplaced: [String] { allItems.filter { placements[$0] == nil } }
    private var allPlaced: Bool { unplaced.isEmpty }
    private var hasInput: Bool { !placements.isEmpty }
    private var allCorrect: Bool { placements.allSatisfy { correctMap[$0.key] == $0.value } }
    private var hasWrong: Bool { checked && !allCorrect }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "tray.2", title: "Categorization", color: .mint) {
                WidgetButton(icon: "arrow.counterclockwise", color: .mint, enabled: hasInput || checked) {
                    placements = [:]
                    checked = false
                    revealed = false
                    selectedCategory = nil
                    allItems = categories.flatMap(\.items).shuffled()
                }
                WidgetButton(icon: "eye", color: .mint, enabled: hasWrong && !revealed) {
                    placements = correctMap
                    revealed = true
                    checked = true
                    selectedCategory = nil
                }
                WidgetButton(icon: "checkmark.circle", color: .mint, enabled: allPlaced && !checked) {
                    checked = true
                    selectedCategory = nil
                }
            }

            if let instruction {
                Text(instruction)
                    .font(.system(size: 14, weight: .medium))
            }

            if !unplaced.isEmpty && !checked {
                FlowLayout(spacing: 8) {
                    ForEach(unplaced, id: \.self) { item in
                        Button {
                            if let cat = selectedCategory {
                                withAnimation(.quickTransition) {
                                    placements[item] = cat
                                }
                            }
                        } label: {
                            Text(item)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCategory != nil ? Color.mint.opacity(0.1) : Color.themeGray6.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedCategory == nil)
                    }
                }
            }

            ForEach(categories, id: \.name) { category in
                categoryBucket(category.name)
            }

            if checked {
                WidgetResultBadge(allCorrect, correct: "All correct!", wrong: "\(placements.filter { correctMap[$0.key] == $0.value }.count)/\(allItems.count) correct")
            }
        }
        .onAppear {
            if !initialized {
                allItems = categories.flatMap(\.items).shuffled()
                initialized = true
            }
        }
    }

    private func categoryBucket(_ name: String) -> some View {
        let isSelected = selectedCategory == name
        let itemsInBucket = placements.filter { $0.value == name }.map(\.key)

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                if !checked {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedCategory = isSelected ? nil : name
                    }
                }
            } label: {
                HStack {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .mint : .primary)
                    Spacer()
                    Text("\(itemsInBucket.count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(isSelected ? Color.mint.opacity(0.12) : Color.themeGray6.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.mint : .clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            if !itemsInBucket.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(itemsInBucket, id: \.self) { item in
                        let isCorrect = correctMap[item] == name
                        HStack(spacing: 4) {
                            if checked {
                                Image(systemName: isCorrect ? "checkmark" : "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(isCorrect ? .green : .red)
                            }
                            Text(item)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(checked ? (isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1)) : Color.mint.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}
