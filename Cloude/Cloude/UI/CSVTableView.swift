import SwiftUI

struct CSVTableView: View {
    let rows: [[String]]
    let hasHeader: Bool

    init(text: String, delimiter: Character = ",") {
        let parsed = CSVTableView.parse(text, delimiter: delimiter)
        self.rows = parsed
        self.hasHeader = parsed.count > 1
    }

    var body: some View {
        if rows.isEmpty {
            Text("Empty file")
                .foregroundColor(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    if hasHeader, let header = rows.first {
                        headerRow(header)
                        Divider()
                    }
                    ForEach(Array(dataRows.enumerated()), id: \.offset) { i, row in
                        dataRow(row, isEven: i % 2 == 0)
                    }
                }
            }
        }
    }

    private var dataRows: [[String]] {
        hasHeader ? Array(rows.dropFirst()) : rows
    }

    @ViewBuilder
    private func headerRow(_ cells: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, cell in
                Text(cell)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .lineLimit(1)
                    .frame(width: columnWidth(i), alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
        }
        .background(Color.oceanSecondary)
    }

    @ViewBuilder
    private func dataRow(_ cells: [String], isEven: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, cell in
                Text(cell)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .frame(width: columnWidth(i), alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
        .background(isEven ? Color.clear : Color.oceanSecondary.opacity(0.5))
    }

    private func columnWidth(_ index: Int) -> CGFloat {
        let maxLen = rows.reduce(0) { max, row in
            guard index < row.count else { return max }
            return Swift.max(max, row[index].count)
        }
        return CGFloat(Swift.max(Swift.min(maxLen, 40), 6)) * 8 + 16
    }

    private static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var current: [String] = []
        var field = ""
        var inQuotes = false

        for char in text {
            if inQuotes {
                if char == "\"" {
                    inQuotes = false
                } else {
                    field.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == delimiter {
                    current.append(field.trimmingCharacters(in: .whitespaces))
                    field = ""
                } else if char == "\n" {
                    current.append(field.trimmingCharacters(in: .whitespaces))
                    if !current.allSatisfy({ $0.isEmpty }) {
                        rows.append(current)
                    }
                    current = []
                    field = ""
                } else if char == "\r" {
                    continue
                } else {
                    field.append(char)
                }
            }
        }

        if !field.isEmpty || !current.isEmpty {
            current.append(field.trimmingCharacters(in: .whitespaces))
            if !current.allSatisfy({ $0.isEmpty }) {
                rows.append(current)
            }
        }

        let maxCols = rows.map(\.count).max() ?? 0
        return rows.map { row in
            row + Array(repeating: "", count: Swift.max(0, maxCols - row.count))
        }
    }
}
