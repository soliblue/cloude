import SwiftUI

struct StatusView: View {
    @ObservedObject var server: WebSocketServer
    @ObservedObject var runnerManager: RunnerManager
    let token: String

    @State var showToken = false
    @State var copied = false
    @State var ipCopied = false
    @State var claudeProcesses: [ClaudeProcess] = []
    @State var processRefreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            statusSection
            Divider()
            processesSection
            Divider()
            tokenSection
            Divider()
            ipSection
            Divider()
            actionsSection
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            refreshProcesses()
            processRefreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                refreshProcesses()
            }
        }
        .onDisappear {
            processRefreshTimer?.invalidate()
            processRefreshTimer = nil
        }
    }

    func refreshProcesses() {
        claudeProcesses = ProcessMonitor.findClaudeProcesses()
    }

    func copyToken() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(token, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    func copyIP() {
        guard let ip = NetworkHelper.getIPAddress() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
        ipCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            ipCopied = false
        }
    }
}
