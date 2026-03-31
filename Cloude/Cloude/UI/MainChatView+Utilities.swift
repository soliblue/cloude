import SwiftUI
import Photos
import CloudeShared

extension MainChatView {
    func initializeFirstWindow() {
        guard let firstWindow = windowManager.windows.first,
              firstWindow.conversationId == nil,
              let conversation = conversationStore.listableConversations.first else { return }
        windowManager.linkToCurrentConversation(firstWindow.id, conversation: conversation)
    }

    func addWindowWithNewChat() {
        let activeWorkingDir = activeWindowWorkingDirectory()
        let activeEnvId = activeWindowEnvironmentId()
        let newWindowId = windowManager.addWindow()
        let newConv = conversationStore.newConversation(workingDirectory: activeWorkingDir, environmentId: activeEnvId)
        windowManager.linkToCurrentConversation(newWindowId, conversation: newConv)
    }

    func activeWindowWorkingDirectory() -> String? {
        guard let activeWindow = windowManager.activeWindow,
              let convId = activeWindow.conversationId,
              let conv = conversationStore.conversation(withId: convId) else {
            return nil
        }
        return conv.workingDirectory
    }

    func activeWindowEnvironmentId() -> UUID? {
        guard let activeWindow = windowManager.activeWindow,
              let convId = activeWindow.conversationId,
              let conv = conversationStore.conversation(withId: convId) else {
            return environmentStore.activeEnvironmentId
        }
        return conv.environmentId ?? environmentStore.activeEnvironmentId
    }

    func checkGitForAllDirectories() {
        var seen = Set<String>()
        pendingGitChecks = conversationStore.listableConversations.compactMap { conv -> (path: String, environmentId: UUID?)? in
            guard let dir = conv.workingDirectory, !dir.isEmpty, gitBranches[dir] == nil else { return nil }
            let key = "\(dir)|\(conv.environmentId?.uuidString ?? "")"
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return (dir, conv.environmentId)
        }
        checkNextGitDirectory()
    }

    func checkNextGitDirectory() {
        guard let check = pendingGitChecks.first else { return }
        connection.gitStatus(path: check.path, environmentId: check.environmentId)
    }

    func cleanupEmptyConversation(for windowId: UUID) {
        guard let window = windowManager.windows.first(where: { $0.id == windowId }),
              let convId = window.conversationId,
              let conversation = conversationStore.conversation(withId: convId),
              conversation.isEmpty else { return }
        conversationStore.deleteConversation(conversation)
        windowManager.removeWindow(windowId)
    }

    func searchFiles(_ query: String) {
        guard let workingDir = activeWindowWorkingDirectory(), !workingDir.isEmpty else {
            fileSearchResults = []
            return
        }
        connection.searchFiles(query: query, workingDirectory: workingDir)
    }

    func fetchLatestScreenshot() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.asyncAfter(deadline: .now() + DS.Delay.l) {
                        self.loadLatestPhoto()
                    }
                }
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + DS.Delay.l) {
            self.loadLatestPhoto()
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
        guard let asset = result.firstObject else { return }

        let imageOptions = PHImageRequestOptions()
        imageOptions.isSynchronous = false
        imageOptions.deliveryMode = .highQualityFormat
        imageOptions.resizeMode = .exact

        let targetSize = CGSize(width: DS.Size.xxl * 3, height: DS.Size.xxl * 3)
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: imageOptions) { image, _ in
            guard let image = image, let data = image.jpegData(compressionQuality: 0.8) else { return }
            DispatchQueue.main.async {
                guard self.attachedImages.count < 5 else { return }
                withAnimation(.easeOut(duration: DS.Duration.s)) {
                    self.attachedImages.append(AttachedImage(data: data, isScreenshot: true))
                }
            }
        }
    }
}
