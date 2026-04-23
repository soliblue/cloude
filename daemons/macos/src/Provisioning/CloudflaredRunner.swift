import Foundation

final class CloudflaredRunner {
    static let shared = CloudflaredRunner()

    private var process: Process?

    func start(token: String) -> Bool {
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
                if self?.process === process {
                    self?.process = nil
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
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
    }
}
