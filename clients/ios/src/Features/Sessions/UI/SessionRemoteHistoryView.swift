import SwiftData
import SwiftUI

struct SessionRemoteHistoryView: View {
    let endpoint: Endpoint
    @State private var store = SessionRemoteStore()
    @State private var search = ""
    @State private var archived = false
    @State private var sections = SessionSectionStore()
    @State private var section = SessionSectionFilter.all
    @State private var managingSections = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                Toggle("Archived chats", isOn: $archived)
                if endpoint.capabilities?.contains("codexSections") == true {
                    Picker("Section", selection: $section) {
                        Text("All chats").tag(SessionSectionFilter.all)
                        Text("No section").tag(SessionSectionFilter.unsectioned)
                        ForEach(sections.sections) { Text($0.name).tag(SessionSectionFilter.section($0.id)) }
                    }
                    Button("Manage sections") { managingSections = true }
                    if sections.nextCursor != nil && !sections.isLoading {
                        Button("Load more sections") {
                            Task { await SessionSectionService.load(endpoint: endpoint, store: sections, more: true) }
                        }
                    }
                    if let error = sections.error { Text(error).font(.caption).foregroundStyle(.secondary) }
                }
                if let error = store.error {
                    Text(error).foregroundStyle(.red)
                }
                ForEach(store.threads) { thread in
                    Button {
                        Task {
                            if await SessionRemoteService.open(
                                thread, endpoint: endpoint, store: store, context: context, restoreArchived: archived)
                            {
                                dismiss()
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                            HStack {
                                Text(thread.title).font(.headline).lineLimit(2)
                                if store.openingId == thread.id { ProgressView() }
                            }
                            Text(thread.cwd).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(
                                .middle)
                            Text(Date(timeIntervalSince1970: thread.updatedAt), style: .relative).font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(store.openingId != nil)
                    .contextMenu {
                        Button(archived ? "Unarchive" : "Archive", systemImage: "archivebox") {
                            Task {
                                await SessionRemoteService.archive(
                                    thread, archived: !archived, endpoint: endpoint, store: store, context: context)
                            }
                        }
                    }
                }
                if store.isLoading { ProgressView() }
                if store.nextCursor != nil && !store.isLoading {
                    Button("Load more") {
                        Task {
                            await SessionRemoteService.load(
                                endpoint: endpoint, store: store, search: search, archived: archived, more: true,
                                section: section)
                        }
                    }
                }
                if store.threads.isEmpty && !store.isLoading && store.error == nil {
                    ContentUnavailableView(
                        "No remote chats", systemImage: "bubble.left.and.bubble.right",
                        description: Text("Codex conversations on this machine appear here."))
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle("Remote Codex chats")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .searchable(text: $search)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(
                isPresented: $managingSections,
                onDismiss: {
                    Task {
                        await SessionSectionService.load(endpoint: endpoint, store: sections)
                        if case .section(let id) = section, sections.nextCursor == nil,
                            sections.error == nil, !sections.sections.contains(where: { $0.id == id })
                        {
                            section = .all
                        }
                        await SessionRemoteService.load(
                            endpoint: endpoint, store: store, search: search, archived: archived, section: section)
                    }
                }
            ) { SessionSectionView(endpoint: endpoint).id(endpoint.cacheId) }
            .task(id: endpoint.cacheId) {
                if endpoint.capabilities?.contains("codexSections") == true {
                    await SessionSectionService.load(endpoint: endpoint, store: sections)
                }
            }
            .task(id: "\(search)|\(archived)|\(section)|\(endpoint.cacheId)") {
                try? await Task.sleep(for: .milliseconds(250))
                if !Task.isCancelled {
                    await SessionRemoteService.load(
                        endpoint: endpoint, store: store, search: search, archived: archived, section: section)
                }
            }
            .refreshable {
                await SessionRemoteService.load(
                    endpoint: endpoint, store: store, search: search, archived: archived, section: section)
            }
        }
    }
}
