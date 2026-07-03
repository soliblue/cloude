import Foundation

final class CloudflaredRunner {
    static let shared = CloudflaredRunner()

    private let queue = DispatchQueue(label: "soli.Cloude.cloudflared")
    private var process: Process?
    private var lastToken: String?

    func start(token: String) -> Bool {
        queue.sync { startLocked(token: token) }
    }

    private func startLocked(token: String) -> Bool {
        lastToken = token
        if let process, process.isRunning {
            return true
        }
        if let binary = CloudflaredBinary.url {
            let process = Process()
            process.executableURL = binary
            process.arguments = ["tunnel", "run", "--token", token]
            let devNull = FileHandle(forWritingAtPath: "/dev/null")
            process.standardOutput = devNull
            process.standardError = devNull
            process.terminationHandler = { [weak self] _ in
                guard let self else { return }
                self.queue.async {
                    guard self.process === process else { return }
                    self.process = nil
                    if self.lastToken != nil {
                        NSLog("CloudflaredRunner: exited unexpectedly, restarting in 5s")
                        self.queue.asyncAfter(deadline: .now() + 5) {
                            if let token = self.lastToken {
                                _ = self.startLocked(token: token)
                            }
                        }
                    }
                }
            }
            if (try? process.run()) != nil {
                self.process = process
                return true
            }
        }
        return false
    }

    func stop() {
        queue.sync {
            lastToken = nil
            if let process, process.isRunning {
                process.terminate()
            }
            process = nil
        }
    }
}
