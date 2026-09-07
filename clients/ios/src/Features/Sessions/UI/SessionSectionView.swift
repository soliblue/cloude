import SwiftUI

struct SessionSectionView: View {
    let endpoint: Endpoint
    var session: Session? = nil
    @State private var store = SessionSectionStore()
    @State private var editing: SessionSection?
    @State private var name = ""
    @State private var naming = false
    @State private var deleting = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                if let session {
                    Section {
                        Button("No section", systemImage: "tray") {
                            Task {
                                if await SessionSectionService.move(session: session, sectionId: nil, store: store) {
                                    dismiss()
                                }
                            }
                        }
                    } footer: {
                        Text("Move this task to a section saved on \(endpoint.displayName).")
                    }
                }
                Section("Sections") {
                    ForEach(store.sections) { section in
                        HStack {
                            if let session {
                                Button(section.name) {
                                    Task {
                                        if await SessionSectionService.move(
                                            session: session, sectionId: section.id, store: store)
                                        {
                                            dismiss()
                                        }
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(section.name).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Menu {
                                Button("Rename", systemImage: "pencil") {
                                    editing = section
                                    name = section.name
                                    naming = true
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    editing = section
                                    deleting = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .accessibilityLabel("Manage \(section.name)")
                        }
                    }
                    Button("New section", systemImage: "plus") {
                        editing = nil
                        name = ""
                        naming = true
                    }
                }
                if let error = store.error {
                    Section {
                        Text(error).foregroundStyle(.red)
                        Button("Reload sections") {
                            Task { await SessionSectionService.load(endpoint: endpoint, store: store) }
                        }
                    }
                }
                if store.isLoading || store.isMutating { ProgressView() }
                if store.nextCursor != nil && !store.isLoading {
                    Button("Load more") {
                        Task { await SessionSectionService.load(endpoint: endpoint, store: store, more: true) }
                    }
                }
            }
            .disabled(store.isMutating)
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle(session == nil ? "Codex sections" : "Move to section")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert(editing == nil ? "New section" : "Rename section", isPresented: $naming) {
                TextField("Name", text: $name)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    Task {
                        _ = await SessionSectionService.save(
                            name: name, sectionId: editing?.id, endpoint: endpoint, store: store)
                    }
                }.disabled(!SessionSectionStore.validName(name))
            }
            .confirmationDialog("Delete section?", isPresented: $deleting, presenting: editing) { section in
                Button("Delete \(section.name)", role: .destructive) {
                    Task { _ = await SessionSectionService.remove(section, endpoint: endpoint, store: store) }
                }
            } message: { _ in
                Text("Delete this section from Codex on this machine. Its tasks are kept and moved to No section.")
            }
            .task(id: endpoint.cacheId) { await SessionSectionService.load(endpoint: endpoint, store: store) }
            .refreshable { await SessionSectionService.load(endpoint: endpoint, store: store) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await SessionSectionService.load(endpoint: endpoint, store: store) } }
            }
        }
    }
}
