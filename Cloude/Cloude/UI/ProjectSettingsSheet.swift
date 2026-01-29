//
//  ProjectSettingsSheet.swift
//  Cloude
//
//  Settings sheet for editing project details
//

import SwiftUI

struct ProjectSettingsSheet: View {
    @ObservedObject var store: ProjectStore
    @ObservedObject var connection: ConnectionManager
    let project: Project
    @Binding var isPresented: Bool

    @State private var name: String
    @State private var rootDirectory: String
    @State private var showFolderPicker = false

    init(store: ProjectStore, connection: ConnectionManager, project: Project, isPresented: Binding<Bool>) {
        self.store = store
        self.connection = connection
        self.project = project
        self._isPresented = isPresented
        self._name = State(initialValue: project.name)
        self._rootDirectory = State(initialValue: project.rootDirectory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $name)
                }

                Section {
                    Button(action: { showFolderPicker = true }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(folderDisplayName)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("The working directory for Claude Code in this project.")
                }

                Section {
                    HStack {
                        Text("Conversations")
                        Spacer()
                        Text("\(project.conversations.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(project.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Project Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        if name != project.name {
                            store.renameProject(project, to: name)
                        }
                        if rootDirectory != project.rootDirectory {
                            store.updateRootDirectory(project, to: rootDirectory)
                        }
                        isPresented = false
                    }) {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(connection: connection) { selectedPath in
                rootDirectory = selectedPath
            }
        }
        .presentationDetents([.medium])
    }

    private var folderDisplayName: String {
        (rootDirectory as NSString).lastPathComponent
    }
}
