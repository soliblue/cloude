//
//  StatusView+Sections.swift
//  Cloude Agent
//
//  Section views for StatusView
//

import SwiftUI

extension StatusView {
    var header: some View {
        HStack {
            Image(systemName: "cloud.fill")
                .font(.title2)
            Text("Cloude Agent")
                .font(.headline)
            Spacer()
        }
    }

    var statusSection: some View {
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

    var workingDirectorySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Working Directory")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(runner.currentDirectory)
                .font(.caption)
                .lineLimit(2)
        }
    }

    var tokenSection: some View {
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

    var ipSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Local IP")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text(NetworkHelper.getIPAddress() ?? "Not available")
                    .font(.system(.caption, design: .monospaced))

                Spacer()

                Button(action: copyIP) {
                    Image(systemName: ipCopied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.plain)
                .disabled(NetworkHelper.getIPAddress() == nil)
            }
        }
    }

    var actionsSection: some View {
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
}
