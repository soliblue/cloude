import Foundation
import Combine
import QuartzCore
import UIKit
import CloudeShared

final class ConversationOutput: ObservableObject {
    weak var parent: ConnectionManager?

    @Published var text: String = "" { didSet { if oldValue.isEmpty != text.isEmpty { parent?.objectWillChange.send() } } }
    @Published var toolCalls: [ToolCall] = []
    @Published var runStats: RunStats?
    @Published var phase: StreamPhase = .idle { didSet { if phase != oldValue { parent?.objectWillChange.send() } } }
    @Published var newSessionId: String? { didSet { if newSessionId != oldValue { parent?.objectWillChange.send() } } }
    var messageUUID: String?
    @Published var liveMessageId: UUID?
    var needsHistorySync = false
    var lastSeenSeq: Int = 0

    var fullText: String = ""
    private var displayIndex: String.Index?
    private var displayLink: CADisplayLink?
    private var lastDrainTime: CFTimeInterval = 0
    private let charsPerSecond: Double = 300
    private var transientStateGeneration = 0

    func appendText(_ chunk: String) {
        fullText += chunk
        startDraining()
    }

    private func startDraining() {
        guard displayLink == nil else { return }
        if displayIndex == nil {
            displayIndex = fullText.startIndex
        }
        lastDrainTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(drainTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func drainTick() {
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

    private func stopDraining() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func flushBuffer() {
        stopDraining()
        if !fullText.isEmpty {
            text = fullText
            displayIndex = fullText.endIndex
        }
    }

    func completeExecutingTools(topLevelOnly: Bool = false) {
        guard toolCalls.contains(where: { $0.state == .executing && (!topLevelOnly || $0.parentToolId == nil) }) else { return }
        toolCalls = toolCalls.map { tool in
            if tool.state == .executing && (!topLevelOnly || tool.parentToolId == nil) {
                var updated = tool
                updated.state = .complete
                return updated
            }
            return tool
        }
    }

    func completeTopLevelExecutingTools() {
        completeExecutingTools(topLevelOnly: true)
    }

    func resetAfterLiveMessageHandoff() {
        #if DEBUG
        DebugMetrics.log(
            "Stream",
            "handoff start liveId=\(liveMessageId?.uuidString.prefix(6) ?? "nil") " +
            "text=\(text.count)ch full=\(fullText.count)ch tools=\(toolCalls.count) " +
            "phase=\(phase)"
        )
        #endif
        liveMessageId = nil
        transientStateGeneration += 1
        let generation = transientStateGeneration
        DispatchQueue.main.async { [weak self] in
            if let self, self.transientStateGeneration == generation, self.phase == .idle, self.liveMessageId == nil {
                self.clearTransientState()
            }
        }
    }

    func reset() {
        #if DEBUG
        DebugMetrics.log(
            "Stream",
            "reset start liveId=\(liveMessageId?.uuidString.prefix(6) ?? "nil") " +
            "text=\(text.count)ch full=\(fullText.count)ch tools=\(toolCalls.count) " +
            "phase=\(phase)"
        )
        #endif
        transientStateGeneration += 1
        liveMessageId = nil
        clearTransientState()
        #if DEBUG
        DebugMetrics.log(
            "Stream",
            "reset end liveId=\(liveMessageId?.uuidString.prefix(6) ?? "nil") " +
            "text=\(text.count)ch full=\(fullText.count)ch tools=\(toolCalls.count) " +
            "phase=\(phase)"
        )
        #endif
    }

    private func clearTransientState() {
        stopDraining()
        fullText = ""
        displayIndex = nil
        text = ""
        toolCalls = []
        runStats = nil
        newSessionId = nil
        messageUUID = nil
        needsHistorySync = false
    }
}
