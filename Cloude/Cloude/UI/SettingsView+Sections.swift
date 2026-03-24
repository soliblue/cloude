import SwiftUI
import CloudeShared

extension SettingsView {
    var processesSection: some View {
        Section {
            if connection.processes.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.pastelGreen)
                    Text("No Claude processes running")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(connection.processes) { proc in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let name = proc.conversationName {
                                Text(name)
                                    .font(.system(.body, weight: .medium))
                            } else {
                                Text("PID \(proc.pid)")
                                    .font(.system(.body, design: .monospaced))
                            }
                            HStack(spacing: 8) {
                                if proc.conversationName != nil {
                                    Text("PID \(proc.pid)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let start = proc.startTime {
                                    Text(start, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Button(action: { connection.killProcess(pid: proc.pid) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                        .tint(.accentColor)
                    }
                }

                if connection.processes.count > 1 {
                    Button(action: { connection.killAllProcesses() }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .font(.subheadline)
                            Text("Kill All Processes")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }
            }
        } header: {
            HStack {
                Text("Claude Processes")
                Spacer()
                Button(action: { connection.getProcesses() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("Running Claude Code processes on the Mac agent")
        }
        .listRowBackground(Color.themeSecondary)
    }

    @ViewBuilder var securityRow: some View {
        if BiometricAuth.isAvailable {
            SettingsRow(icon: BiometricAuth.biometricIcon, color: .pastelGreen) {
                Toggle("Require \(BiometricAuth.biometricName)", isOn: $requireBiometricAuth)
            }
        }
    }

    var aboutSection: some View {
        Section {
            SettingsRow(icon: "cloud.fill", color: .blue) {
                Text("Cloude")
                Spacer()
                Text("v1.0")
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://github.com")!) {
                SettingsRow(icon: "questionmark.circle", color: .cyan) {
                    Text("Help & Support")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .listRowBackground(Color.themeSecondary)
    }
}
