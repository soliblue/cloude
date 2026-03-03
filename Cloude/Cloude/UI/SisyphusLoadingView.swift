import SwiftUI

struct SisyphusLoadingView: View {
    @State private var startDate = Date()

    private let frameNames = (1...15).map { "sisyphus-\($0)" }
    private let frameDuration: Double = 0.1
    private let frameCount = 15

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let cycleLength = Double(frameCount) * frameDuration
            let halfCycle = elapsed.truncatingRemainder(dividingBy: cycleLength * 2)
            let progress = halfCycle < cycleLength
                ? halfCycle / cycleLength
                : 1.0 - (halfCycle - cycleLength) / cycleLength
            let exactFrame = progress * Double(frameCount - 1)
            let lower = Int(exactFrame)
            let upper = min(lower + 1, frameCount - 1)
            let blend = exactFrame - Double(lower)

            ZStack {
                Image(frameNames[lower])
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                Image(frameNames[upper])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(blend)
            }
            .frame(height: 50)
        }
    }
}
