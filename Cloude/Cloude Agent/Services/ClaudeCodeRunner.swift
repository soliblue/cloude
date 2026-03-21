import Foundation
import Combine
import CloudeShared

@MainActor
class ClaudeCodeRunner: ObservableObject {
    @Published var isRunning = false
    @Published var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path

    let events = PassthroughSubject<RunnerEvent, Never>()

    var process: Process?
    var outputPipe: Pipe?
    var errorPipe: Pipe?

    var onOutput: ((String) -> Void)?
    var onToolCall: ((String, String?, String, String?, Int, EditInfo?) -> Void)?
    var onToolResult: ((String, String?, String?) -> Void)?
    var onComplete: (() -> Void)?
    var onSessionId: ((String) -> Void)?
    var onRunStats: ((Int, Double, String?) -> Void)?
    var onCloudeCommand: ((String, String) -> Void)?
    var onStatus: ((AgentState) -> Void)?
    var onMessageUUID: ((String) -> Void)?
    var onTeamCreated: ((String, String) -> Void)?
    var onTeammateSpawned: ((TeammateInfo) -> Void)?
    var onTeamDeleted: (() -> Void)?

    var pendingRunStats: (durationMs: Int, costUsd: Double, model: String?)?
    var activeModel: String?
    var accumulatedOutput = ""
    var lineBuffer = ""

    var claudePath: String {
        let paths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/claude",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.npm-global/bin/claude"
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return "claude"
    }

    var tempImagePaths: [String] = []
    var tempFilePaths: [String] = []

    func abort() {
        guard isRunning, let process = process else { return }

        kill(process.processIdentifier, SIGINT)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.process?.isRunning == true {
                self?.process?.terminate()
            }
        }
    }

    func shellEscape(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
