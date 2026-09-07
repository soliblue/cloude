import Foundation
import QuartzCore

final class DebugFPSCounterTarget: NSObject {
    weak var counter: DebugFPSCounter?

    @objc func tick(_ link: CADisplayLink) { counter?.tick(link) }
}
