import Foundation
import Combine
import CloudeShared

extension ClaudeCodeRunner {
    func drainPipesAndComplete() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        if let data = outputPipe?.fileHandleForReading.readDataToEndOfFile(),
           !data.isEmpty,
           let text = String(data: data, encoding: .utf8) {
            processStreamLines(text)
        }

        if let data = errorPipe?.fileHandleForReading.readDataToEndOfFile(),
           !data.isEmpty,
           let text = String(data: data, encoding: .utf8) {
            onOutput?(text)
        }

        process = nil
        outputPipe = nil
        errorPipe = nil
        isRunning = false
        accumulatedOutput = ""
        lineBuffer = ""

        if let stats = pendingRunStats {
            events.send(.runStats(durationMs: stats.durationMs, costUsd: stats.costUsd))
            onRunStats?(stats.durationMs, stats.costUsd, stats.model)
            pendingRunStats = nil
        }

        events.send(.complete)
        onComplete?()
    }

    func cleanup() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        errorPipe = nil
        isRunning = false
        activeModel = nil
        accumulatedOutput = ""
        lineBuffer = ""
        pendingRunStats = nil

        for imagePath in tempImagePaths {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        tempImagePaths = []
    }

    func handleContentBlockEvent(type: String, json: [String: Any]) {
        let contentBlock: (type: String, json: [String: Any])? = {
            if type == "stream_event",
               let event = json["event"] as? [String: Any],
               let eventType = event["type"] as? String {
                return (eventType, event)
            }
            if type == "content_block_start" || type == "content_block_delta" {
                return (type, json)
            }
            return nil
        }()

        if let cb = contentBlock {
            if cb.type == "content_block_start" {
                if !accumulatedOutput.isEmpty && !accumulatedOutput.hasSuffix("\n") {
                    accumulatedOutput += "\n\n"
                    onOutput?("\n\n")
                }
            }
            if cb.type == "content_block_delta",
               let delta = cb.json["delta"] as? [String: Any],
               let deltaText = delta["text"] as? String {
                accumulatedOutput += deltaText
                events.send(.output(deltaText))
                onOutput?(deltaText)
            }
        }
    }
}
