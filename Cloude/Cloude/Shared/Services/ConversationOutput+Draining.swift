import Foundation
import QuartzCore

extension ConversationOutput {
    func startDraining() {
        guard displayLink == nil else { return }
        if displayIndex == nil {
            displayIndex = fullText.startIndex
        }
        lastDrainTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(drainTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc func drainTick() {
        guard let idx = displayIndex, idx < fullText.endIndex else {
            stopDraining()
            return
        }

        let now = CACurrentMediaTime()
        let elapsed = now - lastDrainTime
        lastDrainTime = now

        let buffered = fullText.distance(from: idx, to: fullText.endIndex)
        let rate: Double
        if buffered > 800 {
            rate = charsPerSecond * 4
        } else if buffered > 400 {
            rate = charsPerSecond * 2
        } else {
            rate = charsPerSecond
        }

        var charsToShow = max(1, Int(rate * elapsed))

        var newIdx = idx
        while charsToShow > 0 && newIdx < fullText.endIndex {
            newIdx = fullText.index(after: newIdx)
            charsToShow -= 1
        }

        displayIndex = newIdx
        text = String(fullText[fullText.startIndex..<newIdx])
    }

    func stopDraining() {
        displayLink?.invalidate()
        displayLink = nil
    }
}
