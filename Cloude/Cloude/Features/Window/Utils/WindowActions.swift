import SwiftUI
import CloudeShared

extension App {
    func selectWindow(index: Int) {
        guard index >= 0 && index < windowManager.windows.count else {
            AppLogger.bootstrapInfo("select window ignored index=\(index) count=\(windowManager.windows.count)")
            return
        }
        windowManager.navigateToWindow(at: index)
        AppLogger.bootstrapInfo("selected window index=\(index)")
    }

    func closeActiveWindow() {
        guard let activeWindow = windowManager.activeWindow else {
            AppLogger.bootstrapInfo("close window ignored no active window")
            return
        }
        guard windowManager.canRemoveWindow else {
            AppLogger.bootstrapInfo("close window ignored only one window")
            return
        }
        windowManager.removeWindow(activeWindow.id)
        AppLogger.bootstrapInfo("closed window id=\(activeWindow.id.uuidString)")
    }

    func closeOrResetActiveWindow() {
        if let activeWindow = windowManager.activeWindow {
            if windowManager.windows.count > 1 {
                closeActiveWindow()
            } else {
                let conversation = conversationStore.newConversation(
                    workingDirectory: activeWindow.conversation(in: conversationStore)?.workingDirectory,
                    environmentId: activeWindow.conversation(in: conversationStore)?.environmentId
                )
                windowManager.linkToCurrentConversation(activeWindow.id, conversation: conversation)
                AppLogger.bootstrapInfo("reset active window id=\(activeWindow.id.uuidString)")
            }
        }
    }

    func createWindow(tab: WindowTab? = nil) {
        let newWindowId = windowManager.addWindow()
        if let tab {
            windowManager.setWindowTab(newWindowId, tab: tab)
        }
        AppLogger.bootstrapInfo("created window id=\(newWindowId.uuidString) tab=\((tab ?? .chat).rawValue)")
    }

    func setActiveWindowTab(_ tab: WindowTab) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }
        windowManager.setWindowTab(activeWindow.id, tab: tab)
        AppLogger.bootstrapInfo("set active window tab windowId=\(activeWindow.id.uuidString) tab=\(tab.rawValue)")
    }
}
