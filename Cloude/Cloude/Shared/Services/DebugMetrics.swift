import Foundation
import QuartzCore
import Combine

@MainActor
final class DebugMetrics: ObservableObject {
    static let shared = DebugMetrics()
    nonisolated static let logFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("debug-metrics.log")
    nonisolated private static let fileQueue = DispatchQueue(label: "soli.Cloude.DebugMetrics", qos: .utility)

    @Published var fps: Int = 0
    @Published var objectWillChangeRate: Int = 0
    private(set) var logBuffers: [String: [DebugEntry]] = [:]
    private let maxLogsPerSource = 200

    var sources: [String] { Array(logBuffers.keys).sorted() }

    static func log(_ source: String, _ message: String) {
        guard UserDefaults.standard.bool(forKey: "debugOverlayEnabled") else { return }
        let entry = DebugEntry(time: Date(), source: source, message: message)
        var buf = shared.logBuffers[source, default: []]
        buf.append(entry)
        if buf.count > shared.maxLogsPerSource {
            buf.removeFirst(buf.count - shared.maxLogsPerSource)
        }
        shared.logBuffers[source] = buf
        NSLog("[\(source)] \(message)")
        shared.persist(entry)
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
        try? Data().write(to: Self.logFileURL)
    }

    private var fpsLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fpsAccumulator: CFTimeInterval = 0

    private var owcCount: Int = 0
    private var sampleTimer: Timer?
    private var owcCancellable: AnyCancellable?

    private var isRunning = false

    init() {
        let line = "\n=== Debug Session \(Self.fileTimeFormatter.string(from: Date())) ===\n"
        if let data = line.data(using: .utf8) {
            if !FileManager.default.fileExists(atPath: Self.logFileURL.path) {
                FileManager.default.createFile(atPath: Self.logFileURL.path, contents: nil)
            }
            if let handle = try? FileHandle(forWritingTo: Self.logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        }
    }

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
                if let self {
                    AppLogger.performanceInfo("debug sample fps=\(self.fps) owcPerSec=\(self.owcCount)")
                }
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

    private func persist(_ entry: DebugEntry) {
        let line = "\(Self.lineTimeFormatter.string(from: entry.time)) [\(entry.source)] \(entry.message)\n"
        guard let data = line.data(using: .utf8) else { return }
        Self.fileQueue.async {
            if !FileManager.default.fileExists(atPath: Self.logFileURL.path) {
                FileManager.default.createFile(atPath: Self.logFileURL.path, contents: nil)
            }
            if let handle = try? FileHandle(forWritingTo: Self.logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        }
    }

    private static let lineTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private static let fileTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
