import SwiftUI

enum WidgetRegistry {
    private static let prefix = "mcp__ios__"

    private struct WidgetMeta {
        let displayName: String
        let icon: String
    }

    private static let meta: [String: WidgetMeta] = [
        "pie_chart": .init(displayName: "Pie Chart", icon: "chart.pie"),
        "timeline": .init(displayName: "Timeline", icon: "calendar.day.timeline.left"),
        "tree": .init(displayName: "Tree", icon: "filemenu.and.selection"),
        "color_palette": .init(displayName: "Color Palette", icon: "paintpalette"),
        "image_carousel": .init(displayName: "Images", icon: "photo.on.rectangle"),
        "sf_symbols": .init(displayName: "SF Symbols", icon: "square.grid.2x2"),
    ]

    static func isWidget(_ toolName: String) -> Bool {
        guard toolName.hasPrefix(prefix) else { return false }
        return meta.keys.contains(String(toolName.dropFirst(prefix.count)))
    }

    static func widgetType(_ toolName: String) -> String? {
        if isWidget(toolName) { return String(toolName.dropFirst(prefix.count)) }
        return nil
    }

    static func parseInput(_ jsonString: String?) -> [String: Any]? {
        guard let str = jsonString, let data = str.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return dict
    }

    @ViewBuilder
    static func view(for toolName: String, input: String?) -> some View {
        if let type = widgetType(toolName), let data = parseInput(input) {
            switch type {
            case "pie_chart": PieChartWidget(data: data)
            case "timeline": TimelineWidget(data: data)
            case "tree": TreeWidget(data: data)
            case "color_palette": ColorPaletteWidget(data: data)
            case "image_carousel": ImageCarouselWidget(data: data)
            case "sf_symbols": SFSymbolsWidget(data: data)
            default: Text("Unknown widget: \(type)").font(.system(size: DS.Text.s)).foregroundColor(.secondary)
            }
        }
    }

    static func displayName(_ toolName: String) -> String {
        widgetType(toolName).flatMap { meta[$0]?.displayName } ?? toolName
    }

    static func iconName(_ toolName: String) -> String {
        widgetType(toolName).flatMap { meta[$0]?.icon } ?? "puzzlepiece"
    }
}
