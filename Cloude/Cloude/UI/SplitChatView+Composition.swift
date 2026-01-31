//
//  SplitChatView+Composition.swift
//  Cloude
//

import SwiftUI

extension SplitChatView {
    @ViewBuilder
    func windowGrid(geometry: GeometryProxy) -> some View {
        VStack(spacing: 2) {
            ForEach(windowManager.windows) { window in
                windowView(for: window, totalHeight: geometry.size.height - 4)
            }
        }
        .padding(4)
    }

    @ViewBuilder
    func pagedView(geometry: GeometryProxy) -> some View {
        TabView(selection: $currentPageIndex) {
            ForEach(Array(windowManager.windows.enumerated()), id: \.element.id) { index, window in
                pagedWindowContent(for: window)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: currentPageIndex) { _, newIndex in
            windowManager.navigateToWindow(at: newIndex)
        }
        .onAppear {
            if let activeId = windowManager.activeWindowId,
               let index = windowManager.windowIndex(for: activeId) {
                currentPageIndex = index
            }
        }
        .onChange(of: windowManager.activeWindowId) { _, newId in
            if let id = newId, let index = windowManager.windowIndex(for: id) {
                if currentPageIndex != index {
                    withAnimation { currentPageIndex = index }
                }
            }
        }
    }

    func pageIndicator() -> some View {
        HStack(spacing: 10) {
            ForEach(Array(windowManager.windows.enumerated()), id: \.element.id) { index, window in
                let isActive = window.id == windowManager.activeWindowId
                let conversation = window.projectId.flatMap { pid in
                    projectStore.projects.first { $0.id == pid }
                }.flatMap { proj in
                    window.conversationId.flatMap { cid in proj.conversations.first { $0.id == cid } }
                }

                Group {
                    if let symbol = conversation?.symbol, !symbol.isEmpty {
                        Image(systemName: symbol)
                            .font(.system(size: 18))
                            .frame(width: 40, height: 40)
                            .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: isActive ? 16 : 12, height: isActive ? 16 : 12)
                    }
                }
                .contentShape(Circle())
                .onTapGesture {
                    withAnimation { currentPageIndex = index }
                }
                .onLongPressGesture {
                    editingWindow = window
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func pagedWindowContent(for window: ChatWindow) -> some View {
        let project = window.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
        let conversation = project.flatMap { proj in
            window.conversationId.flatMap { cid in proj.conversations.first { $0.id == cid } }
        }

        VStack(spacing: 0) {
            windowHeader(for: window, project: project, conversation: conversation, showCloseButton: false)

            switch window.type {
            case .chat:
                ProjectChatView(
                    connection: connection,
                    store: projectStore,
                    project: project,
                    conversation: conversation,
                    isCompact: false,
                    onInteraction: { dismissKeyboard() }
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

    func windowHeader(for window: ChatWindow, project: Project?, conversation: Conversation?, showCloseButton: Bool = true) -> some View {
        let gitBranch = project.flatMap { gitBranches[$0.id] }
        let availableTypes = WindowType.allCases.filter { type in
            if type == .gitChanges { return gitBranch != nil }
            return true
        }

        return HStack(spacing: 8) {
            ForEach(availableTypes, id: \.self) { type in
                Button(action: {
                    windowManager.setActive(window.id)
                    windowManager.setWindowType(window.id, type: type)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: 14))
                        if type == .gitChanges, let branch = gitBranch {
                            Text(branch)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(window.type == type ? .accentColor : .secondary)
                    .padding(6)
                    .background(window.type == type ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: {
                windowManager.setActive(window.id)
                editingWindow = window
            }) {
                HStack(spacing: 4) {
                    if let symbol = conversation?.symbol, !symbol.isEmpty {
                        Image(systemName: symbol)
                            .font(.system(size: 12))
                    }
                    if let conv = conversation {
                        Text(conv.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    } else {
                        Text("Select chat...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let proj = project {
                        Text("• \(proj.name)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showCloseButton {
                Button(action: {
                    windowManager.setActive(window.id)
                    if windowManager.windows.count == 1 {
                        addWindowWithNewChat()
                    } else {
                        windowManager.removeWindow(window.id)
                    }
                }) {
                    Image(systemName: windowManager.windows.count == 1 ? "plus" : "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .disabled(windowManager.windows.count == 1 && !windowManager.canAddWindow)
            } else {
                Button(action: addWindowWithNewChat) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    func windowContent(for window: ChatWindow, project: Project?, conversation: Conversation?) -> some View {
        let isActive = window.id == windowManager.activeWindowId
        let isCollapsed = isKeyboardVisible && !isActive && windowManager.windows.count > 1

        if isCollapsed {
            collapsedWindowContent(conversation: conversation)
        } else {
            switch window.type {
            case .chat:
                chatWindowContent(for: window, project: project, conversation: conversation)
            case .files:
                filesWindowContent(project: project)
            case .gitChanges:
                gitChangesWindowContent(project: project)
            }
        }
    }

    func collapsedWindowContent(conversation: Conversation?) -> some View {
        EmptyView()
    }

    func chatWindowContent(for window: ChatWindow, project: Project?, conversation: Conversation?) -> some View {
        ProjectChatView(
            connection: connection,
            store: projectStore,
            project: project,
            conversation: conversation,
            isCompact: true,
            onInteraction: {
                windowManager.setActive(window.id)
                dismissKeyboard()
            }
        )
    }

    func filesWindowContent(project: Project?) -> some View {
        FileBrowserView(
            connection: connection,
            rootPath: project?.rootDirectory
        )
    }

    func gitChangesWindowContent(project: Project?) -> some View {
        GitChangesView(
            connection: connection,
            rootPath: project?.rootDirectory
        )
    }
}
