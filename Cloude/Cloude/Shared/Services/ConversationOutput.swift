import Foundation
import Combine
import QuartzCore
import UIKit
import CloudeShared

final class ConversationOutput: ObservableObject {
    @Published var text: String = ""
    @Published var toolCalls: [ToolCall] = []
    @Published var runStats: RunStats?
    @Published var phase: StreamPhase = .idle
    @Published var newSessionId: String?
    @Published var liveMessageId: UUID?

    var messageUUID: String?
    var requiresHistoryResync = false
    var lastSeenSeq: Int = 0
    var fullText: String = ""

    let charsPerSecond: Double = 300
    var displayIndex: String.Index?
    var displayLink: CADisplayLink?
    var lastDrainTime: CFTimeInterval = 0
    private var transientStateGeneration = 0

    func appendText(_ chunk: String) {
        fullText += chunk
        startDraining()
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
            if let self, self.transientStateGeneration == generation {
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

    func clearTransientState() {
        stopDraining()
        fullText = ""
        displayIndex = nil
        text = ""
        toolCalls = []
        runStats = nil
        newSessionId = nil
        messageUUID = nil
        requiresHistoryResync = false
    }
}
