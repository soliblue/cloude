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

            if runnerManager.isAnyRunning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("\(runnerManager.runningCount) conversation(s) running...")
                        .font(.caption)
                }
            }
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

            if runnerManager.isAnyRunning {
                Button("Abort All") {
                    runnerManager.abortAll()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }
}
