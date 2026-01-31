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
                        .foregroundStyle(.blue)
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
                            Text(toolDisplayName(tool))
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.conversationSymbol ?? "cloud.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                StateIndicator(state: context.state.agentState, compact: true)
            } minimal: {
                Image(systemName: "cloud.fill")
                    .foregroundStyle(.blue)
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
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)
            } else {
                HStack(spacing: 4) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                    Text("Running")
                        .font(.caption2)
                }
            }
        case .compacting:
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                    .symbolEffect(.rotate)
                if !compact {
                    Text("Compacting")
                        .font(.caption2)
                }
            }
        case .idle:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if !compact {
                    Text("Done")
                        .font(.caption2)
                }
            }
        }
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<CloudeActivityAttributes>

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: context.attributes.conversationSymbol ?? "cloud.fill")
                .font(.body)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.conversationName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(stateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let tool = context.state.currentTool {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(toolDisplayName(tool))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            StateIndicatorCompact(state: context.state.agentState)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    var stateText: String {
        switch context.state.agentState {
        case .running: return "Working"
        case .compacting: return "Compacting"
        case .idle: return "Done"
        }
    }

    func toolDisplayName(_ name: String) -> String {
        switch name {
        case "Bash": return "running command"
        case "Read": return "reading file"
        case "Write": return "writing file"
        case "Edit": return "editing"
        case "Grep": return "searching"
        case "Glob": return "finding files"
        case "WebFetch", "WebSearch": return "fetching web"
        case "Task": return "subagent"
        case "TodoWrite": return "updating tasks"
        default: return name.lowercased()
        }
    }
}

struct StateIndicatorCompact: View {
    let state: AgentState

    var body: some View {
        switch state {
        case .running:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.7)
                .frame(width: 20, height: 20)
        case .compacting:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .symbolEffect(.rotate)
        case .idle:
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        }
    }
}
