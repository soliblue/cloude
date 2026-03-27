import SwiftUI

struct SisyphusLoadingView: View {
    private let start = Date()
    private let pushFrames = (1...6).map { "cloude-anim-\($0)" }
    private let retreatFrames = (11...18).map { "cloude-anim-\($0)" }
    private let interval: TimeInterval = 0.22

    private var sequence: [String] {
        pushFrames + retreatFrames
    }

    var body: some View {
        TimelineView(.periodic(from: start, by: interval)) { context in
            let index = Int(context.date.timeIntervalSince(start) / interval) % sequence.count
            Image(sequence[index])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: DS.Size.m)
        }
    }
}
