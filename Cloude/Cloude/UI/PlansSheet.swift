import SwiftUI
import CloudeShared

struct PlansSheet: View {
    let stages: [String: [PlanItem]]
    var isLoading: Bool = false
    var onOpenFile: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStage = "active"
    @State private var selectedTags: Set<String> = []

    private let stageOrder = ["backlog", "next", "active", "testing", "done"]

    private func stageIcon(_ stage: String) -> String {
        switch stage {
        case "backlog": return "tray.full"
        case "next": return "arrow.right.circle"
        case "active": return "hammer"
        case "testing": return "flask"
        case "done": return "checkmark.circle"
        default: return "circle"
        }
    }

    private var stagesWithCounts: [(String, Int)] {
        stageOrder.map { ($0, stages[$0]?.count ?? 0) }
    }

    private var currentPlans: [PlanItem] {
        stages[selectedStage] ?? []
    }

    private var filteredAndSortedPlans: [PlanItem] {
        let filtered = selectedTags.isEmpty
            ? currentPlans
            : currentPlans.filter { plan in
                guard let planTags = plan.tags else { return false }
                return !Set(planTags).isDisjoint(with: selectedTags)
            }
        return filtered.sorted { ($0.priority ?? Int.max) < ($1.priority ?? Int.max) }
    }

    private var availableTags: [String] {
        Array(Set(stages.values.flatMap { $0 }.compactMap { $0.tags }.flatMap { $0 })).sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stagePicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                if !availableTags.isEmpty {
                    tagFilterChips
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.secondary.opacity(0.5))
                    Spacer()
                } else if currentPlans.isEmpty {
                    Spacer()
                    Text("No plans in \(selectedStage)")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.5))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredAndSortedPlans) { plan in
                                PlanCard(plan: plan, stage: selectedStage) {
                                    onOpenFile?(plan.path)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
        .onAppear {
            if stages[selectedStage]?.isEmpty ?? true {
                if let first = stageOrder.first(where: { !(stages[$0]?.isEmpty ?? true) }) {
                    selectedStage = first
                }
            }
        }
    }

    private var stagePicker: some View {
        HStack(spacing: 0) {
            ForEach(stagesWithCounts, id: \.0) { stage, count in
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedStage = stage } }) {
                    VStack(spacing: 3) {
                        Image(systemName: stageIcon(stage))
                            .font(.system(size: 14, weight: selectedStage == stage ? .semibold : .regular))
                        Text("\(count)")
                            .font(.system(size: 11))
                            .foregroundColor(selectedStage == stage ? .accentColor.opacity(0.7) : .secondary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedStage == stage ? Color.accentColor.opacity(0.08) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedStage == stage ? .accentColor : .secondary.opacity(0.6))
            }
        }
        .padding(4)
        .background(.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }

    private var tagFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button(action: { selectedTags.removeAll() }) {
                    Text("All")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
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
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedTags.contains(tag) ? tagColor(tag).opacity(0.12) : .white.opacity(0.06))
                            .foregroundColor(selectedTags.contains(tag) ? tagColor(tag) : .secondary.opacity(0.7))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(selectedTags.contains(tag) ? tagColor(tag).opacity(0.2) : .white.opacity(0.1), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tagColor(_ tag: String) -> Color {
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
}

struct PlanCard: View {
    let plan: PlanItem
    let stage: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let icon = plan.icon {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                        }
                        Text(plan.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                    }

                    if let description = plan.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    if let tags = plan.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(tagColor(tag).opacity(0.1))
                                        .foregroundColor(tagColor(tag).opacity(0.8))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                if stage == "done", let build = plan.build {
                    Text("\(build)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.06))
                        .foregroundColor(.secondary.opacity(0.6))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white.opacity(0.08))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func tagColor(_ tag: String) -> Color {
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
}
