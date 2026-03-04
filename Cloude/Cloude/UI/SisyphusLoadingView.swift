import SwiftUI

struct SisyphusLoadingView: View {
    @State private var frameIndex = 0

    private let pushFrames = (1...9).map { "cloude-anim-\($0)" }
    private let retreatFrames = (10...18).map { "cloude-anim-\($0)" }
    private let interval: TimeInterval = 0.14

    private var sequence: [String] {
        let pushCycle = pushFrames + pushFrames.reversed().dropFirst().dropLast()
        let retreatCycle = retreatFrames + retreatFrames.reversed().dropFirst().dropLast()
        return pushCycle + pushCycle + retreatCycle
    }

    var body: some View {
        Image(sequence[frameIndex])
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
