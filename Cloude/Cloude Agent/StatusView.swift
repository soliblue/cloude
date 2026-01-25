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

    @State private var showToken = false
    @State private var copied = false

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
            actionsSection
        }
        .padding()
        .frame(width: 280)
    }

    private var header: some View {
        HStack {
            Image(systemName: "cloud.fill")
                .font(.title2)
            Text("Cloude Agent")
                .font(.headline)
            Spacer()
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(server.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(server.isRunning ? "Server running on port \(server.port)" : "Server stopped")
                    .font(.caption)
            }

            HStack {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                Text("\(server.connectedClients) client(s) connected")
                    .font(.caption)
            }

            if runner.isRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Claude is running...")
                        .font(.caption)
                }
            }
        }
    }

    private var workingDirectorySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Working Directory")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(runner.currentDirectory)
                .font(.caption)
                .lineLimit(2)
        }
    }

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Auth Token")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                if showToken {
                    Text(token)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                } else {
                    Text("••••••••••••••••")
                        .font(.caption)
                }

                Spacer()

                Button(action: { showToken.toggle() }) {
                    Image(systemName: showToken ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)

                Button(action: copyToken) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionsSection: some View {
        HStack {
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)

            Spacer()

            if runner.isRunning {
                Button("Abort") {
                    runner.abort()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }

    private func copyToken() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(token, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}
