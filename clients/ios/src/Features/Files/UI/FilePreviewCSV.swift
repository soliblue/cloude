import SwiftUI

struct FilePreviewCSV: View {
    let data: Data
    var tabSeparated = false
    @State private var rows: [[String]] = []

    var body: some View {
        FilePreviewScrollContainer(axes: [.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows.indices, id: \.self) { i in
                    row(cells: rows[i], index: i)
                }
            }
        }
        .task(id: data) { rows = await FileCSVService.rows(data, tabSeparated: tabSeparated) }
    }

    private func row(cells: [String], index: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(cells.indices, id: \.self) { j in
                Text(cells[j])
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .padding(.horizontal, ThemeTokens.Spacing.s)
                    .padding(.vertical, ThemeTokens.Spacing.xs)
                    .frame(width: 160, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .background(background(for: index))
    }

    private func background(for row: Int) -> Color {
        if row == 0 { return ThemeColor.gray.opacity(0.2) }
        return row.isMultiple(of: 2) ? Color.clear : ThemeColor.gray.opacity(0.08)
    }

}
