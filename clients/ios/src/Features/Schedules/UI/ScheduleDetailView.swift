import SwiftData
import SwiftUI

struct ScheduleDetailView: View {
    let session: Session
    let original: Schedule
    let store: ScheduleStore
    let onOpenTask: () -> Void
    @State private var history = ScheduleStore()
    @State private var remote = SessionRemoteStore()
    @State private var editing = false
    @State private var deleting = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme

    private var schedule: Schedule { store.schedules.first(where: { $0.id == original.id }) ?? original }

    var body: some View {
        List {
            Section {
                if store.isCached || history.isCached {
                    Label("Saved on this iPhone", systemImage: "iphone").font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Status", value: schedule.enabled ? "Enabled" : "Paused")
                Text(schedule.schedule.summary).font(.subheadline)
                if let next = schedule.nextDate, schedule.enabled {
                    LabeledContent("Next run") { Text(next, format: .dateTime.month().day().hour().minute()) }
                }
                Text(schedule.task.path).font(.caption.monospaced()).textSelection(.enabled)
                Text(schedule.task.prompt).textSelection(.enabled)
                LabeledContent("Model", value: schedule.task.model ?? "Host default")
                Button(schedule.enabled ? "Pause schedule" : "Enable schedule") {
                    Task {
                        if let endpoint = session.endpoint,
                            await ScheduleService.setEnabled(
                                schedule, enabled: !schedule.enabled, endpoint: endpoint, store: store)
                        {
                            await refresh()
                        }
                    }
                }.disabled(store.isMutating || !store.available)
                Button("Run now", systemImage: "play") {
                    Task {
                        if let endpoint = session.endpoint,
                            await ScheduleService.run(schedule, endpoint: endpoint, store: store)
                        {
                            await refresh()
                        }
                    }
                }.disabled(store.isMutating || schedule.activeRun != nil || !store.available)
            }
            if let error = store.error ?? history.error ?? remote.error { Text(error).foregroundStyle(.red) }
            Section("Run history") {
                ForEach(history.runs) { run in
                    Button {
                        Task {
                            if let threadId = run.threadId, UUID(uuidString: threadId) != nil,
                                let endpoint = session.endpoint,
                                await SessionRemoteService.open(
                                    threadId: threadId, endpoint: endpoint, store: remote, context: context)
                            {
                                onOpenTask()
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(run.status.capitalized).font(.headline)
                                Spacer()
                                if remote.openingId == run.threadId && run.threadId != nil { ProgressView() }
                            }
                            Text(run.date, format: .dateTime.month().day().hour().minute()).font(.caption)
                                .foregroundStyle(.secondary)
                            if let error = run.error { Text(error).font(.caption).foregroundStyle(.red) }
                            if run.threadId != nil { Text("Open task").font(.caption) }
                        }
                    }.disabled(run.threadId == nil || remote.openingId != nil)
                }
                if history.runs.isEmpty && !history.isLoading { Text("No runs yet").foregroundStyle(.secondary) }
                if history.isLoading { ProgressView() }
                if history.nextCursor != nil {
                    Button("Load older runs") {
                        Task {
                            if let endpoint = session.endpoint {
                                await ScheduleService.loadRuns(schedule, endpoint: endpoint, store: history, more: true)
                            }
                        }
                    }.disabled(history.isLoading)
                }
            }
            Section {
                Button("Delete schedule", role: .destructive) { deleting = true }
                    .disabled(schedule.activeRun != nil || store.isMutating || !store.available)
            } footer: {
                Text(
                    "Deleting a schedule keeps its completed Codex tasks. Stop an active task before deleting its schedule."
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.palette.background)
        .navigationTitle(schedule.name)
        .navigationBarTitleDisplayMode(.inline)
        .themedNavChrome()
        .toolbar { Button("Edit") { editing = true }.disabled(store.isMutating || !store.available) }
        .sheet(isPresented: $editing, onDismiss: { Task { await refresh() } }) {
            ScheduleEditorView(session: session, existing: schedule).id(session.connectionKey)
        }
        .confirmationDialog("Delete this schedule?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete schedule", role: .destructive) {
                Task {
                    if let endpoint = session.endpoint,
                        await ScheduleService.remove(schedule, endpoint: endpoint, store: store)
                    {
                        await ScheduleService.load(endpoint: endpoint, store: store)
                        dismiss()
                    }
                }
            }
        }
        .task(id: session.connectionKey) {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(schedule.activeRun == nil ? 10 : 3))
            }
        }
        .refreshable { await refresh() }
    }

    private func refresh() async {
        if let endpoint = session.endpoint {
            async let schedules: Void = ScheduleService.load(endpoint: endpoint, store: store)
            async let runs: Void = ScheduleService.loadRuns(schedule, endpoint: endpoint, store: history)
            _ = await (schedules, runs)
        }
    }
}
