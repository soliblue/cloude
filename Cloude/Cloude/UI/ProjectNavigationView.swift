//
//  ProjectNavigationView.swift
//  Cloude
//
//  Navigation container for projects and conversations
//

import SwiftUI

struct ProjectNavigationView: View {
    @ObservedObject var store: ProjectStore
    @ObservedObject var connection: ConnectionManager
    @Binding var isPresented: Bool

    @State private var selectedProject: Project?
    @State private var showNewProjectSheet = false
    @State private var editingProject: Project?
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.projects) { project in
                    NavigationLink(value: project) {
                        ProjectRowView(
                            project: project,
                            isSelected: store.currentProject?.id == project.id
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.deleteProject(project)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingProject = project
                            newName = project.name
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Project.self) { project in
                ProjectConversationsView(store: store, connection: connection, project: project, isPresented: $isPresented)
            }
            .overlay {
                if store.projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder",
                        description: Text("Create a project to organize conversations")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { showNewProjectSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewProjectSheet) {
                NewProjectSheet(store: store, connection: connection, isPresented: $showNewProjectSheet)
            }
            .alert("Rename Project", isPresented: .init(
                get: { editingProject != nil },
                set: { if !$0 { editingProject = nil } }
            )) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {
                    editingProject = nil
                }
                Button("Save") {
                    if let project = editingProject {
                        store.renameProject(project, to: newName)
                    }
                    editingProject = nil
                }
            }
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundColor(isSelected ? .blue : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)

                HStack(spacing: 8) {
                    Text("\(project.conversations.count) conversations")
                    if !project.rootDirectory.isEmpty {
                        Text(shortenedPath(project.rootDirectory))
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func shortenedPath(_ path: String) -> String {
        path.components(separatedBy: "/").last ?? path
    }
}
