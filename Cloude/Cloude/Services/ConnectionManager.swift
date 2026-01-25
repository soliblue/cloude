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
    private var savedHost: String = ""
    private var savedPort: UInt16 = 8765
    private var savedToken: String = ""

    var onOutput: ((String) -> Void)?
    var onFileChange: ((String, String?, String?) -> Void)?
    var onDirectoryListing: ((String, [FileEntry]) -> Void)?
    var onFileContent: ((String, String, String, Int64) -> Void)?

    var hasCredentials: Bool {
        !savedHost.isEmpty && !savedToken.isEmpty
    }

    func connect(host: String, port: UInt16, token: String) {
        savedHost = host
        savedPort = port
        savedToken = token
        reconnect()
    }

    func reconnect() {
        guard hasCredentials else { return }
        disconnect(clearCredentials: false)

        guard let url = URL(string: "ws://\(savedHost):\(savedPort)") else {
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

    func reconnectIfNeeded() {
        guard hasCredentials, !isAuthenticated else { return }
        reconnect()
    }

    func disconnect(clearCredentials: Bool = true) {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session = nil
        isConnected = false
        isAuthenticated = false
        agentState = .idle

        if clearCredentials {
            savedHost = ""
            savedToken = ""
        }
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
        send(.auth(token: savedToken))
    }

    func sendChat(_ message: String, workingDirectory: String? = nil) {
        if !isAuthenticated {
            reconnectIfNeeded()
        }
        send(.chat(message: message, workingDirectory: workingDirectory))
    }

    func abort() {
        send(.abort)
    }

    func listDirectory(path: String) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.listDirectory(path: path))
    }

    func getFile(path: String) {
        if !isAuthenticated { reconnectIfNeeded() }
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
