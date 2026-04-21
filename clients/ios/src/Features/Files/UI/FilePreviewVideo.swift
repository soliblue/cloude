import AVKit
import SwiftUI

struct FilePreviewVideo: View {
    let data: Data
    let fileName: String
    @State private var url: URL?

    var body: some View {
        Group {
            if let url {
                VideoPlayer(player: AVPlayer(url: url))
            } else {
                ProgressView()
            }
        }
        .task {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + fileName)
            try? data.write(to: tmp)
            url = tmp
        }
        .onDisappear {
            if let url {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
