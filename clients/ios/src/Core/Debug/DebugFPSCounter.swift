import Foundation
import Observation
import QuartzCore

@Observable
final class DebugFPSCounter: NSObject {
    var fps: Int = 0
    @ObservationIgnored
    private var displayLink: CADisplayLink?
    @ObservationIgnored
    private var lastTimestamp: CFTimeInterval = 0
    @ObservationIgnored
    private var frames: Int = 0

    override init() {
        super.init()
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
