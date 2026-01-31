import Foundation
import Combine

@MainActor
class ClaudeCodeRunner: ObservableObject {
    @Published var isRunning = false
    @Published var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path

    let events = PassthroughSubject<RunnerEvent, Never>()

    var process: Process?
    var outputPipe: Pipe?
    var errorPipe: Pipe?

    var onOutput: ((String) -> Void)?
    var onToolCall: ((String, String?, String, String?, Int) -> Void)?
    var onComplete: (() -> Void)?
    var onSessionId: ((String) -> Void)?
    var onRunStats: ((Int, Double) -> Void)?

    var accumulatedOutput = ""
    var lineBuffer = ""

    private var claudePath: String {
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

    var tempImagePath: String?

    func run(prompt: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, imageBase64: String? = nil) {
        guard !isRunning else {
            onOutput?("Claude is already running. Use abort to cancel.\n")
            return
        }

        let directory = workingDirectory ?? currentDirectory

        if let wd = workingDirectory {
            currentDirectory = wd
        }

        if let base64 = imageBase64, let imageData = Data(base64Encoded: base64) {
            let tempDir = FileManager.default.temporaryDirectory
            let imagePath = tempDir.appendingPathComponent("cloude_image_\(UUID().uuidString).png").path
            FileManager.default.createFile(atPath: imagePath, contents: imageData)
            tempImagePath = imagePath
        } else {
            tempImagePath = nil
        }

        isRunning = true
        accumulatedOutput = ""

        process = Process()
        outputPipe = Pipe()
        errorPipe = Pipe()

        var finalPrompt = prompt
        if let imagePath = tempImagePath {
            finalPrompt = "First, read the image at \(imagePath)\n\n\(prompt)"
        }

        var command = claudePath
        if let sid = sessionId, !isNewSession {
            command += " --resume \(sid)"
        }
        command += " --dangerously-skip-permissions --output-format stream-json --verbose --include-partial-messages -p \(shellEscape(finalPrompt))"

        process?.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process?.arguments = ["-l", "-c", command]
        process?.currentDirectoryURL = URL(fileURLWithPath: directory)
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["NO_COLOR"] = "1"
        process?.environment = env

        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            guard let self else { return }
            Task { @MainActor [self] in
                self.processStreamLines(text)
            }
        }

        errorPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            guard let self else { return }
            Task { @MainActor [self] in
                self.onOutput?(text)
            }
        }

        process?.terminationHandler = { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.drainPipesAndComplete()
            }
        }

        do {
            try process?.run()
        } catch {
            onOutput?("Failed to start Claude: \(error.localizedDescription)\n")
            cleanup()
        }
    }

    func abort() {
        guard isRunning, let process = process else { return }

        kill(process.processIdentifier, SIGINT)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.process?.isRunning == true {
                self?.process?.terminate()
            }
        }
    }

    private func shellEscape(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
