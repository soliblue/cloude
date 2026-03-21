import Foundation
import CloudeShared

extension ClaudeCodeRunner {
    func run(prompt: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, imagesBase64: [String]? = nil, filesBase64: [AttachedFilePayload]? = nil, useFixedSessionId: Bool = false, forkSession: Bool = false, model: String? = nil, effort: String? = nil) {
        guard !isRunning else {
            onOutput?("Claude is already running. Use abort to cancel.\n")
            return
        }

        let directory = workingDirectory ?? currentDirectory

        if let wd = workingDirectory {
            currentDirectory = wd
        }

        tempImagePaths = []
        if let images = imagesBase64 {
            let tempDir = FileManager.default.temporaryDirectory
            for base64 in images {
                if let imageData = Data(base64Encoded: base64) {
                    let imagePath = tempDir.appendingPathComponent("cloude_image_\(UUID().uuidString).png").path
                    FileManager.default.createFile(atPath: imagePath, contents: imageData)
                    tempImagePaths.append(imagePath)
                }
            }
        }

        tempFilePaths = []
        if let files = filesBase64 {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("cloude_files_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            for file in files {
                if let fileData = Data(base64Encoded: file.data) {
                    let filePath = tempDir.appendingPathComponent(file.name).path
                    FileManager.default.createFile(atPath: filePath, contents: fileData)
                    tempFilePaths.append(filePath)
                }
            }
        }

        isRunning = true
        activeModel = model
        accumulatedOutput = ""

        process = Process()
        outputPipe = Pipe()
        errorPipe = Pipe()

        var finalPrompt = prompt
        if !tempFilePaths.isEmpty {
            let readLines = tempFilePaths.map { "Read the file at \($0)" }.joined(separator: "\n")
            finalPrompt = "\(readLines)\n\n\(finalPrompt)"
        }
        if !tempImagePaths.isEmpty {
            let readLines = tempImagePaths.map { "First, read the image at \($0)" }.joined(separator: "\n")
            finalPrompt = "\(readLines)\n\n\(finalPrompt)"
        }

        var command = claudePath
        if let model = model {
            command += " --model \(model)"
        }
        if let effort = effort {
            command += " --effort \(effort)"
        }
        if let sid = sessionId {
            if forkSession {
                command += " --resume \(sid) --fork-session"
            } else if useFixedSessionId {
                if isNewSession {
                    command += " --session-id \(sid)"
                } else {
                    command += " --resume \(sid)"
                }
            } else if !isNewSession {
                command += " --resume \(sid)"
            }
        }
        command += " --dangerously-skip-permissions --output-format stream-json --verbose --include-partial-messages -p \(shellEscape(finalPrompt))"

        process?.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process?.arguments = ["-l", "-i", "-c", command]
        process?.currentDirectoryURL = URL(fileURLWithPath: directory)
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["NO_COLOR"] = "1"
        env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
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
}
