import SwiftUI

extension StatusView {
    var processesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Claude Processes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(claudeProcesses.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if claudeProcesses.isEmpty {
                Text("No processes running")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(claudeProcesses) { proc in
                        HStack(spacing: 6) {
                            Text("PID \(proc.id)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)

                            if let start = proc.startTime {
                                Text(start, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                _ = ProcessMonitor.killProcess(proc.id)
                                refreshProcesses()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if claudeProcesses.count > 1 {
                Button(action: {
                    _ = ProcessMonitor.killAllClaudeProcesses()
                    refreshProcesses()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Kill All")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    var actionsSection: some View {
        HStack {
            Button("Quit") {
                _ = ProcessMonitor.killAllClaudeProcesses()
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
