//
//  ClaudeCodeRunner.swift
//  Cloude Agent
//
//  Manages Claude Code CLI process
//

import Foundation
import Combine

@MainActor
class ClaudeCodeRunner: ObservableObject {
    @Published var isRunning = false
    @Published var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    var onOutput: ((String) -> Void)?
    var onComplete: (() -> Void)?

    private var claudePath: String {
        // Try common locations for claude CLI
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

        // Default to PATH lookup
        return "claude"
    }

    func run(prompt: String, workingDirectory: String? = nil) {
        guard !isRunning else {
            onOutput?("Claude is already running. Use abort to cancel.\n")
            return
        }

        let directory = workingDirectory ?? currentDirectory

        // Update current directory if provided
        if let wd = workingDirectory {
            currentDirectory = wd
        }

        isRunning = true

        process = Process()
        outputPipe = Pipe()
        errorPipe = Pipe()

        // Use shell to ensure PATH is available
        process?.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process?.arguments = ["-l", "-c", "\(claudePath) -p \(shellEscape(prompt))"]
        process?.currentDirectoryURL = URL(fileURLWithPath: directory)
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe

        // Set up environment
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["NO_COLOR"] = "1" // Disable colors for cleaner output
        process?.environment = env

        // Handle stdout
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.onOutput?(text)
                }
            }
        }

        // Handle stderr
        errorPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.onOutput?(text)
                }
            }
        }

        // Handle completion
        process?.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.cleanup()
                self?.onComplete?()
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

        // Send SIGINT first (like Ctrl+C)
        kill(process.processIdentifier, SIGINT)

        // Give it a moment to clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.process?.isRunning == true {
                self?.process?.terminate()
            }
        }
    }

    private func cleanup() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        errorPipe = nil
        isRunning = false
    }

    private func shellEscape(_ string: String) -> String {
        // Escape for shell by wrapping in single quotes and escaping single quotes
        let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
