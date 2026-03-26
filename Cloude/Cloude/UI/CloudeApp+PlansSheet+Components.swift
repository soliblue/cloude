import SwiftUI
import CloudeShared

extension PlansSheet {
    var tagFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                Button(action: { selectedTags.removeAll() }) {
                    Text("All")
                        .font(.system(size: DS.Text.m, weight: .medium))
                        .padding(.horizontal, DS.Spacing.m)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(selectedTags.isEmpty ? Color.accentColor.opacity(0.1) : .white.opacity(0.06))
                        .foregroundColor(selectedTags.isEmpty ? .accentColor : .secondary.opacity(0.7))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(selectedTags.isEmpty ? Color.accentColor.opacity(0.2) : .white.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                ForEach(availableTags, id: \.self) { tag in
                    Button(action: {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }) {
                        Text(tag)
                            .font(.system(size: DS.Text.m, weight: .medium))
                            .padding(.horizontal, DS.Spacing.m)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(selectedTags.contains(tag) ? planTagColor(tag).opacity(0.12) : .white.opacity(0.06))
                            .foregroundColor(selectedTags.contains(tag) ? planTagColor(tag) : .secondary.opacity(0.7))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(selectedTags.contains(tag) ? planTagColor(tag).opacity(0.2) : .white.opacity(0.1), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.l)
        }
    }
}

func planTagColor(_ tag: String) -> Color {
    switch tag {
    case "ui": return .blue
    case "agent": return .purple
    case "security": return .red
    case "reliability": return .orange
    case "heartbeat": return .pink
    case "memory": return .green
    case "autonomy": return .indigo
    case "plans": return .teal
    case "refactor": return .gray
    case "teams": return .cyan
    case "files": return .brown
    case "git": return .mint
    case "tools": return .yellow
    case "input": return .blue
    case "markdown": return .purple
    case "conversations": return .green
    case "windows": return .indigo
    case "messages": return .orange
    case "skills": return .pink
    case "performance": return .red
    default: return .secondary
    }
}
