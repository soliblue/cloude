import SwiftData
import SwiftUI

struct SessionProjectPicker: View {
    let session: Session
    let endpoint: Endpoint
    let onPick: () -> Void
    @Query private var recentSessions: [Session]
    @State private var store = SessionProjectStore()
    @Environment(\.theme) private var theme

    init(session: Session, endpoint: Endpoint, onPick: @escaping () -> Void) {
        self.session = session
        self.endpoint = endpoint
        self.onPick = onPick
        let endpointId = endpoint.id
        _recentSessions = Query(
            filter: #Predicate<Session> { $0.endpoint?.id == endpointId && $0.path != nil },
            sort: [SortDescriptor(\.lastOpenedAt, order: .reverse)])
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    FolderPickerView(
                        session: session, endpoint: endpoint, path: "~", title: endpoint.displayName,
                        onPick: { path in
                            SessionActions.setEndpoint(endpoint, for: session)
                            SessionActions.setPath(path, for: session)
                            onPick()
                        })
                } label: {
                    Label("Browse remote folders", systemImage: "folder")
                }
            }
            if !store.selectableProjects.isEmpty {
                Section(store.isCached ? "Saved Codex projects" : "Codex projects") {
                    ForEach(store.selectableProjects) { project in
                        if project.selectableRoots.count == 1, let root = project.selectableRoots.first {
                            SessionProjectRootButton(
                                session: session, endpoint: endpoint, project: project, root: root, onPick: onPick)
                        } else if !project.selectableRoots.isEmpty {
                            DisclosureGroup(project.displayName) {
                                ForEach(project.selectableRoots) { root in
                                    SessionProjectRootButton(
                                        session: session, endpoint: endpoint, project: project, root: root,
                                        onPick: onPick)
                                }
                            }
                        }
                    }
                    if store.nextCursor != nil {
                        Button("Load more projects") {
                            Task { await SessionProjectService.load(endpoint: endpoint, store: store, more: true) }
                        }
                        .disabled(store.isLoading)
                    }
                }
            }
            if !recentPaths.isEmpty {
                Section("Recent folders") {
                    ForEach(recentPaths, id: \.self) { path in
                        Button {
                            SessionActions.setEndpoint(endpoint, for: session)
                            SessionActions.setPath(path, for: session)
                            onPick()
                        } label: {
                            Label(path, systemImage: "clock")
                                .lineLimit(2).truncationMode(.middle)
                        }
                    }
                }
            }
            if store.isLoading { ProgressView("Loading projects…") }
            if let error = store.error {
                Section {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                    Button("Retry") { Task { await SessionProjectService.load(endpoint: endpoint, store: store) } }
                        .disabled(store.isLoading)
                }
            } else if !store.isLoading && store.selectableProjects.isEmpty {
                Text("No registered projects on this machine. Choose a recent folder or browse to a project.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.palette.background)
        .navigationTitle("Choose a project")
        .navigationBarTitleDisplayMode(.inline)
        .themedNavChrome()
        .task(id: "\(endpoint.id)|\(endpoint.connectionRevision?.uuidString ?? "")") {
            await SessionProjectService.load(endpoint: endpoint, store: store)
        }
        .refreshable { await SessionProjectService.load(endpoint: endpoint, store: store) }
    }

    private var recentPaths: [String] {
        var seen: Set<String> = []
        return recentSessions.compactMap(\.path).filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
