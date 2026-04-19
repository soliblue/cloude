import Foundation
import QuartzCore

final class FPSTarget {
    weak var metrics: DebugMetrics?

    init(metrics: DebugMetrics) {
        self.metrics = metrics
    }

    @objc func tick() {
        MainActor.assumeIsolated {
            metrics?.recordFrame()
        }
    }
}
