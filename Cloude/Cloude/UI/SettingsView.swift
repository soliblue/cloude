//
//  SettingsView.swift
//  Cloude
//
//  Connection settings
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var paneManager: PaneManager

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
                displaySection
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

    private var displaySection: some View {
        Section {
            SettingsRow(icon: "rectangle.expand.vertical", color: .indigo) {
                Toggle("Focus Mode", isOn: $paneManager.focusModeEnabled)
            }
        } header: {
            Text("Display")
        } footer: {
            Text("Active conversation expands to fill more space when multiple panes are open")
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
                        .font(.caption)
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
    SettingsView(connection: ConnectionManager(), paneManager: PaneManager())
}
