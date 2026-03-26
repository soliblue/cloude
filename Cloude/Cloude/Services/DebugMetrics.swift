import Foundation
import QuartzCore
import Combine

struct DebugEntry: Identifiable {
    let id = UUID()
    let time: Date
    let source: String
    let message: String
}

@MainActor
final class DebugMetrics: ObservableObject {
    static let shared = DebugMetrics()

    @Published var fps: Int = 0
    @Published var objectWillChangeRate: Int = 0
    private(set) var logBuffers: [String: [DebugEntry]] = [:]
    private let maxLogsPerSource = 200

    var sources: [String] { Array(logBuffers.keys).sorted() }

    static func log(_ source: String, _ message: String) {
        let entry = DebugEntry(time: Date(), source: source, message: message)
        var buf = shared.logBuffers[source, default: []]
        buf.append(entry)
        if buf.count > shared.maxLogsPerSource {
            buf.removeFirst(buf.count - shared.maxLogsPerSource)
        }
        shared.logBuffers[source] = buf
    }

    func allLogs() -> [DebugEntry] {
        logBuffers.values.flatMap { $0 }.sorted { $0.time < $1.time }
    }

    func logs(for source: String?) -> [DebugEntry] {
        if let source {
            return logBuffers[source, default: []]
        }
        return allLogs()
    }

    func clearLogs() {
        logBuffers.removeAll()
    }

    private var fpsLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fpsAccumulator: CFTimeInterval = 0

    private var owcCount: Int = 0
    private var sampleTimer: Timer?
    private var owcCancellable: AnyCancellable?

    private var isRunning = false

    func start(observing publisher: ObservableObjectPublisher? = nil) {
        if isRunning { return }
        isRunning = true
        fps = 0
        objectWillChangeRate = 0

        let link = CADisplayLink(target: FPSTarget(metrics: self), selector: #selector(FPSTarget.tick))
        link.add(to: .main, forMode: .common)
        fpsLink = link
        lastFrameTime = CACurrentMediaTime()
        frameCount = 0
        fpsAccumulator = 0

        sampleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.objectWillChangeRate = self?.owcCount ?? 0
                self?.owcCount = 0
            }
        }

        if let publisher {
            owcCancellable = publisher.sink { [weak self] _ in
                self?.owcCount += 1
            }
        }
    }

    func stop() {
        isRunning = false
        fpsLink?.invalidate()
        fpsLink = nil
        sampleTimer?.invalidate()
        sampleTimer = nil
        owcCancellable = nil
    }

    func recordFrame() {
        let now = CACurrentMediaTime()
        let delta = now - lastFrameTime
        lastFrameTime = now
        frameCount += 1
        fpsAccumulator += delta

        if fpsAccumulator >= 1.0 {
            fps = frameCount
            frameCount = 0
            fpsAccumulator = 0
        }
    }
}

private class FPSTarget {
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
