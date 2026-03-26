import SwiftUI
import CloudeShared

extension SettingsView {
    var processesSection: some View {
        Section {
            if connection.processes.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: DS.Icon.m))
                        .foregroundColor(.pastelGreen)
                    Text("No Claude processes running")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(connection.processes) { proc in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let name = proc.conversationName {
                                Text(name)
                                    .font(.system(size: DS.Text.m, weight: .medium))
                            } else {
                                Text("PID \(proc.pid)")
                                    .font(.system(size: DS.Text.m, design: .monospaced))
                            }
                            HStack(spacing: 8) {
                                if proc.conversationName != nil {
                                    Text("PID \(proc.pid)")
                                        .font(.system(size: DS.Text.s))
                                        .foregroundColor(.secondary)
                                }
                                if let start = proc.startTime {
                                    Text(start, style: .relative)
                                        .font(.system(size: DS.Text.s))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Button(action: { connection.killProcess(pid: proc.pid) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: DS.Icon.m))
                        }
                        .buttonStyle(.plain)
                        .tint(.accentColor)
                    }
                }

                if connection.processes.count > 1 {
                    Button(action: { connection.killAllProcesses() }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: DS.Icon.m))
                            Text("Kill All Processes")
                                .font(.system(size: DS.Text.m))
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }
            }
        } header: {
            HStack {
                Text("Claude Processes")
                    .font(.system(size: DS.Text.s))
                Spacer()
                Button(action: { connection.getProcesses() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: DS.Text.s))
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("Running Claude Code processes on the Mac agent")
                .font(.system(size: DS.Text.s))
        }
        .listRowBackground(Color.themeSecondary)
    }

    @ViewBuilder var securityRow: some View {
        if BiometricAuth.isAvailable {
            SettingsRow(icon: BiometricAuth.biometricIcon, color: .pastelGreen) {
                Toggle("Require \(BiometricAuth.biometricName)", isOn: $requireBiometricAuth)
                    .font(.system(size: DS.Text.m))
            }
        }
    }

    var aboutSection: some View {
        Section {
            SettingsRow(icon: "cloud.fill", color: .blue) {
                Text("Cloude")
                    .font(.system(size: DS.Text.m))
                Spacer()
                Text("v1.0")
                    .font(.system(size: DS.Text.s))
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://x.com/_xsoli")!) {
                SettingsRow(icon: "questionmark.circle", color: .cyan) {
                    Text("Help & Support")
                        .font(.system(size: DS.Text.m))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .listRowBackground(Color.themeSecondary)
    }
}
