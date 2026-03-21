import SwiftUI
import Foundation

struct StatLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .frame(height: 8)
            Text(text)
        }
        .font(.system(size: 9))
    }
}

struct StreamingOutput: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if text.isEmpty {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Claude is responding...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            if !text.isEmpty {
                StreamingMarkdownView(text: text, isComplete: false)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct StreamingInterleavedOutput: View {
    let text: String
    let toolCalls: [ToolCall]
    var runStats: (durationMs: Int, costUsd: Double, model: String?)? = nil

    private var groupedSegments: [StreamingSegment] {
        let topLevelTools = toolCalls
            .filter { $0.parentToolId == nil }
            .sorted { ($0.textPosition ?? 0) < ($1.textPosition ?? 0) }

        var result: [StreamingSegment] = []
        var currentIndex = 0
        var pendingTools: [ToolCall] = []

        for tool in topLevelTools {
            let position = tool.textPosition ?? 0
            if position > currentIndex && position <= text.count {
                if !pendingTools.isEmpty {
                    result.append(.tools(pendingTools))
                    pendingTools = []
                }
                let startIdx = text.index(text.startIndex, offsetBy: currentIndex)
                let endIdx = text.index(text.startIndex, offsetBy: position)
                let segment = String(text[startIdx..<endIdx])
                if !segment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(.text(segment))
                }
                currentIndex = position
            }
            pendingTools.append(tool)
        }

        if !pendingTools.isEmpty {
            result.append(.tools(pendingTools))
        }

        if currentIndex < text.count {
            let startIdx = text.index(text.startIndex, offsetBy: currentIndex)
            let remaining = String(text[startIdx...])
            if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(.text(remaining))
            }
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if text.isEmpty && toolCalls.isEmpty && runStats == nil {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Claude is responding...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                if !groupedSegments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(groupedSegments.enumerated()), id: \.offset) { _, segment in
                            switch segment {
                            case .text(let content):
                                StreamingMarkdownView(text: content, isComplete: false)
                            case .tools(let tools):
                                let allChildren = toolCalls.filter { $0.parentToolId != nil }
                                let widgetTools = tools.filter { WidgetRegistry.isWidget($0.name) }
                                let regularTools = tools.filter { !WidgetRegistry.isWidget($0.name) }

                                ForEach(widgetTools, id: \.toolId) { tool in
                                    WidgetRegistry.view(for: tool.name, input: tool.input)
                                }

                                if !regularTools.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(regularTools.reversed(), id: \.toolId) { tool in
                                                InlineToolPill(
                                                    toolCall: tool,
                                                    children: allChildren.filter { $0.parentToolId == tool.toolId }
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .padding(.horizontal, -16)
                                    .scrollClipDisabled()
                                }
                            }
                        }
                    }
                }

                if let stats = runStats {
                    HStack(spacing: 5) {
                        Text(Date(), style: .time)
                            .font(.system(size: 9))
                        RunStatsView(durationMs: stats.durationMs, costUsd: stats.costUsd, model: stats.model)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum StreamingSegment {
    case text(String)
    case tools([ToolCall])
}

struct RunStatsView: View {
    let durationMs: Int
    let costUsd: Double
    var model: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let modelDisplay = modelInfo {
                StatLabel(icon: modelDisplay.icon, text: modelDisplay.name)
            }
            StatLabel(icon: "timer", text: formattedDuration)
            StatLabel(icon: "dollarsign.circle", text: formattedCost)
        }
    }

    private var modelInfo: (name: String, icon: String)? {
        guard let model else { return nil }
        if model.contains("opus") { return ("Opus", "crown") }
        if model.contains("sonnet") { return ("Sonnet", "hare") }
        if model.contains("haiku") { return ("Haiku", "leaf") }
        return (model, "cpu")
    }

    private var formattedDuration: String {
        let seconds = Double(durationMs) / 1000.0
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let remainingSeconds = Int(seconds) % 60
            return "\(minutes)m \(remainingSeconds)s"
        }
    }

    private var formattedCost: String {
        if costUsd < 0.01 {
            return String(format: "$%.4f", costUsd)
        } else {
            return String(format: "$%.2f", costUsd)
        }
    }
}

struct WhiteboardSnapshotPill: View {
    let text: String
    @State private var showDetail = false

    private var snapshot: WhiteboardState? {
        let jsonPart = text.replacingOccurrences(of: "[whiteboard snapshot]\n", with: "")
        if let data = jsonPart.data(using: .utf8) {
            return try? JSONDecoder().decode(WhiteboardState.self, from: data)
        }
        return nil
    }

    var body: some View {
        if let state = snapshot {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
                Text("snapshot")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
                Text("\(state.elements.count) elements")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 8))
            .highPriorityGesture(TapGesture().onEnded { showDetail = true })
            .sheet(isPresented: $showDetail) {
                WhiteboardSnapshotSheet(state: state)
            }
        } else {
            Text(text)
        }
    }
}

struct WhiteboardSnapshotSheet: View {
    let state: WhiteboardState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Canvas") {
                    LabeledContent("Viewport", value: String(format: "(%.0f, %.0f) @ %.1fx", state.viewport.x, state.viewport.y, state.viewport.zoom))
                    LabeledContent("Elements", value: "\(state.elements.count)")
                }

                Section("Elements") {
                    ForEach(state.elements) { el in
                        HStack(spacing: 8) {
                            Image(systemName: elementIcon(el.type))
                                .font(.system(size: 11))
                                .foregroundColor(.accentColor)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(el.type.rawValue)
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    Text(el.id)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                HStack(spacing: 8) {
                                    if el.type != .arrow {
                                        Text(String(format: "(%.0f, %.0f)", el.x, el.y))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    if el.type == .rect || el.type == .ellipse {
                                        Text(String(format: "%.0f×%.0f", el.w, el.h))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    if let label = el.label, !label.isEmpty {
                                        Text("\"\(label)\"")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    if let from = el.from, let to = el.to {
                                        Text("\(from) → \(to)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    if let points = el.points {
                                        Text("\(points.count) pts")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            if let fill = el.fill {
                                Circle()
                                    .fill(Color(hexString: fill))
                                    .frame(width: 12, height: 12)
                            }
                            if let stroke = el.stroke {
                                Circle()
                                    .strokeBorder(Color(hexString: stroke), lineWidth: 2)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Whiteboard Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func elementIcon(_ type: WhiteboardElementType) -> String {
        switch type {
        case .rect: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .path: return "pencil.tip"
        case .arrow: return "arrow.right"
        }
    }
}
