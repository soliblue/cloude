//
//  SettingsView.swift
//  Cloude
//
//  Connection settings
//

import SwiftUI
import CloudeShared

struct SettingsView: View {
    @ObservedObject var connection: ConnectionManager

    @AppStorage("serverHost") private var serverHost = ""
    @AppStorage("serverPort") private var serverPort = "8765"
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("requireBiometricAuth") private var requireBiometricAuth = false
    @State private var authToken = ""
    @State private var showToken = false
    @State private var ipCopied = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ConnectionStatusCard(connection: connection, onConnect: connect, onDisconnect: {
                        connection.disconnect()
                    }, canConnect: !serverHost.isEmpty && !authToken.isEmpty)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                connectionSection
                processesSection
                securitySection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onAppear {
            if let saved = KeychainHelper.get(key: "authToken") {
                authToken = saved
            }
            if connection.isAuthenticated {
                connection.getProcesses()
            }
        }
        .onChange(of: authToken) { _, newValue in
            KeychainHelper.save(key: "authToken", value: newValue)
        }
    }

    private var connectionSection: some View {
        Section {
            SettingsRow(icon: "server.rack", color: .blue) {
                TextField("Host", text: $serverHost)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }

            SettingsRow(icon: "number", color: .blue) {
                TextField("Port", text: $serverPort)
                    .keyboardType(.numberPad)
            }

            SettingsRow(icon: "key.fill", color: .orange) {
                Group {
                    if showToken {
                        TextField("Auth Token", text: $authToken)
                            .font(.system(.body, design: .monospaced))
                            .autocapitalization(.none)
                    } else {
                        SecureField("Auth Token", text: $authToken)
                    }
                }

                Button(action: { showToken.toggle() }) {
                    Image(systemName: showToken ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            SettingsRow(icon: appTheme.icon, color: .purple) {
                Picker("Theme", selection: $appTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.menu)
            }

            DeviceIPRow(ipCopied: $ipCopied)
        }
    }

    private var processesSection: some View {
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
    }

    private var securitySection: some View {
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
    }

    private var aboutSection: some View {
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
    }

    private func connect() {
        guard let port = UInt16(serverPort) else { return }
        connection.connect(host: serverHost, port: port, token: authToken)
    }
}

#Preview {
    SettingsView(connection: ConnectionManager())
}
