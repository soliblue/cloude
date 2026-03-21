import ActivityKit
import WidgetKit
import SwiftUI
import CloudeShared

struct LockScreenView: View {
    let context: ActivityViewContext<CloudeActivityAttributes>

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: context.attributes.conversationSymbol ?? "cloud.fill")
                .font(.body)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.conversationName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(stateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let tool = context.state.currentTool {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if let detail = context.state.toolDetail {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text(toolDisplayName(tool))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            StateIndicatorCompact(state: context.state.agentState)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
                .foregroundStyle(.secondary)
                .symbolEffect(.rotate)
        case .idle:
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
