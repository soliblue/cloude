import SwiftUI

struct ChatViewMessageListRowMarkdownBlockTable: View {
    let rows: [[String]]

    private var columnCount: Int { rows.map(\.count).max() ?? 0 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    if rowIndex > 0 { Divider() }
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { colIndex in
                            ChatViewMessageListRowMarkdownBlockTableCell(
                                text: colIndex < row.count
                                    ? row[colIndex].trimmingCharacters(in: .whitespaces) : "",
                                isHeader: rowIndex == 0
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minWidth: ThemeTokens.Size.l)
                            .background(
                                rowIndex == 0
                                    ? Color.gray.opacity(ThemeTokens.Opacity.s) : Color.clear)
                        }
                    }
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.l)
        }
        .padding(.horizontal, -ThemeTokens.Spacing.l)
        .scrollClipDisabled()
    }
}
