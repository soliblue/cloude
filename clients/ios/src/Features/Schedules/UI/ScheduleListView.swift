import SwiftUI

struct ScheduleListView: View {
    let session: Session
    var initialScheduleId: String? = nil
    @State private var store = ScheduleStore()
    @State private var creating = false
    @State private var initialPresented = false
    @State private var initialConsumed = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(session.endpoint?.displayName ?? "Remote machine").font(.headline)
                    Text(
                        "Each run starts a separate Codex task on this machine. Review its work and approvals in run history."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                if store.isCached {
                    Label("Saved on this iPhone", systemImage: "iphone").font(.caption).foregroundStyle(.secondary)
                }
                if let error = store.error { Text(error).foregroundStyle(.red) }
                ForEach(store.schedules) { schedule in
                    NavigationLink {
                        ScheduleDetailView(
                            session: session, original: schedule, store: store, onOpenTask: { dismiss() })
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(schedule.name).font(.headline)
                                Spacer()
                                Text(schedule.enabled ? "Enabled" : "Paused").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(schedule.schedule.summary).font(.caption).foregroundStyle(.secondary)
                            if let run = schedule.activeRun {
                                Text(run.status.capitalized).font(.caption).foregroundStyle(.orange)
                            } else if let next = schedule.nextDate, schedule.enabled {
                                Text(next, format: .dateTime.month().day().hour().minute()).font(.caption)
                            }
                        }
                    }
                }
                if store.isLoading { ProgressView("Refreshing schedules…") }
                if store.schedules.isEmpty && !store.isLoading && store.error == nil {
                    ContentUnavailableView(
                        "No scheduled tasks", systemImage: "calendar.badge.clock",
                        description: Text("Schedule recurring reviews, checks, or coding tasks on this machine."))
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle("Scheduled tasks")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .navigationDestination(isPresented: $initialPresented) {
                if let schedule = store.schedules.first(where: { $0.id == initialScheduleId }) {
                    ScheduleDetailView(session: session, original: schedule, store: store, onOpenTask: { dismiss() })
                } else {
                    ContentUnavailableView(
                        "Schedule unavailable", systemImage: "calendar.badge.exclamationmark",
                        description: Text("This schedule may have been deleted on the remote machine."))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("New schedule", systemImage: "plus") { creating = true }.disabled(!store.available)
                }
            }
            .sheet(isPresented: $creating, onDismiss: { Task { await refresh() } }) {
                ScheduleEditorView(session: session).id(session.connectionKey)
            }
            .onChange(of: store.isCached) { _, cached in
                if cached && !initialConsumed && store.schedules.contains(where: { $0.id == initialScheduleId }) {
                    initialConsumed = true
                    initialPresented = true
                }
            }
            .task(id: session.connectionKey) { await refresh() }
            .refreshable { await refresh() }
        }
    }

    private func refresh() async {
        if let endpoint = session.endpoint {
            await ScheduleService.load(endpoint: endpoint, store: store)
            if initialScheduleId != nil && !initialConsumed && !Task.isCancelled
                && (store.error == nil
                    || (store.isCached && store.schedules.contains(where: { $0.id == initialScheduleId })))
            {
                initialConsumed = true
                initialPresented = true
            }
        }
    }
}
