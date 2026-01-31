//
//  HeartbeatService.swift
//  Cloude Agent
//

import Foundation
import Combine

@MainActor
class HeartbeatService: ObservableObject {
    static let shared = HeartbeatService()

    @Published var intervalMinutes: Int? {
        didSet { UserDefaults.standard.set(intervalMinutes, forKey: "heartbeatIntervalMinutes") }
    }
    @Published var sessionId: String? {
        didSet { UserDefaults.standard.set(sessionId, forKey: "heartbeatSessionId") }
    }
    @Published var messageCount: Int = 0 {
        didSet { UserDefaults.standard.set(messageCount, forKey: "heartbeatMessageCount") }
    }
    @Published var unreadCount: Int = 0
    @Published var isRunning = false

    private var timer: DispatchSourceTimer?
    private var runner: ClaudeCodeRunner?
    private var accumulatedOutput = ""

    var onOutput: ((String) -> Void)?
    var onComplete: ((String) -> Void)?
    var onSessionId: ((String) -> Void)?

    private let heartbeatPrompt = """
        This is your autonomous heartbeat. Use this time proactively:
        - Explore the codebase for refactoring opportunities or code improvements
        - Add feature ideas or notes to CLAUDE.local.md (your personal memory file)
        - Send a message with observations or suggestions
        - Update your memory section in CLAUDE.local.md
        - Check git status for uncommitted work
        - Look for patterns that could be cleaner
        Be concise but do something useful. Only output <skip> if you genuinely have nothing to contribute.
        """

    private let compactThreshold = 30

    private init() {
        intervalMinutes = UserDefaults.standard.object(forKey: "heartbeatIntervalMinutes") as? Int
        sessionId = UserDefaults.standard.string(forKey: "heartbeatSessionId")
        messageCount = UserDefaults.standard.integer(forKey: "heartbeatMessageCount")

        if intervalMinutes != nil {
            scheduleTimer()
        }
    }

    func setInterval(_ minutes: Int?) {
        Log.info("Setting interval to \(String(describing: minutes)) minutes")
        intervalMinutes = minutes
        scheduleTimer()
    }

    func getConfig() -> (intervalMinutes: Int?, unreadCount: Int, sessionId: String?) {
        (intervalMinutes, unreadCount, sessionId)
    }

    func markRead() {
        unreadCount = 0
    }

    private func scheduleTimer() {
        timer?.cancel()
        timer = nil

        guard let minutes = intervalMinutes, minutes > 0 else { return }

        let queue = DispatchQueue.main
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now() + .seconds(minutes * 60), repeating: .seconds(minutes * 60))
        timer?.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                Log.info("Timer fired, triggering heartbeat")
                self?.runHeartbeat()
            }
        }
        timer?.resume()
    }

    func runHeartbeat() {
        guard !isRunning else {
            Log.info("Heartbeat already running, skipping")
            return
        }
        Log.info("Starting heartbeat run (messageCount=\(messageCount), sessionId=\(String(describing: sessionId)))")
        isRunning = true
        accumulatedOutput = ""

        if runner == nil {
            runner = ClaudeCodeRunner()
            setupRunnerCallbacks()
        }

        let shouldCompact = messageCount >= compactThreshold
        let prompt = shouldCompact ? "/compact\n\n\(heartbeatPrompt)" : heartbeatPrompt

        if shouldCompact {
            Log.info("Running /compact before heartbeat")
        }

        let cloudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/coding/cloude").path
        runner?.run(
            prompt: prompt,
            workingDirectory: cloudeDir,
            sessionId: sessionId,
            isNewSession: sessionId == nil
        )

        messageCount += 1
        if shouldCompact {
            messageCount = 0
        }
    }

    private func setupRunnerCallbacks() {
        runner?.onOutput = { [weak self] (text: String) in
            Task { @MainActor in
                self?.accumulatedOutput += text
                self?.onOutput?(text)
            }
        }

        runner?.onSessionId = { [weak self] (sid: String) in
            Task { @MainActor in
                self?.sessionId = sid
                self?.onSessionId?(sid)
            }
        }

        runner?.onComplete = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let output = self.accumulatedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                let isSkip = output == "<skip>" || output == "." || output.isEmpty
                Log.info("Heartbeat complete, length=\(output.count), isSkip=\(isSkip)")
                if !output.isEmpty {
                    self.unreadCount += 1
                    self.onComplete?(output)
                }
                self.isRunning = false
            }
        }
    }

    func triggerNow() {
        Log.info("Manual trigger requested")
        runHeartbeat()
    }
}
