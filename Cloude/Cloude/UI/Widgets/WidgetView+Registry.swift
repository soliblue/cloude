import SwiftUI

enum WidgetRegistry {
    private static let prefix = "mcp__widgets__"

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
        switch widgetType(toolName) {
        case "function_plot": return "Function Plot"
        case "fill_in_blank": return "Fill in the Blank"
        case "interactive_function": return "Interactive Function"
        case "flashcard_deck": return "Flashcards"
        case "quiz": return "Quiz"
        case "ordering": return "Ordering"
        case "matching": return "Matching"
        case "categorization": return "Categorization"
        case "word_scramble": return "Word Scramble"
        case "sentence_builder": return "Sentence Builder"
        case "highlight_select": return "Highlight"
        case "error_correction": return "Error Correction"
        case "type_answer": return "Type Answer"
        case "step_reveal": return "Step by Step"
        case "bar_chart": return "Bar Chart"
        case "pie_chart": return "Pie Chart"
        case "scatter_plot": return "Scatter Plot"
        case "line_chart": return "Line Chart"
        case "timeline": return "Timeline"
        case "tree": return "Tree"
        case "color_palette": return "Color Palette"
        case "image_carousel": return "Images"
        default: return toolName
        }
    }

    static func iconName(_ toolName: String) -> String {
        switch widgetType(toolName) {
        case "function_plot": return "chart.xyaxis.line"
        case "fill_in_blank": return "text.badge.checkmark"
        case "interactive_function": return "slider.horizontal.3"
        case "flashcard_deck": return "rectangle.stack"
        case "quiz": return "questionmark.circle"
        case "ordering": return "arrow.up.arrow.down"
        case "matching": return "line.horizontal.3"
        case "categorization": return "tray.2"
        case "word_scramble": return "textformat.abc"
        case "sentence_builder": return "text.word.spacing"
        case "highlight_select": return "highlighter"
        case "error_correction": return "exclamationmark.triangle"
        case "type_answer": return "keyboard"
        case "step_reveal": return "list.number"
        case "bar_chart": return "chart.bar"
        case "pie_chart": return "chart.pie"
        case "scatter_plot": return "chart.dots.scatter"
        case "line_chart": return "chart.line.uptrend.xyaxis"
        case "timeline": return "calendar.day.timeline.left"
        case "tree": return "filemenu.and.selection"
        case "color_palette": return "paintpalette"
        case "image_carousel": return "photo.on.rectangle"
        default: return "puzzlepiece"
        }
    }

    static func color(_ toolName: String) -> Color {
        switch widgetType(toolName) {
        case "function_plot": return .blue
        case "fill_in_blank": return .orange
        case "interactive_function": return .purple
        case "flashcard_deck": return .indigo
        case "quiz": return .cyan
        case "ordering": return .teal
        case "matching": return .pink
        case "categorization": return .mint
        case "word_scramble": return .yellow
        case "sentence_builder": return .green
        case "highlight_select": return .yellow
        case "error_correction": return .red
        case "type_answer": return .cyan
        case "step_reveal": return .indigo
        case "bar_chart": return .blue
        case "pie_chart": return .orange
        case "scatter_plot": return .teal
        case "line_chart": return .blue
        case "timeline": return .blue
        case "tree": return .yellow
        case "color_palette": return .purple
        case "image_carousel": return .green
        default: return .secondary
        }
    }
}
