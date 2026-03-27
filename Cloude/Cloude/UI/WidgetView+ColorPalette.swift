import SwiftUI

extension Notification.Name {
    static let showFullscreenColor = Notification.Name("showFullscreenColor")
}

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

    private var useGrid: Bool { colors.count > 3 }

    var body: some View {
        if useGrid {
            let rows = stride(from: 0, to: colors.count, by: 2).map { i in
                Array(colors[i..<min(i + 2, colors.count)])
            }
            VStack(spacing: DS.Spacing.xs) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, color in
                            colorSwatch(color)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
        } else {
            VStack(spacing: DS.Spacing.xs) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    colorSwatch(color)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
        }
    }

    private func colorSwatch(_ color: (hex: String, label: String?)) -> some View {
        HStack(spacing: 0) {
            Color(hexString: color.hex)
                .frame(width: useGrid ? DS.Size.xl : nil, height: DS.Size.xl)
                .frame(maxWidth: useGrid ? nil : .infinity)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                if let label = color.label {
                    Text(label)
                        .font(.system(size: DS.Text.s, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                Text(color.hex.uppercased())
                    .font(.system(size: DS.Text.s, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, DS.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: DS.Size.xl)
            .background(Color.themeSecondary.opacity(DS.Opacity.half))
        }
        .onLongPressGesture(minimumDuration: DS.Duration.normal) {
            NotificationCenter.default.post(name: .showFullscreenColor, object: color.hex)
        }
    }
}

struct FullscreenColorOverlay: View {
    @State private var hex: String?

    var body: some View {
        ZStack {
            if let hex {
                Color(hexString: hex)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: DS.Duration.normal)) { self.hex = nil }
                    }
            }
        }
        .animation(.easeIn(duration: DS.Duration.normal), value: hex)
        .onReceive(NotificationCenter.default.publisher(for: .showFullscreenColor)) { notif in
            if let color = notif.object as? String {
                withAnimation(.easeIn(duration: DS.Duration.normal)) { hex = color }
            }
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
