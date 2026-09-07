import Foundation

final class CodexLoginService {
    static let shared = CodexLoginService()
    static var request: (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void = {
        CodexClient.shared.request($0, params: $1, completion: $2)
    }

    private let lock = NSLock()
    private var state = "idle"
    private var loginId: String?
    private var userCode: String?
    private var verificationUrl: String?
    private var error: String?
    private var generation = 0
    private var early: [String: Bool] = [:]
    private var cancelRequested = false
    private var canceling = false
    private var failureDuringCancel = false

    private init() {
        CodexClient.shared.observe(
            id: "codex-login", on: .global(), message: { [weak self] message in self?.notification(message) },
            disconnected: { [weak self] disconnect in self?.disconnected(disconnect) })
    }

    func status() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return snapshot()
    }

    func start() -> [String: Any] {
        lock.lock()
        if state == "pending" {
            let current = snapshot()
            lock.unlock()
            return current
        }
        generation += 1
        let currentGeneration = generation
        state = "pending"
        loginId = nil
        userCode = nil
        verificationUrl = nil
        error = nil
        early.removeAll()
        cancelRequested = false
        canceling = false
        failureDuringCancel = false
        lock.unlock()
        Self.request("account/login/start", ["type": "chatgptDeviceCode"]) { [weak self] result in
            self?.started(result, generation: currentGeneration)
        }
        return status()
    }

    func cancel() -> [String: Any] {
        lock.lock()
        guard state == "pending" else {
            let current = snapshot()
            lock.unlock()
            return current
        }
        cancelRequested = true
        let currentLoginId = loginId
        let currentGeneration = generation
        let shouldRequest = currentLoginId != nil && !canceling
        if shouldRequest { canceling = true }
        lock.unlock()
        if let currentLoginId, shouldRequest {
            Self.request("account/login/cancel", ["loginId": currentLoginId]) { [weak self] result in
                self?.canceled(result, generation: currentGeneration, loginId: currentLoginId)
            }
        }
        return status()
    }

    func notification(_ message: [String: Any]) {
        guard message["method"] as? String == "account/login/completed",
            let params = message["params"] as? [String: Any], let success = params["success"] as? Bool,
            let notificationLoginId = params["loginId"] as? String, !notificationLoginId.isEmpty
        else { return }
        lock.lock()
        defer { lock.unlock() }
        guard state == "pending" else { return }
        if let currentLoginId = loginId {
            guard notificationLoginId == currentLoginId else { return }
            if canceling, !success {
                failureDuringCancel = true
                return
            }
            state = success ? "completed" : "failed"
            clearTerminal()
            loginId = notificationLoginId
            if !success { error = "Sign-in failed. Start a new device code and try again." }
        } else if early.count < 16 {
            early[notificationLoginId] = success
        }
    }

    func resetForTesting() {
        lock.lock()
        generation += 1
        state = "idle"
        loginId = nil
        userCode = nil
        verificationUrl = nil
        error = nil
        early.removeAll()
        cancelRequested = false
        canceling = false
        failureDuringCancel = false
        lock.unlock()
    }

    func disconnected(_ disconnect: Error) {
        lock.lock()
        if state == "pending" {
            state = "failed"
            clearTerminal()
            error = "Codex disconnected during sign-in. Start a new device code."
        }
        lock.unlock()
    }

    private func started(_ result: Result<[String: Any], Error>, generation expectedGeneration: Int) {
        lock.lock()
        guard generation == expectedGeneration, state == "pending" else {
            lock.unlock()
            return
        }
        var cancelId: String?
        switch result {
        case .success(let value):
            if value["type"] as? String == "chatgptDeviceCode",
                let returnedId = value["loginId"] as? String, returnedId.count <= 512, !returnedId.isEmpty,
                let returnedCode = value["userCode"] as? String, returnedCode.count <= 256, !returnedCode.isEmpty,
                let returnedUrl = value["verificationUrl"] as? String, validUrl(returnedUrl)
            {
                loginId = returnedId
                userCode = returnedCode
                verificationUrl = returnedUrl
                error = nil
                if let earlyResult = early.removeValue(forKey: returnedId) {
                    state = earlyResult ? "completed" : "failed"
                    clearTerminal()
                    if !earlyResult { error = "Sign-in failed. Start a new device code and try again." }
                }
                let shouldCancel = state == "pending" && cancelRequested && !canceling
                canceling = shouldCancel
                if shouldCancel { cancelId = returnedId }
            } else {
                state = "failed"
                clearTerminal()
                error = "Codex did not return a supported ChatGPT device-code sign-in."
            }
        case .failure:
            state = "failed"
            clearTerminal()
            error = "Could not start Codex sign-in. Check the host connection and device-code sign-in availability."
        }
        lock.unlock()
        if let cancelId {
            Self.request("account/login/cancel", ["loginId": cancelId]) { [weak self] result in
                self?.canceled(result, generation: expectedGeneration, loginId: cancelId)
            }
        }
    }

    private func canceled(
        _ result: Result<[String: Any], Error>, generation expectedGeneration: Int, loginId expectedLoginId: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard generation == expectedGeneration, state == "pending", loginId == expectedLoginId else { return }
        canceling = false
        cancelRequested = false
        switch result {
        case .success(let value) where ["canceled", "notFound"].contains(value["status"] as? String):
            state = "canceled"
            clearTerminal()
            loginId = expectedLoginId
        case .failure where failureDuringCancel:
            state = "failed"
            clearTerminal()
            loginId = expectedLoginId
            error = "Sign-in failed. Start a new device code and try again."
        default:
            error = "Could not cancel sign-in. Try again."
        }
    }

    private func snapshot() -> [String: Any] {
        var value: [String: Any] = ["status": state]
        if let loginId { value["loginId"] = loginId }
        if let userCode { value["userCode"] = userCode }
        if let verificationUrl { value["verificationUrl"] = verificationUrl }
        if let error { value["error"] = error }
        return value
    }

    private func clearTerminal() {
        if state != "pending" {
            userCode = nil
            verificationUrl = nil
            cancelRequested = false
            canceling = false
            failureDuringCancel = false
        }
    }

    private func validUrl(_ value: String) -> Bool {
        value.count <= 2048 && value.hasPrefix("https://auth.openai.com/")
            && !value.contains(where: { $0.isWhitespace })
            && URL(string: value)?.scheme == "https"
            && URL(string: value)?.host == "auth.openai.com"
            && URL(string: value)?.port == nil
            && URL(string: value)?.user == nil
            && URL(string: value)?.password == nil
    }
}
