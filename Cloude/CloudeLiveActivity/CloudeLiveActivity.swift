import ActivityKit
import WidgetKit
import SwiftUI
import CloudeShared

struct CloudeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CloudeActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.conversationSymbol ?? "cloud.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StateIndicator(state: context.state.agentState)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.conversationName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let tool = context.state.currentTool {
                        HStack(spacing: 6) {
                            Image(systemName: toolIcon(tool))
                                .font(.caption)
                            if let detail = context.state.toolDetail {
                                Text(detail)
                                    .font(.caption)
                                    .lineLimit(1)
                            } else {
                                Text(toolDisplayName(tool))
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.conversationSymbol ?? "cloud.fill")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                StateIndicator(state: context.state.agentState, compact: true)
            } minimal: {
                Image(systemName: "cloud.fill")
                    .foregroundStyle(.tint)
            }
        }
    }

    func toolIcon(_ name: String) -> String {
        switch name {
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Write": return "pencil"
        case "Edit": return "pencil.line"
        case "Grep": return "magnifyingglass"
        case "Glob": return "folder.badge.magnifyingglass"
        case "WebFetch", "WebSearch": return "globe"
        case "Task": return "person.2"
        case "TodoWrite": return "checklist"
        default: return "wrench"
        }
    }

    func toolDisplayName(_ name: String) -> String {
        switch name {
        case "Bash": return "Running command..."
        case "Read": return "Reading file..."
        case "Write": return "Writing file..."
        case "Edit": return "Editing file..."
        case "Grep": return "Searching code..."
        case "Glob": return "Finding files..."
        case "WebFetch": return "Fetching web..."
        case "WebSearch": return "Searching web..."
        case "Task": return "Running agent..."
        case "TodoWrite": return "Updating tasks..."
        default: return name
        }
    }
}

struct StateIndicator: View {
    let state: AgentState
    var compact: Bool = false

    var body: some View {
        switch state {
        case .running:
            if compact {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.6)
            } else {
                HStack(spacing: 4) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                    Text("Running")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case .compacting:
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
                    .symbolEffect(.rotate)
                if !compact {
                    Text("Compacting")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case .idle:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                if !compact {
                    Text("Done")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
