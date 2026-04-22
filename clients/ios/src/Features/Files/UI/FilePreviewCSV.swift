import SwiftUI

struct FilePreviewCSV: View {
    let data: Data

    var body: some View {
        if let text = String(data: data, encoding: .utf8) {
            grid(rows: parse(text))
        } else {
            Text("Invalid CSV")
                .appFont(size: ThemeTokens.Text.m)
                .foregroundColor(.secondary)
        }
    }

    private func grid(rows: [[String]]) -> some View {
        FilePreviewScrollContainer(axes: [.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows.indices, id: \.self) { i in
                    row(cells: rows[i], index: i)
                }
            }
        }
    }

    private func row(cells: [String], index: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(cells.indices, id: \.self) { j in
                Text(cells[j])
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .padding(.horizontal, ThemeTokens.Spacing.s)
                    .padding(.vertical, ThemeTokens.Spacing.xs)
                    .frame(minWidth: 80, alignment: .leading)
            }
        }
        .background(background(for: index))
    }

    private func background(for row: Int) -> Color {
        if row == 0 { return ThemeColor.gray.opacity(0.2) }
        return row.isMultiple(of: 2) ? Color.clear : ThemeColor.gray.opacity(0.08)
    }

    private func parse(_ text: String) -> [[String]] {
        let delimiter: Character = text.contains("\t") && !text.contains(",") ? "\t" : ","
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuote = false
        for ch in text {
            if inQuote {
                if ch == "\"" {
                    inQuote = false
                } else {
                    field.append(ch)
                }
            } else if ch == "\"" {
                inQuote = true
            } else if ch == delimiter {
                row.append(field)
                field = ""
            } else if ch == "\n" {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if ch != "\r" {
                field.append(ch)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
