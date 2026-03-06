import SwiftUI

struct ColorPaletteWidget: View {
    let data: [String: Any]

    private var title: String? { data["title"] as? String }
    private var colors: [(hex: String, label: String?)] {
        guard let arr = data["colors"] as? [[String: Any]] else { return [] }
        return arr.compactMap { item in
            guard let hex = item["hex"] as? String else { return nil }
            return (hex: hex, label: item["label"] as? String)
        }
    }

    var body: some View {
        WidgetContainer {
            WidgetHeader(icon: "paintpalette", title: title ?? "Color Palette", color: .purple)

            VStack(spacing: 0) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    HStack(spacing: 0) {
                        Color(hexString: color.hex)
                            .frame(height: 56)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(color.hex.uppercased())
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                            if let label = color.label {
                                Text(label)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 56)
                        .background(Color.oceanGray6.opacity(0.5))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

extension Color {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(hex: UInt(value))
    }
}
