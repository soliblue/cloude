//
//  SplitChatView+Window.swift
//  Cloude

import SwiftUI

extension SplitChatView {
    @ViewBuilder
    func windowView(for window: ChatWindow, totalHeight: CGFloat) -> some View {
        let project = window.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
        let conversation = project.flatMap { proj in
            window.conversationId.flatMap { cid in proj.conversations.first { $0.id == cid } }
        }
        let isActive = window.id == windowManager.activeWindowId
        let isThinking = window.conversationId != nil && connection.runningConversationId == window.conversationId
        let height = heightForWindow(window, totalHeight: totalHeight)

        VStack(spacing: 0) {
            windowHeader(for: window, project: project, conversation: conversation, showCloseButton: true)
            Divider()
            windowContent(for: window, project: project, conversation: conversation)
        }
        .frame(height: height)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            PulsingBorder(isActive: isActive, isThinking: isThinking)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            windowManager.setActive(window.id)
        }
    }

    func heightForWindow(_ window: ChatWindow, totalHeight: CGFloat) -> CGFloat? {
        let count = windowManager.windows.count
        guard count > 1 else { return nil }

        let isActive = window.id == windowManager.activeWindowId
        let spacing = CGFloat(count - 1) * 2
        let availableHeight = totalHeight - spacing

        if isKeyboardVisible {
            let collapsedHeight: CGFloat = 44
            let totalCollapsedHeight = collapsedHeight * CGFloat(count - 1)
            if isActive {
                return availableHeight - totalCollapsedHeight
            } else {
                return collapsedHeight
            }
        }

        guard windowManager.focusModeEnabled else { return nil }

        if isActive {
            return availableHeight * 0.65
        } else {
            return availableHeight * 0.35 / CGFloat(count - 1)
        }
    }

    @ViewBuilder
    func windowContent(for window: ChatWindow, project: Project?, conversation: Conversation?) -> some View {
        let isActive = window.id == windowManager.activeWindowId
        let isCollapsed = isKeyboardVisible && !isActive && windowManager.windows.count > 1

        if isCollapsed {
            EmptyView()
        } else {
            switch window.type {
            case .chat:
                ProjectChatView(
                    connection: connection,
                    store: projectStore,
                    project: project,
                    conversation: conversation,
                    isCompact: true,
                    isKeyboardVisible: isKeyboardVisible,
                    onInteraction: {
                        windowManager.setActive(window.id)
                        dismissKeyboard()
                    }
                )
            case .files:
                FileBrowserView(
                    connection: connection,
                    rootPath: project?.rootDirectory
                )
            case .gitChanges:
                GitChangesView(
                    connection: connection,
                    rootPath: project?.rootDirectory
                )
            }
        }
    }
}
