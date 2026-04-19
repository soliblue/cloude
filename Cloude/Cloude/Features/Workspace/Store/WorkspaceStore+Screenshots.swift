import Foundation
import Photos
import SwiftUI

extension WorkspaceStore {
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
