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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "tray.2")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.mint)
                Text("Categorization")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            placements = [:]
                            checked = false
                            revealed = false
                            selectedCategory = nil
                            allItems = categories.flatMap(\.items).shuffled()
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasInput || checked ? .mint : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasInput && !checked)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            placements = correctMap
                            revealed = true
                            checked = true
                            selectedCategory = nil
                        }
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(hasWrong && !revealed ? .mint : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasWrong || revealed)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            checked = true
                            selectedCategory = nil
                        }
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(allPlaced && !checked ? .mint : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(!allPlaced || checked)
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
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    placements[item] = cat
                                }
                            }
                        } label: {
                            Text(item)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCategory != nil ? Color.mint.opacity(0.1) : Color.oceanGray6.opacity(0.5))
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
                HStack(spacing: 4) {
                    Image(systemName: allCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 10))
                    Text(allCorrect ? "All correct!" : "\(placements.filter { correctMap[$0.key] == $0.value }.count)/\(allItems.count) correct")
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
                .background(isSelected ? Color.mint.opacity(0.12) : Color.oceanGray6.opacity(0.5))
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
