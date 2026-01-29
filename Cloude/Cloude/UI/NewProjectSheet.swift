//
//  NewProjectSheet.swift
//  Cloude
//
//  Sheet for creating a new project
//

import SwiftUI

struct NewProjectSheet: View {
    @ObservedObject var store: ProjectStore
    @ObservedObject var connection: ConnectionManager
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var rootDirectory = ""
    @State private var showFolderPicker = false

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
                            if rootDirectory.isEmpty {
                                Text("Select Root Folder")
                                    .foregroundColor(.secondary)
                            } else {
                                Text(folderDisplayName)
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("The working directory for Claude Code in this project.")
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let projectName = name.isEmpty ? folderDisplayName : name
                        _ = store.createProject(name: projectName, rootDirectory: rootDirectory)
                        isPresented = false
                    }
                    .disabled(rootDirectory.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(connection: connection) { selectedPath in
                rootDirectory = selectedPath
                if name.isEmpty {
                    name = (selectedPath as NSString).lastPathComponent
                }
            }
        }
    }

    private var folderDisplayName: String {
        (rootDirectory as NSString).lastPathComponent
    }
}
