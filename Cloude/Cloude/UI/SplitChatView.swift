//
//  SplitChatView.swift
//  Cloude
//
//  Multi-window chat view supporting 1-4 simultaneous conversations
//

import SwiftUI
import UIKit
import Combine

struct SplitChatView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var windowManager: WindowManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var selectingWindow: ChatWindow?
    @State var editingWindow: ChatWindow?
    @State var currentPageIndex: Int = 0
    @State var isKeyboardVisible = false
    @State var inputText = ""
    @State var selectedImageData: Data?
    @State private var hasClipboardContent = false
    @State var drafts: [UUID: (text: String, imageData: Data?)] = [:]
    @State var gitBranches: [UUID: String] = [:]
    @State var pendingGitChecks: [UUID] = []

    var body: some View {
        GeometryReader { geometry in
            switch windowManager.layoutMode {
            case .split:
                windowGrid(geometry: geometry)
            case .paged:
                pagedView(geometry: geometry)
            }
        }
        .onTapGesture {
            dismissKeyboard()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                GlobalInputBar(
                    inputText: $inputText,
                    selectedImageData: $selectedImageData,
                    hasClipboardContent: hasClipboardContent,
                    isConnected: connection.isAuthenticated,
                    isWhisperReady: connection.isWhisperReady,
                    onSend: sendMessage,
                    onTranscribe: transcribeAudio
                )

                if windowManager.layoutMode == .paged && windowManager.windows.count > 1 {
                    pageIndicator()
                        .frame(height: 24)
                        .padding(.bottom, isKeyboardVisible ? 12 : 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { }
            .background(windowManager.layoutMode == .paged ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
        }
        .onAppear {
            initializeFirstWindow()
            checkClipboard()
            setupGitStatusHandler()
            checkGitForAllProjects()
            connection.onTranscription = { text in
                print("[iOS] Received transcription: \(text)")
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isBlank = trimmed.isEmpty ||
                    trimmed.contains("blank audio") ||
                    trimmed.contains("no speech") ||
                    trimmed.contains("inaudible") ||
                    trimmed == "you" ||
                    trimmed == "thanks for watching"
                if !isBlank {
                    if inputText.isEmpty {
                        inputText = text
                    } else {
                        inputText += " " + text
                    }
                }
            }
        }
        .onChange(of: windowManager.activeWindowId) { oldId, newId in
            if let oldId = oldId {
                if !inputText.isEmpty || selectedImageData != nil {
                    drafts[oldId] = (inputText, selectedImageData)
                } else {
                    drafts.removeValue(forKey: oldId)
                }
            }
            if let newId = newId, let draft = drafts[newId] {
                inputText = draft.text
                selectedImageData = draft.imageData
            } else {
                inputText = ""
                selectedImageData = nil
            }
            if windowManager.windows.count == 1 { syncActiveWindowToStore() }
        }
        .onChange(of: projectStore.currentConversation?.id) { _, _ in
            if windowManager.windows.count == 1 { updateActiveWindowLink() }
        }
        .sheet(item: $selectingWindow) { window in
            WindowConversationPicker(
                projectStore: projectStore,
                connection: connection,
                onSelect: { project, conversation in
                    windowManager.linkToCurrentConversation(window.id, project: project, conversation: conversation)
                    selectingWindow = nil
                    if gitBranches[project.id] == nil, !project.rootDirectory.isEmpty {
                        pendingGitChecks = [project.id]
                        checkNextGitProject()
                    }
                }
            )
        }
        .sheet(item: $editingWindow) { window in
            WindowEditSheet(
                window: window,
                projectStore: projectStore,
                windowManager: windowManager,
                onSelectConversation: {
                    editingWindow = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectingWindow = window
                    }
                },
                onDismiss: { editingWindow = nil }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            checkClipboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkClipboard()
        }
        .onChange(of: connection.isAuthenticated) { _, isAuth in
            if isAuth { checkGitForAllProjects() }
        }
        .onChange(of: connection.lastError) { _, error in
            if error != nil && !pendingGitChecks.isEmpty {
                pendingGitChecks.removeFirst()
                checkNextGitProject()
            }
        }
    }

    private func checkClipboard() {
        hasClipboardContent = true
    }
}
