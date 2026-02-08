import SwiftUI
import CloudeShared

struct NewFolderSheet: View {
    @ObservedObject var store: ConversationStore
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
            .background(Color.oceanBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.oceanSecondary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        _ = store.newConversation(workingDirectory: rootDirectory)
                        isPresented = false
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .disabled(rootDirectory.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(connection: connection) { selectedPath in
                rootDirectory = selectedPath
                if name.isEmpty {
                    name = selectedPath.lastPathComponent
                }
            }
        }
        .presentationBackground(Color.oceanBackground)
    }

    private var folderDisplayName: String {
        rootDirectory.lastPathComponent
    }
}
