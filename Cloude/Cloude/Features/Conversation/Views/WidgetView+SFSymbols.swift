import SwiftUI

struct SFSymbolsWidget: View {
    let data: [String: Any]

    private var symbols: [(name: String, label: String?)] {
        guard let arr = data["symbols"] as? [[String: Any]] else { return [] }
        return arr.compactMap { item in
            guard let name = item["name"] as? String else { return nil }
            return (name: name, label: item["label"] as? String)
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.s),
        GridItem(.flexible(), spacing: DS.Spacing.s),
        GridItem(.flexible(), spacing: DS.Spacing.s),
    ]

    var body: some View {
        WidgetContainer {
            LazyVGrid(columns: columns, spacing: DS.Spacing.s) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    symbolCard(symbol)
                }
            }
        }
    }

    private func symbolCard(_ symbol: (name: String, label: String?)) -> some View {
        VStack(spacing: DS.Spacing.s) {
            Image.safeSymbol(symbol.name)
                .font(.system(size: DS.Icon.l + 4))
                .foregroundColor(.primary)
                .frame(height: DS.Size.l)

            Text(symbol.label ?? symbol.name)
                .font(.system(size: DS.Text.s, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.m)
        .padding(.horizontal, DS.Spacing.xs)
        .background(Color.themeSecondary.opacity(DS.Opacity.s))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
    }
}
