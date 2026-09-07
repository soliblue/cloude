import SwiftUI

struct ScheduleEditorView: View {
    let session: Session
    @State private var draft: ScheduleDraft
    @State private var store = ScheduleStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    init(session: Session, existing: Schedule? = nil) {
        self.session = session
        _draft = State(initialValue: ScheduleDraft(session: session, existing: existing))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Name", text: $draft.name)
                    LiteralTextField(title: "Scheduled instruction", text: $draft.prompt, lines: 5...10)
                    LabeledContent("Machine", value: session.endpoint?.displayName ?? "Remote machine")
                    Text(draft.path).font(.caption.monospaced()).textSelection(.enabled)
                }.disabled(store.isMutating || store.uncertainSave)
                Section("Schedule") {
                    Picker("Repeat", selection: $draft.kind) {
                        Text("At a set time").tag("calendar")
                        Text("At an interval").tag("interval")
                    }
                    if draft.kind == "calendar" {
                        DatePicker("Time", selection: $draft.clockTime, displayedComponents: .hourAndMinute)
                        TextField("Time zone", text: $draft.timeZone).textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        ForEach(1...7, id: \.self) { day in
                            Toggle(
                                Calendar.current.weekdaySymbols[day % 7],
                                isOn: Binding(
                                    get: { draft.days.contains(day) },
                                    set: { if $0 { draft.days.insert(day) } else { draft.days.remove(day) } }))
                        }
                    } else {
                        HStack {
                            Text("Interval in minutes")
                            TextField("60", value: $draft.minutes, format: .number)
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        }
                        Text("From 15 minutes to 10,080 minutes (one week).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.disabled(store.isMutating || store.uncertainSave)
                Section("Codex") {
                    Picker(
                        "Model",
                        selection: Binding(
                            get: { draft.model },
                            set: {
                                draft.model = $0
                                draft.effort = ""
                            })
                    ) {
                        Text("Host default").tag("")
                        if !draft.model.isEmpty {
                            Text(
                                ChatModelCatalog.shared.displayName(
                                    ChatModel(rawValue: draft.model), sessionId: session.id)
                            ).tag(draft.model)
                        }
                        ForEach(
                            ChatModelCatalog.shared.models(sessionId: session.id, provider: .codex)
                                .filter { $0.rawValue != draft.model }, id: \.self
                        ) { model in
                            Text(ChatModelCatalog.shared.displayName(model, sessionId: session.id)).tag(model.rawValue)
                        }
                    }
                    Picker("Reasoning", selection: $draft.effort) {
                        Text("Default").tag("")
                        if !draft.effort.isEmpty { Text(draft.effort.capitalized).tag(draft.effort) }
                        ForEach(
                            ChatModelCatalog.shared.efforts(
                                sessionId: session.id, provider: .codex,
                                model: ChatModel(rawValue: draft.model)
                            )
                            .filter { $0.rawValue != draft.effort }, id: \.self
                        ) { Text($0.displayName).tag($0.rawValue) }
                    }
                    Picker("Permissions", selection: $draft.permissionMode) {
                        Text("Default").tag("default")
                        Text("Plan").tag("plan")
                    }
                }.disabled(store.isMutating || store.uncertainSave)
                Section {
                    Toggle("Enabled", isOn: $draft.enabled)
                } footer: {
                    Text(
                        "Enabled tasks run on this machine even while your phone is offline and use your Codex subscription. Missed and overlapping runs are skipped. Approvals can be answered by opening the task in run history."
                    )
                }.disabled(store.isMutating || store.uncertainSave)
                if let error = store.error { Text(error).foregroundStyle(.red) }
                if store.isMutating { ProgressView("Saving…") }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle(draft.scheduleId == nil ? "New schedule" : "Edit schedule")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.uncertainSave ? "Retry save" : "Save") {
                        Task { if await ScheduleService.save(draft, session: session, store: store) { dismiss() } }
                    }.disabled(store.isMutating)
                }
            }
        }
    }
}
