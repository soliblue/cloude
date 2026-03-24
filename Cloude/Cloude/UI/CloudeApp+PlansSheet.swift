import SwiftUI
import CloudeShared

struct PlansSheet: View {
    let stages: [String: [PlanItem]]
    var isLoading: Bool = false
    var fromCache: Bool = false
    var onOpenFile: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStage = "active"
    @State var selectedTags: Set<String> = []

    let stageOrder = ["backlog", "next", "active", "testing", "done"]

    func stageIcon(_ stage: String) -> String {
        switch stage {
        case "backlog": return "tray.full"
        case "next": return "arrow.right.circle"
        case "active": return "hammer"
        case "testing": return "flask"
        case "done": return "checkmark.circle"
        default: return "circle"
        }
    }

    var stagesWithCounts: [(String, Int)] {
        stageOrder.map { ($0, stages[$0]?.count ?? 0) }
    }

    var currentPlans: [PlanItem] {
        stages[selectedStage] ?? []
    }

    var filteredAndSortedPlans: [PlanItem] {
        let filtered = selectedTags.isEmpty
            ? currentPlans
            : currentPlans.filter { plan in
                guard let planTags = plan.tags else { return false }
                return !Set(planTags).isDisjoint(with: selectedTags)
            }
        return filtered.sorted { ($0.priority ?? Int.max) < ($1.priority ?? Int.max) }
    }

    var availableTags: [String] {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                if fromCache && !isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        Label("Cached", systemImage: "arrow.clockwise.icloud")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if isLoading && !stages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.themeBackground)
        .onAppear {
            if stages[selectedStage]?.isEmpty ?? true {
                if let first = stageOrder.first(where: { !(stages[$0]?.isEmpty ?? true) }) {
                    selectedStage = first
                }
            }
        }
    }

    var stagePicker: some View {
        HStack(spacing: 0) {
            ForEach(stagesWithCounts, id: \.0) { stage, count in
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedStage = stage } }) {
                    VStack(spacing: 3) {
                        Image(systemName: stageIcon(stage))
                            .font(.footnote.weight(selectedStage == stage ? .semibold : .regular))
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundColor(selectedStage == stage ? .accentColor.opacity(0.7) : .secondary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedStage == stage ? Color.accentColor.opacity(0.08) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedStage == stage ? .accentColor : .secondary.opacity(0.6))
            }
        }
        .padding(4)
        .background(.white.opacity(0.08))
        .cornerRadius(9)
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }
}
