import SwiftUI

struct SisyphusLoadingView: View {
    private let start = Date()
    private let pushFrames = (1...9).map { "cloude-anim-\($0)" }
    private let retreatFrames = (10...18).map { "cloude-anim-\($0)" }
    private let interval: TimeInterval = 0.09

    private var sequence: [String] {
        let pushCycle = pushFrames + pushFrames.reversed().dropFirst().dropLast()
        let retreatCycle = retreatFrames + retreatFrames.reversed().dropFirst().dropLast()
        return pushCycle + pushCycle + retreatCycle
    }

    var body: some View {
        TimelineView(.periodic(from: start, by: interval)) { context in
            let index = Int(context.date.timeIntervalSince(start) / interval) % sequence.count
            Image(sequence[index])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 30)
        }
    }
}
