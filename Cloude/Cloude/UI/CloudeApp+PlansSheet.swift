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
                        .padding(.vertical, DS.Spacing.m)
                }

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.secondary.opacity(DS.Opacity.m))
                    Spacer()
                } else if currentPlans.isEmpty {
                    Spacer()
                    Text("No plans in \(selectedStage)")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary.opacity(DS.Opacity.m))
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: DS.Spacing.m) {
                            ForEach(filteredAndSortedPlans) { plan in
                                PlanCard(plan: plan, stage: selectedStage) {
                                    onOpenFile?(plan.path)
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.l)
                        .padding(.bottom, DS.Spacing.l)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: DS.Spacing.m) {
                        ForEach(Array(stagesWithCounts.enumerated()), id: \.element.0) { i, item in
                            if i > 0 {
                                Divider().frame(height: DS.Icon.m)
                            }
                            Button(action: { withAnimation(.easeInOut(duration: DS.Duration.s)) { selectedStage = item.0 } }) {
                                Image(systemName: stageIcon(item.0))
                                    .font(.system(size: DS.Icon.s, weight: selectedStage == item.0 ? .semibold : .regular))
                            }
                            .agenticID("plans_stage_\(item.0)")
                            .buttonStyle(.plain)
                            .foregroundColor(selectedStage == item.0 ? .accentColor : .secondary.opacity(DS.Opacity.l))
                        }
                    }
                    .padding(.horizontal, DS.Spacing.s)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: DS.Spacing.m) {
                        if fromCache && !isLoading {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: DS.Icon.s, weight: .medium))
                                .foregroundColor(.secondary)
                            Divider().frame(height: DS.Icon.m)
                        }
                        if isLoading && !stages.isEmpty {
                            ProgressView()
                                .controlSize(.small)
                            Divider().frame(height: DS.Icon.m)
                        }
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: DS.Icon.s, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .agenticID("plans_close_button")
                    }
                    .padding(.horizontal, DS.Spacing.s)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .agenticID("plans_view")
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
