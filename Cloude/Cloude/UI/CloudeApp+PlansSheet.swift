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
        Array(Set(currentPlans.compactMap { $0.tags }.flatMap { $0 })).sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !availableTags.isEmpty {
                    tagFilterChips
                        .padding(.vertical, 10)
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
                    ScrollView(showsIndicators: false) {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        ForEach(Array(stagesWithCounts.enumerated()), id: \.element.0) { i, item in
                            if i > 0 {
                                Divider().frame(height: 20)
                            }
                            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedStage = item.0 } }) {
                                Image(systemName: stageIcon(item.0))
                                    .font(.system(size: 14, weight: selectedStage == item.0 ? .semibold : .regular))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(selectedStage == item.0 ? .accentColor : .secondary.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 8)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if fromCache && !isLoading {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Divider().frame(height: 20)
                        }
                        if isLoading && !stages.isEmpty {
                            ProgressView()
                                .controlSize(.small)
                            Divider().frame(height: 20)
                        }
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
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
}
