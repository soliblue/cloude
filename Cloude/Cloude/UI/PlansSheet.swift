import SwiftUI
import CloudeShared

struct PlansSheet: View {
    let stages: [String: [PlanItem]]
    var isLoading: Bool = false
    var onDelete: ((String, String) -> Void)?
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
                    List {
                        ForEach(currentPlans) { plan in
                            PlanCard(
                                plan: plan,
                                onTap: { onOpenFile?(plan.path) },
                                onDelete: { onDelete?(selectedStage, plan.filename) }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
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
    var onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDelete = false

    private let deleteThreshold: CGFloat = -60

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
        ZStack(alignment: .trailing) {
            if showDelete {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) { offset = -400 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDelete() }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                }
                .transition(.opacity)
            }

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
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = value.translation.width
                            showDelete = value.translation.width < deleteThreshold
                        }
                    }
                    .onEnded { value in
                        if value.translation.width < deleteThreshold {
                            withAnimation(.easeOut(duration: 0.2)) { offset = -400 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDelete() }
                        } else {
                            withAnimation(.spring(response: 0.3)) {
                                offset = 0
                                showDelete = false
                            }
                        }
                    }
            )
        }
        .clipped()
    }
}
