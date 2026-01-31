//
//  SplitChatView+Layout.swift
//  Cloude

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
}
