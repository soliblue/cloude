//
//  HeartbeatService.swift
//  Cloude Agent
//

import Foundation
import Combine
import CloudeShared

@MainActor
class HeartbeatService: ObservableObject {
    static let shared = HeartbeatService()

    @Published var intervalMinutes: Int? {
        didSet { UserDefaults.standard.set(intervalMinutes, forKey: "heartbeatIntervalMinutes") }
    }
    @Published var messageCount: Int = 0 {
        didSet { UserDefaults.standard.set(messageCount, forKey: "heartbeatMessageCount") }
    }
    @Published var sessionInitialized: Bool = false {
        didSet { UserDefaults.standard.set(sessionInitialized, forKey: "heartbeatSessionInitialized") }
    }
    @Published var projectDirectory: String? {
        didSet { UserDefaults.standard.set(projectDirectory, forKey: "heartbeatProjectDirectory") }
    }
    @Published var unreadCount: Int = 0
    @Published var isRunning = false

    private var timer: DispatchSourceTimer?

    var runnerManager: RunnerManager?

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
        messageCount = UserDefaults.standard.integer(forKey: "heartbeatMessageCount")
        projectDirectory = UserDefaults.standard.string(forKey: "heartbeatProjectDirectory")

        if intervalMinutes != nil {
            scheduleTimer()
        }
    }

    func setInterval(_ minutes: Int?) {
        Log.info("Setting interval to \(String(describing: minutes)) minutes")
        intervalMinutes = minutes
        scheduleTimer()
    }

    func getConfig() -> (intervalMinutes: Int?, unreadCount: Int) {
        (intervalMinutes, unreadCount)
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
                self?.triggerNow()
            }
        }
        timer?.resume()
    }

    func triggerNow() {
        guard let runnerManager else {
            Log.error("No runnerManager set for HeartbeatService")
            return
        }

        guard !isRunning else {
            Log.info("Heartbeat already running, skipping")
            return
        }

        Log.info("Starting heartbeat run (messageCount=\(messageCount))")
        isRunning = true

        let shouldCompact = messageCount >= compactThreshold
        let prompt = shouldCompact ? "/compact\n\n\(heartbeatPrompt)" : heartbeatPrompt

        if shouldCompact {
            Log.info("Running /compact before heartbeat")
        }

        let workingDir = projectDirectory ?? Self.findCloudeProjectRoot() ?? MemoryService.projectRoot

        runnerManager.run(
            prompt: prompt,
            workingDirectory: workingDir,
            sessionId: Heartbeat.sessionId,
            isNewSession: true,
            imageBase64: nil,
            conversationId: Heartbeat.sessionId,
            useFixedSessionId: true
        )

        messageCount += 1
        if shouldCompact {
            messageCount = 0
        }
    }

    func handleComplete(isEmpty: Bool) {
        if !isEmpty {
            unreadCount += 1
        }
        isRunning = false
    }

    private static func findCloudeProjectRoot() -> String? {
        let possiblePaths = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/CODING/cloude").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("cloude").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Projects/cloude").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer/cloude").path
        ]

        for path in possiblePaths {
            let claudeMdPath = (path as NSString).appendingPathComponent("CLAUDE.md")
            if FileManager.default.fileExists(atPath: claudeMdPath) {
                Log.info("Found Cloude project at \(path)")
                return path
            }
        }
        return nil
    }
}
