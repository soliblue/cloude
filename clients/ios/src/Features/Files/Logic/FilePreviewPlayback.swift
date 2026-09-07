import AVFoundation
import Foundation
import Observation

@Observable
final class FilePreviewPlayback {
    let player = AVPlayer()

    func open(_ url: URL) {
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}
