import SwiftUI
import CloudeShared

extension SettingsView {
    var processesSection: some View {
        Section {
            if connection.processes.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
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
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if connection.processes.count > 1 {
                    Button(action: { connection.killAllProcesses() }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 20))
                            Text("Kill All Processes")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        } header: {
            HStack {
                Text("Claude Processes")
                Spacer()
                Button(action: { connection.getProcesses() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
        } footer: {
            Text("Running Claude Code processes on the Mac agent")
        }
        .listRowBackground(Color.oceanSecondary)
    }

    var tailscaleSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    Text("Tailscale Required")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text("Cloude connects to your Mac agent over Tailscale, a secure mesh VPN. Install Tailscale on both your iPhone and Mac to enable remote access.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Link(destination: URL(string: "https://tailscale.com/download")!) {
                    HStack {
                        Text("Download Tailscale")
                            .font(.subheadline)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Network")
        }
        .listRowBackground(Color.oceanSecondary)
    }

    var securitySection: some View {
        Section {
            if BiometricAuth.isAvailable {
                SettingsRow(icon: BiometricAuth.biometricIcon, color: .green) {
                    Toggle("Require \(BiometricAuth.biometricName)", isOn: $requireBiometricAuth)
                }
            } else {
                SettingsRow(icon: "lock.fill", color: .gray) {
                    Text("Biometric Auth")
                    Spacer()
                    Text("Not Available")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Security")
        }
        .listRowBackground(Color.oceanSecondary)
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
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .listRowBackground(Color.oceanSecondary)
    }
}
