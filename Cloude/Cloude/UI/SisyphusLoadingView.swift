import SwiftUI

struct SisyphusLoadingView: View {
    @State private var frameIndex = 0

    private let frameNames = (1...15).map { "sisyphus-\($0)" }
    private let interval: TimeInterval = 0.1

    private var sequence: [Int] {
        Array(0..<15) + Array((0..<15).reversed())
    }

    var body: some View {
        Image(frameNames[sequence[frameIndex]])
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 30)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    frameIndex = (frameIndex + 1) % sequence.count
                }
            }
    }
}
