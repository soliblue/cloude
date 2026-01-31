//
//  SplitChatView+WindowSync.swift
//  Cloude
//

import SwiftUI

extension SplitChatView {
    func initializeFirstWindow() {
        guard let firstWindow = windowManager.windows.first,
              firstWindow.conversationId == nil,
              let project = projectStore.currentProject,
              let conversation = projectStore.currentConversation else { return }
        windowManager.linkToCurrentConversation(firstWindow.id, project: project, conversation: conversation)
    }

    func addWindowWithNewChat() {
        var project = projectStore.currentProject
        if project == nil {
            project = projectStore.createProject(name: "Default Project")
        }
        guard let proj = project else { return }

        let newWindowId = windowManager.addWindow()
        let newConv = projectStore.newConversation(in: proj)
        windowManager.linkToCurrentConversation(newWindowId, project: proj, conversation: newConv)
    }

    func syncActiveWindowToStore() {
        guard let activeWindow = windowManager.activeWindow else { return }
        if let projectId = activeWindow.projectId,
           let project = projectStore.projects.first(where: { $0.id == projectId }) {
            if let convId = activeWindow.conversationId,
               let conv = project.conversations.first(where: { $0.id == convId }) {
                projectStore.selectConversation(conv, in: project)
            } else {
                projectStore.selectProject(project)
            }
        }
    }

    func updateActiveWindowLink() {
        guard let activeId = windowManager.activeWindowId else { return }
        windowManager.linkToCurrentConversation(
            activeId,
            project: projectStore.currentProject,
            conversation: projectStore.currentConversation
        )
    }
}
