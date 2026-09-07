import AVKit
import SwiftUI

struct FilePreviewAudio: View {
    let url: URL
    @State private var playback = FilePreviewPlayback()

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.l) {
            Image(systemName: "waveform")
                .appFont(size: ThemeTokens.Icon.l)
                .foregroundColor(ThemeColor.secondary)
            VideoPlayer(player: playback.player)
                .frame(height: 160)
        }
        .padding(ThemeTokens.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { playback.open(url) }
        .onDisappear { playback.stop() }
    }
}
