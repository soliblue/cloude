import Combine
import QuartzCore
import SwiftUI

final class DebugFPSCounter: ObservableObject {
    @Published var fps: Int = 0
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frames: Int = 0

    init() {
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    deinit {
        displayLink?.invalidate()
    }

    func setPaused(_ paused: Bool) {
        displayLink?.isPaused = paused
        if paused {
            lastTimestamp = 0
            frames = 0
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp != 0 {
            frames += 1
            let delta = link.timestamp - lastTimestamp
            if delta >= 1 {
                fps = Int(Double(frames) / delta)
                frames = 0
                lastTimestamp = link.timestamp
            }
        } else {
            lastTimestamp = link.timestamp
        }
    }
}
