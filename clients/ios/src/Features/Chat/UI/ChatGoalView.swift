import SwiftUI

struct ChatGoalView: View {
    let session: Session
    @State private var objective = ""
    @State private var budget = ""
    @State private var isLoading = false
    @State private var failed = false
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Objective") {
                    TextField("What should Codex accomplish?", text: $objective, axis: .vertical).lineLimit(3...8)
                }
                Section("Optional token budget") {
                    TextField("No limit", text: $budget).keyboardType(.numberPad)
                    Text("Codex stores this objective with the conversation. Send a message to start or continue work.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let goal = session.goal {
                    Section("Progress") {
                        LabeledContent("Status", value: goal.statusLabel)
                        LabeledContent("Tokens used", value: goal.tokensUsed.formatted())
                        LabeledContent("Time used", value: "\(goal.timeUsedSeconds / 60) min")
                        if let maximum = goal.tokenBudget {
                            ProgressView(value: Double(min(goal.tokensUsed, maximum)), total: Double(max(1, maximum)))
                            Text("\(max(0, maximum - goal.tokensUsed).formatted()) tokens remaining").font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button(goal.status == "active" ? "Pause goal" : "Resume goal") {
                            isLoading = true
                            Task {
                                failed =
                                    !(await ChatGoalService.set(
                                        session: session,
                                        body: ["status": goal.status == "active" ? "paused" : "active"]))
                                isLoading = false
                            }
                        }
                        Button("Mark complete") {
                            isLoading = true
                            Task {
                                failed = !(await ChatGoalService.set(session: session, body: ["status": "complete"]))
                                isLoading = false
                            }
                        }
                        Button("Remove goal", role: .destructive) {
                            isLoading = true
                            Task {
                                if await ChatGoalService.clear(session: session) { dismiss() } else { failed = true }
                                isLoading = false
                            }
                        }
                    }
                }
                if failed {
                    Text("Could not update the remote goal. Check your connection and daemon version, then try again.")
                        .foregroundStyle(.red)
                }
                if isLoading { ProgressView() }
            }
            .disabled(isLoading)
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle("Codex goal")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isLoading = true
                        Task {
                            failed =
                                !(await ChatGoalService.set(
                                    session: session,
                                    body: [
                                        "objective": objective,
                                        "tokenBudget": Int(budget).map { $0 as Any } ?? NSNull(), "status": "active",
                                    ]))
                            isLoading = false
                        }
                    }.disabled(
                        isLoading || objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || objective.count > 4000 || (!budget.isEmpty && (Int(budget) ?? 0) <= 0))
                }
            }
            .task {
                objective = session.goal?.objective ?? ""
                budget = session.goal?.tokenBudget.map(String.init) ?? ""
                isLoading = true
                failed = !(await ChatGoalService.refresh(session: session))
                if !failed {
                    objective = session.goal?.objective ?? ""
                    budget = session.goal?.tokenBudget.map(String.init) ?? ""
                }
                isLoading = false
            }
        }
    }
}
