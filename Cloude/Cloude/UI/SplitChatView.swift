//
//  SplitChatView.swift
//  Cloude
//
//  Multi-pane chat view supporting 1-4 simultaneous conversations
//

import SwiftUI

struct SplitChatView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var projectStore: ProjectStore
    @StateObject private var paneManager = PaneManager()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selectingPane: ChatPane?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                paneGrid(geometry: geometry)
                Divider()
                controlBar
            }
        }
        .onAppear { syncActivePaneToStore() }
        .onChange(of: paneManager.activePaneId) { _, _ in syncActivePaneToStore() }
        .onChange(of: projectStore.currentConversation?.id) { _, _ in updateActivePaneLink() }
        .sheet(item: $selectingPane) { pane in
            PaneConversationPicker(
                projectStore: projectStore,
                onSelect: { project, conversation in
                    paneManager.linkToCurrentConversation(pane.id, project: project, conversation: conversation)
                    selectingPane = nil
                }
            )
        }
    }

    @ViewBuilder
    private func paneGrid(geometry: GeometryProxy) -> some View {
        let paneCount = paneManager.panes.count
        let isLandscape = geometry.size.width > geometry.size.height

        switch paneCount {
        case 1:
            singlePane
        case 2:
            twoPanes(isLandscape: isLandscape)
        default:
            fourPaneGrid
        }
    }

    private var singlePane: some View {
        paneView(for: paneManager.panes[0])
            .padding(4)
    }

    private func twoPanes(isLandscape: Bool) -> some View {
        Group {
            if isLandscape {
                HStack(spacing: 4) {
                    ForEach(paneManager.panes) { pane in
                        paneView(for: pane)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(paneManager.panes) { pane in
                        paneView(for: pane)
                    }
                }
            }
        }
        .padding(4)
    }

    private var fourPaneGrid: some View {
        let panes = paneManager.panes
        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                paneView(for: panes[0])
                if panes.count > 1 {
                    paneView(for: panes[1])
                }
            }
            HStack(spacing: 4) {
                if panes.count > 2 {
                    paneView(for: panes[2])
                }
                if panes.count > 3 {
                    paneView(for: panes[3])
                }
            }
        }
        .padding(4)
    }

    private func paneView(for pane: ChatPane) -> some View {
        let project = pane.projectId.flatMap { pid in projectStore.projects.first { $0.id == pid } }
        let conversation = project.flatMap { proj in
            pane.conversationId.flatMap { cid in proj.conversations.first { $0.id == cid } }
        }
        let isActive = pane.id == paneManager.activePaneId

        return ProjectChatView(
            connection: connection,
            store: projectStore,
            project: project,
            conversation: conversation,
            isCompact: true,
            showHeader: true,
            onSelectConversation: { selectingPane = pane }
        )
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor : Color(.separator), lineWidth: isActive ? 2 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { paneManager.setActive(pane.id) }
    }

    private var controlBar: some View {
        HStack {
            Button(action: { paneManager.addPane() }) {
                Label("Add Pane", systemImage: "plus.rectangle.on.rectangle")
                    .font(.caption)
            }
            .disabled(!paneManager.canAddPane)

            Spacer()

            Text("\(paneManager.panes.count) pane\(paneManager.panes.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: removeActivePane) {
                Label("Remove Pane", systemImage: "minus.rectangle")
                    .font(.caption)
            }
            .disabled(!paneManager.canRemovePane)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func removeActivePane() {
        if let activeId = paneManager.activePaneId {
            paneManager.removePane(activeId)
        }
    }

    private func syncActivePaneToStore() {
        guard let activePane = paneManager.activePane else { return }
        if let projectId = activePane.projectId,
           let project = projectStore.projects.first(where: { $0.id == projectId }) {
            if let convId = activePane.conversationId,
               let conv = project.conversations.first(where: { $0.id == convId }) {
                projectStore.selectConversation(conv, in: project)
            } else {
                projectStore.selectProject(project)
            }
        }
    }

    private func updateActivePaneLink() {
        guard let activeId = paneManager.activePaneId else { return }
        paneManager.linkToCurrentConversation(
            activeId,
            project: projectStore.currentProject,
            conversation: projectStore.currentConversation
        )
    }
}
