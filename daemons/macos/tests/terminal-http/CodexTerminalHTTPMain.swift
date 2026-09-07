import Foundation

@main
struct CodexTerminalHTTPMain {
    static let server = HTTPServer()
    static func main() {
        server.start()
        dispatchMain()
    }
}
