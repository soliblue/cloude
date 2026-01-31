//
//  WindowEditSheet.swift
//  Cloude

import SwiftUI

struct WindowEditSheet: View {
    let window: ChatWindow
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var windowManager: WindowManager
    let onSelectConversation: () -> Void
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var symbol: String = ""
    @State private var showSymbolPicker = false

    private var project: Project? {
        window.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
    }

    private var conversation: Conversation? {
        project.flatMap { proj in
            window.conversationId.flatMap { cid in proj.conversations.first { $0.id == cid } }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Button(action: { showSymbolPicker = true }) {
                        Image(systemName: symbol.isEmpty ? "circle.dashed" : symbol)
                            .font(.system(size: 24))
                            .frame(width: 56, height: 56)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    TextField("Name", text: $name)
                        .font(.title3)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 12) {
                    Button(action: onSelectConversation) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("Change")
                        }
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    if windowManager.windows.count > 1 {
                        Button(action: {
                            windowManager.removeWindow(window.id)
                            onDismiss()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("Edit Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if let proj = project, let conv = conversation {
                            if !name.isEmpty {
                                projectStore.renameConversation(conv, in: proj, to: name)
                            }
                            projectStore.setConversationSymbol(conv, in: proj, symbol: symbol.isEmpty ? nil : symbol)
                        }
                        onDismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .sheet(isPresented: $showSymbolPicker) {
                SymbolPickerSheet(selectedSymbol: $symbol)
            }
        }
        .presentationDetents([.height(280)])
        .onAppear {
            name = conversation?.name ?? ""
            symbol = conversation?.symbol ?? ""
        }
    }
}
