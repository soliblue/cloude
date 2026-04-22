import SwiftUI

struct EndpointsSymbolPicker: View {
    @Binding var selectedSymbol: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.appAccent) private var appAccent
    @State private var searchText = ""

    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: ThemeTokens.Spacing.xs), count: 6)

    private var filteredCategories: [(String, [String])] {
        if searchText.isEmpty { return EndpointsSymbolCatalog.categories }
        let query = searchText.lowercased()
        return EndpointsSymbolCatalog.categories.compactMap { category, symbols in
            let filtered = symbols.filter { $0.lowercased().contains(query) }
            return filtered.isEmpty ? nil : (category, filtered)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                    ForEach(filteredCategories, id: \.0) { category, symbols in
                        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                            Text(category)
                                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, ThemeTokens.Spacing.xs)

                            LazyVGrid(columns: Self.gridColumns, spacing: ThemeTokens.Spacing.m) {
                                ForEach(symbols, id: \.self) { symbol in
                                    Button {
                                        selectedSymbol = symbol
                                        dismiss()
                                    } label: {
                                        Image(systemName: symbol)
                                            .appFont(size: ThemeTokens.Icon.l)
                                            .frame(width: ThemeTokens.Size.l, height: ThemeTokens.Size.l)
                                            .background(
                                                selectedSymbol == symbol
                                                    ? appAccent.color.opacity(ThemeTokens.Opacity.m) : Color.clear
                                            )
                                            .cornerRadius(ThemeTokens.Radius.s)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "Search symbols")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .themedNavChrome()
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(theme.palette.background)
        .preferredColorScheme(theme.palette.colorScheme)
    }
}
