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
            VStack(spacing: 1) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 1) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, color in
                            colorSwatch(color)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            VStack(spacing: 1) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    colorSwatch(color)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func colorSwatch(_ color: (hex: String, label: String?)) -> some View {
        HStack(spacing: 0) {
            Color(hexString: color.hex)
                .frame(width: useGrid ? 40 : nil, height: 44)
                .frame(maxWidth: useGrid ? nil : .infinity)

            VStack(alignment: .leading, spacing: 1) {
                if let label = color.label {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                Text(color.hex.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color.themeSecondary.opacity(0.5))
        }
        .onLongPressGesture(minimumDuration: 0.2) {
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
                        withAnimation(.easeOut(duration: 0.2)) { self.hex = nil }
                    }
            }
        }
        .animation(.easeIn(duration: 0.2), value: hex)
        .onReceive(NotificationCenter.default.publisher(for: .showFullscreenColor)) { notif in
            if let color = notif.object as? String {
                withAnimation(.easeIn(duration: 0.2)) { hex = color }
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
