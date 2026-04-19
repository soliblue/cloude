import Foundation
import Combine
import CloudeShared

@MainActor
class ClaudeCodeRunner: ObservableObject {
    @Published var isRunning = false
    @Published var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path

    var process: Process?
    var outputPipe: Pipe?
    var errorPipe: Pipe?

    var onOutput: ((String) -> Void)?
    var onToolCall: ((String, String?, String, String?, Int, EditInfo?) -> Void)?
    var onToolResult: ((String, String?, String?) -> Void)?
    var onComplete: (() -> Void)?
    var onSessionId: ((String) -> Void)?
    var onRunStats: ((Int, Double, String?) -> Void)?
    var onStatus: ((AgentState) -> Void)?
    var onMessageUUID: ((String) -> Void)?
    var pendingRunStats: (durationMs: Int, costUsd: Double, model: String?)?
    var activeModel: String?
    var accumulatedOutput = ""
    var deltaTextCount = 0
    var lineBuffer = ""

    var claudePath: String { ClaudePaths.resolve() }
    func shellEscape(_ string: String) -> String { ClaudePaths.shellEscape(string) }

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
}
