import SwiftUI

enum WidgetRegistry {
    private static let prefix = "mcp__widgets__"

    private struct WidgetMeta {
        let displayName: String
        let icon: String
        let color: Color
    }

    private static let meta: [String: WidgetMeta] = [
        "function_plot": .init(displayName: "Function Plot", icon: "chart.xyaxis.line", color: .blue),
        "fill_in_blank": .init(displayName: "Fill in the Blank", icon: "text.badge.checkmark", color: .orange),
        "interactive_function": .init(displayName: "Interactive Function", icon: "slider.horizontal.3", color: .purple),
        "flashcard_deck": .init(displayName: "Flashcards", icon: "rectangle.stack", color: .indigo),
        "quiz": .init(displayName: "Quiz", icon: "questionmark.circle", color: .cyan),
        "ordering": .init(displayName: "Ordering", icon: "arrow.up.arrow.down", color: .teal),
        "matching": .init(displayName: "Matching", icon: "line.horizontal.3", color: .pink),
        "categorization": .init(displayName: "Categorization", icon: "tray.2", color: .mint),
        "word_scramble": .init(displayName: "Word Scramble", icon: "textformat.abc", color: .yellow),
        "sentence_builder": .init(displayName: "Sentence Builder", icon: "text.word.spacing", color: .green),
        "highlight_select": .init(displayName: "Highlight", icon: "highlighter", color: .yellow),
        "error_correction": .init(displayName: "Error Correction", icon: "exclamationmark.triangle", color: .red),
        "type_answer": .init(displayName: "Type Answer", icon: "keyboard", color: .cyan),
        "step_reveal": .init(displayName: "Step by Step", icon: "list.number", color: .indigo),
        "bar_chart": .init(displayName: "Bar Chart", icon: "chart.bar", color: .blue),
        "pie_chart": .init(displayName: "Pie Chart", icon: "chart.pie", color: .orange),
        "scatter_plot": .init(displayName: "Scatter Plot", icon: "chart.dots.scatter", color: .teal),
        "line_chart": .init(displayName: "Line Chart", icon: "chart.line.uptrend.xyaxis", color: .blue),
        "timeline": .init(displayName: "Timeline", icon: "calendar.day.timeline.left", color: .blue),
        "tree": .init(displayName: "Tree", icon: "filemenu.and.selection", color: .yellow),
        "color_palette": .init(displayName: "Color Palette", icon: "paintpalette", color: .purple),
        "image_carousel": .init(displayName: "Images", icon: "photo.on.rectangle", color: .green),
    ]

    static func isWidget(_ toolName: String) -> Bool {
        toolName.hasPrefix(prefix)
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
            case "function_plot": FunctionPlotWidget(data: data)
            case "fill_in_blank": FillInBlankWidget(data: data)
            case "interactive_function": InteractiveFunctionWidget(data: data)
            case "flashcard_deck": FlashcardDeckWidget(data: data)
            case "quiz": QuizWidget(data: data)
            case "ordering": OrderingWidget(data: data)
            case "matching": MatchingWidget(data: data)
            case "categorization": CategorizationWidget(data: data)
            case "word_scramble": WordScrambleWidget(data: data)
            case "sentence_builder": SentenceBuilderWidget(data: data)
            case "highlight_select": HighlightSelectWidget(data: data)
            case "error_correction": ErrorCorrectionWidget(data: data)
            case "type_answer": TypeAnswerWidget(data: data)
            case "step_reveal": StepRevealWidget(data: data)
            case "bar_chart": BarChartWidget(data: data)
            case "pie_chart": PieChartWidget(data: data)
            case "scatter_plot": ScatterPlotWidget(data: data)
            case "line_chart": LineChartWidget(data: data)
            case "timeline": TimelineWidget(data: data)
            case "tree": TreeWidget(data: data)
            case "color_palette": ColorPaletteWidget(data: data)
            case "image_carousel": ImageCarouselWidget(data: data)
            default: Text("Unknown widget: \(type)").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    static func displayName(_ toolName: String) -> String {
        widgetType(toolName).flatMap { meta[$0]?.displayName } ?? toolName
    }

    static func iconName(_ toolName: String) -> String {
        widgetType(toolName).flatMap { meta[$0]?.icon } ?? "puzzlepiece"
    }

    static func color(_ toolName: String) -> Color {
        widgetType(toolName).flatMap { meta[$0]?.color } ?? .secondary
    }
}
