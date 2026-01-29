//
//  StatusView.swift
//  Cloude Agent
//
//  Menu bar popover showing agent status
//

import SwiftUI

struct StatusView: View {
    @ObservedObject var server: WebSocketServer
    @ObservedObject var runner: ClaudeCodeRunner
    let token: String

    @State var showToken = false
    @State var copied = false
    @State var ipCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            statusSection
            Divider()
            workingDirectorySection
            Divider()
            tokenSection
            Divider()
            ipSection
            Divider()
            actionsSection
        }
        .padding()
        .frame(width: 280)
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
