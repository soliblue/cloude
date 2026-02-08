import SwiftUI
import CloudeShared

struct PlansSheet: View {
    let stages: [String: [PlanItem]]
    var isLoading: Bool = false
    var onOpenFile: ((String) -> Void)?
    var onUploadPlan: ((String, String, String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStage = "active"
    @State private var selectedTags: Set<String> = []
    @State private var showCreateSheet = false

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.oceanBackground)
        .onAppear {
            if stages[selectedStage]?.isEmpty ?? true {
                if let first = stageOrder.first(where: { !(stages[$0]?.isEmpty ?? true) }) {
                    selectedStage = first
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreatePlanSheet(initialStage: selectedStage) { stage, filename, content in
                onUploadPlan?(stage, filename, content)
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

struct CreatePlanSheet: View {
    let initialStage: String
    let onSave: (String, String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var stage: String
    @State private var description = ""
    @State private var tags = ""
    @FocusState private var titleFocused: Bool

    private let stageOrder = ["backlog", "next", "active", "testing", "done"]

    init(initialStage: String, onSave: @escaping (String, String, String) -> Void) {
        self.initialStage = initialStage
        self.onSave = onSave
        _stage = State(initialValue: initialStage == "done" ? "backlog" : initialStage)
    }

    private var filename: String {
        title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            .appending(".md")
    }

    private var markdownContent: String {
        var lines: [String] = ["# \(title)"]
        if !description.isEmpty {
            lines.append("")
            for line in description.components(separatedBy: .newlines) {
                lines.append("> \(line)")
            }
        }
        let trimmedTags = tags.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTags.isEmpty {
            lines.append("")
            lines.append("<!-- tags: \(trimmedTags) -->")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("Plan title", text: $title)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                        .focused($titleFocused)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Stage")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        ForEach(stageOrder.filter { $0 != "done" }, id: \.self) { s in
                            Button(action: { stage = s }) {
                                Text(s)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(stage == s ? Color.accentColor.opacity(0.15) : .white.opacity(0.06))
                                    .foregroundColor(stage == s ? .accentColor : .secondary.opacity(0.7))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(stage == s ? Color.accentColor.opacity(0.3) : .white.opacity(0.1), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("Brief description (optional)", text: $description, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(3...5)
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("ui, agent, security (optional)", text: $tags)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        onSave(stage, filename, markdownContent)
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundColor(title.isEmpty ? .secondary.opacity(0.3) : .accentColor)
                    }
                    .disabled(title.isEmpty)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.oceanBackground)
        .onAppear { titleFocused = true }
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
