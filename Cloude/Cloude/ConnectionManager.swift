import Foundation
import Combine

@MainActor
class ConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var isAuthenticated = false
    @Published var agentState: AgentState = .idle
    @Published var lastError: String?

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var serverURL: String = ""
    private var authToken: String = ""

    var onOutput: ((String) -> Void)?
    var onFileChange: ((String, String?, String?) -> Void)?
    var onDirectoryListing: ((String, [FileEntry]) -> Void)?
    var onFileContent: ((String, String, String, Int64) -> Void)?

    func connect(host: String, port: UInt16, token: String) {
        disconnect()

        serverURL = "ws://\(host):\(port)"
        authToken = token

        guard let url = URL(string: serverURL) else {
            lastError = "Invalid URL"
            return
        }

        session = URLSession(configuration: .default)
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        isConnected = true
        lastError = nil

        receiveMessage()
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session = nil
        isConnected = false
        isAuthenticated = false
        agentState = .idle
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self?.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self?.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    self?.receiveMessage()

                case .failure(let error):
                    self?.lastError = error.localizedDescription
                    self?.isConnected = false
                    self?.isAuthenticated = false
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ServerMessage.self, from: data) else {
            return
        }

        switch message {
        case .output(let text):
            onOutput?(text)

        case .fileChange(let path, let diff, let content):
            onFileChange?(path, diff, content)

        case .status(let state):
            agentState = state

        case .authRequired:
            authenticate()

        case .authResult(let success, let errorMessage):
            isAuthenticated = success
            if !success {
                lastError = errorMessage ?? "Authentication failed"
            }

        case .error(let errorMessage):
            lastError = errorMessage

        case .image:
            break

        case .directoryListing(let path, let entries):
            onDirectoryListing?(path, entries)

        case .fileContent(let path, let data, let mimeType, let size):
            onFileContent?(path, data, mimeType, size)
        }
    }

    private func authenticate() {
        send(.auth(token: authToken))
    }

    func sendChat(_ message: String, workingDirectory: String? = nil) {
        guard isAuthenticated else {
            lastError = "Not authenticated"
            return
        }
        send(.chat(message: message, workingDirectory: workingDirectory))
    }

    func abort() {
        send(.abort)
    }

    func listDirectory(path: String) {
        guard isAuthenticated else { return }
        send(.listDirectory(path: path))
    }

    func getFile(path: String) {
        guard isAuthenticated else { return }
        send(.getFile(path: path))
    }

    private func send(_ message: ClientMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }

        webSocket?.send(.string(text)) { [weak self] error in
            if let error = error {
                Task { @MainActor in
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }
}
