import AVKit
import SwiftUI

struct FilePreviewVideo: View {
    let url: URL
    @State private var playback = FilePreviewPlayback()

    var body: some View {
        VideoPlayer(player: playback.player)
            .onAppear { playback.open(url) }
            .onDisappear { playback.stop() }
    }
}
