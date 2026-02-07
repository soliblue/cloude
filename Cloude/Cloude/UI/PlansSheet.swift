import SwiftUI
import CloudeShared

struct PlansSheet: View {
    let stages: [String: [PlanItem]]
    var isLoading: Bool = false
    var onOpenFile: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStage = "active"

    private let stageOrder = ["active", "testing", "next", "backlog"]

    private var stagesWithCounts: [(String, Int)] {
        stageOrder.map { ($0, stages[$0]?.count ?? 0) }
    }

    private var currentPlans: [PlanItem] {
        stages[selectedStage] ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stagePicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                if isLoading {
                    Spacer()
                    ProgressView()
                    Text("Loading plans...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                } else if currentPlans.isEmpty {
                    Spacer()
                    Text("No plans in \(selectedStage)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(currentPlans) { plan in
                                PlanCard(plan: plan) {
                                    onOpenFile?(plan.path)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                        Text(stage.capitalized)
                            .font(.system(size: 13, weight: selectedStage == stage ? .semibold : .regular))
                        Text("\(count)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedStage == stage ? Color.accentColor.opacity(0.12) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedStage == stage ? .accentColor : .secondary)
            }
        }
        .padding(4)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct PlanCard: View {
    let plan: PlanItem
    var onTap: () -> Void

    private var previewText: String {
        let lines = plan.content.components(separatedBy: .newlines)
        let bodyLines = lines.drop { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || trimmed.hasPrefix("# ")
        }
        let preview = bodyLines.prefix(5).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? plan.content.prefix(200).description : String(preview.prefix(200))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(plan.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(previewText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
