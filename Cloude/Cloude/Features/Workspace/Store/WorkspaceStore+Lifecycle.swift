import Foundation
import SwiftUI
import Photos
import CloudeShared

extension WorkspaceStore {
    func initializeFirstWindow(conversationStore: ConversationStore, windowManager: WindowManager) {
        if let firstWindow = windowManager.windows.first,
           firstWindow.conversationId == nil,
           let conversation = conversationStore.listableConversations.first {
            windowManager.linkToCurrentConversation(firstWindow.id, conversation: conversation)
        }
    }

    func handleActiveWindowChange(
        oldId: UUID?,
        newId: UUID?,
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore? = nil
    ) {
        if let oldId = oldId {
            drafts[oldId] = Draft(text: inputText, images: attachedImages, effort: currentEffort, model: currentModel)
            cleanupEmptyConversation(for: oldId, conversationStore: conversationStore, windowManager: windowManager)
        }
        if let newId = newId, let draft = drafts[newId] {
            inputText = draft.text
            attachedImages = draft.images
            currentEffort = draft.effort
            currentModel = draft.model
        } else {
            inputText = ""
            attachedImages = []
            currentEffort = currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.defaultEffort
            currentModel = currentConversation(windowManager: windowManager, conversationStore: conversationStore)?.defaultModel
        }
        if let newId, let environmentStore {
            checkGitForActiveWindow(windowId: newId, conversationStore: conversationStore, windowManager: windowManager, environmentStore: environmentStore)
        }
    }

    func checkGitForActiveWindow(
        windowId: UUID,
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore
    ) {
        let window = windowManager.windows.first(where: { $0.id == windowId })
        let conv = window?.conversation(in: conversationStore)
        if let dir = window?.gitRepoRootPath ?? conv?.workingDirectory,
           !dir.isEmpty {
            environmentStore.connection(for: conv?.environmentId ?? environmentStore.activeEnvironmentId)?.gitStatus.enqueue(dir)
        }
    }

    func handleModelChange(_ newModel: ModelSelection?, conversationStore: ConversationStore, windowManager: WindowManager) {
        if let conv = currentConversation(windowManager: windowManager, conversationStore: conversationStore),
           newModel != conv.defaultModel {
            conversationStore.setDefaultModel(conv, model: newModel)
        }
    }

    func handleEffortChange(_ newEffort: EffortLevel?, conversationStore: ConversationStore, windowManager: WindowManager) {
        if let conv = currentConversation(windowManager: windowManager, conversationStore: conversationStore),
           newEffort != conv.defaultEffort {
            conversationStore.setDefaultEffort(conv, effort: newEffort)
        }
    }

    func addWindowWithNewChat(
        conversationStore: ConversationStore,
        windowManager: WindowManager,
        environmentStore: EnvironmentStore
    ) {
        let dir = activeWindowWorkingDirectory(windowManager: windowManager, conversationStore: conversationStore)
        let envId = activeWindowEnvironmentId(windowManager: windowManager, conversationStore: conversationStore, environmentStore: environmentStore)
        let newWindowId = windowManager.addWindow()
        let newConv = conversationStore.newConversation(
            workingDirectory: dir,
            environmentId: envId
        )
        windowManager.linkToCurrentConversation(newWindowId, conversation: newConv)
    }

    func cleanupEmptyConversation(for windowId: UUID, conversationStore: ConversationStore, windowManager: WindowManager) {
        if let window = windowManager.windows.first(where: { $0.id == windowId }),
           let convId = window.conversationId,
           let conversation = conversationStore.conversation(withId: convId),
           conversation.isEmpty {
            conversationStore.deleteConversation(conversation)
            windowManager.removeWindow(windowId)
        }
    }

    func searchFiles(
        _ query: String,
        environmentStore: EnvironmentStore,
        conversationStore: ConversationStore,
        windowManager: WindowManager
    ) {
        let envId = activeWindowEnvironmentId(
            windowManager: windowManager,
            conversationStore: conversationStore,
            environmentStore: environmentStore
        )
        if let workingDir = activeWindowWorkingDirectory(windowManager: windowManager, conversationStore: conversationStore),
           !workingDir.isEmpty {
            environmentStore.connection(for: envId)?.searchFiles(query: query, workingDirectory: workingDir)
        } else {
            environmentStore.connection(for: envId)?.clearFileSearchResults()
        }
    }

    func fetchLatestScreenshot() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            DispatchQueue.main.asyncAfter(deadline: .now() + DS.Delay.l) {
                self.loadLatestPhoto()
            }
        } else {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.asyncAfter(deadline: .now() + DS.Delay.l) {
                        self.loadLatestPhoto()
                    }
                }
            }
        }
    }

    private func loadLatestPhoto(attempt: Int = 0) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        let cutoff = Date().addingTimeInterval(-3)
        options.predicate = NSPredicate(format: "mediaType == %d AND creationDate > %@", PHAssetMediaType.image.rawValue, cutoff as NSDate)

        let result = PHAsset.fetchAssets(with: options)
        if result.firstObject == nil, attempt < 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + DS.Delay.m) {
                self.loadLatestPhoto(attempt: attempt + 1)
            }
            return
        }
        if let asset = result.firstObject {
            let imageOptions = PHImageRequestOptions()
            imageOptions.isSynchronous = false
            imageOptions.deliveryMode = .highQualityFormat
            imageOptions.resizeMode = .exact

            let targetSize = CGSize(width: DS.Size.xxl * 3, height: DS.Size.xxl * 3)
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: imageOptions) { image, _ in
                if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
                    DispatchQueue.main.async {
                        if self.attachedImages.count < 5 {
                            withAnimation(.easeOut(duration: DS.Duration.s)) {
                                self.attachedImages.append(AttachedImage(data: data, isScreenshot: true))
                            }
                        }
                    }
                }
            }
        }
    }
}
