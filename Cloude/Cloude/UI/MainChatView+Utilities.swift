import SwiftUI
import UIKit
import Photos
import Combine
import CloudeShared

extension MainChatView {
    func initializeFirstWindow() {
        guard let firstWindow = windowManager.windows.first,
              firstWindow.conversationId == nil,
              let conversation = conversationStore.currentConversation else { return }
        windowManager.linkToCurrentConversation(firstWindow.id, conversation: conversation)
    }

    func addWindowWithNewChat() {
        let activeWorkingDir = activeWindowWorkingDirectory()
        let newWindowId = windowManager.addWindow()
        let newConv = conversationStore.newConversation(workingDirectory: activeWorkingDir)
        windowManager.linkToCurrentConversation(newWindowId, conversation: newConv)
    }

    func activeWindowWorkingDirectory() -> String? {
        guard let activeWindow = windowManager.activeWindow,
              let convId = activeWindow.conversationId,
              let conv = conversationStore.conversation(withId: convId) else {
            return conversationStore.currentConversation?.workingDirectory
        }
        return conv.workingDirectory
    }

    func syncActiveWindowToStore() {
        guard let activeWindow = windowManager.activeWindow,
              let convId = activeWindow.conversationId,
              let conv = conversationStore.conversation(withId: convId) else { return }
        conversationStore.selectConversation(conv)
    }

    func updateActiveWindowLink() {
        guard let activeId = windowManager.activeWindowId else { return }
        windowManager.linkToCurrentConversation(
            activeId,
            conversation: conversationStore.currentConversation
        )
    }

    func setupGitStatusHandler() {
        connection.onGitStatus = { status in
            if let dir = pendingGitChecks.first {
                pendingGitChecks.removeFirst()
                if !status.branch.isEmpty {
                    gitBranches[dir] = status.branch
                }
                checkNextGitDirectory()
            }
        }
    }

    func checkGitForAllDirectories() {
        pendingGitChecks = conversationStore.uniqueWorkingDirectories
            .filter { gitBranches[$0] == nil }
        checkNextGitDirectory()
    }

    func checkNextGitDirectory() {
        guard let dir = pendingGitChecks.first, !dir.isEmpty else { return }
        connection.gitStatus(path: dir)
    }

    func cleanupEmptyConversation(for windowId: UUID) {
        guard let window = windowManager.windows.first(where: { $0.id == windowId }),
              let convId = window.conversationId,
              let conversation = conversationStore.conversation(withId: convId),
              conversation.isEmpty else { return }
        conversationStore.deleteConversation(conversation)
        windowManager.unlinkConversation(windowId)
    }

    func searchFiles(_ query: String) {
        guard let workingDir = activeWindowWorkingDirectory(), !workingDir.isEmpty else {
            fileSearchResults = []
            return
        }
        connection.searchFiles(query: query, workingDirectory: workingDir)
    }

    func setupFileSearchHandler() {
        connection.onFileSearchResults = { files, _ in
            fileSearchResults = files
        }
    }

    func setupCostHandler() {
        connection.onLastAssistantMessageCostUpdate = { [conversationStore] convId, costUsd in
            guard let conversation = conversationStore.conversation(withId: convId),
                  let lastAssistantMsg = conversation.messages.last(where: { !$0.isUser }) else { return }
            conversationStore.updateMessage(lastAssistantMsg.id, in: conversation) { msg in
                msg.costUsd = costUsd
            }
        }
    }

    func fetchLatestScreenshot() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    self.loadLatestPhoto()
                }
            }
            return
        }
        loadLatestPhoto()
    }

    private func loadLatestPhoto() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        guard let asset = result.firstObject else { return }

        let imageOptions = PHImageRequestOptions()
        imageOptions.isSynchronous = false
        imageOptions.deliveryMode = .highQualityFormat
        imageOptions.resizeMode = .exact

        let targetSize = CGSize(width: 600, height: 600)
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: imageOptions) { image, _ in
            guard let image = image, let data = image.jpegData(compressionQuality: 0.8) else { return }
            DispatchQueue.main.async {
                guard self.attachedImages.count < 5 else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    self.attachedImages.append(AttachedImage(data: data, isScreenshot: true))
                }
            }
        }
    }
}
