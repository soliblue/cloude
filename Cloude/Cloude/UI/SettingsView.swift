//
//  SettingsView.swift
//  Cloude
//
//  Connection settings
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var connection: ConnectionManager

    @AppStorage("serverHost") private var serverHost = ""
    @AppStorage("serverPort") private var serverPort = "8765"
    @State private var authToken = ""
    @State private var showToken = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Host (Tailscale IP)", text: $serverHost)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)

                    TextField("Port", text: $serverPort)
                        .keyboardType(.numberPad)
                }

                Section("Authentication") {
                    HStack {
                        if showToken {
                            TextField("Auth Token", text: $authToken)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                        } else {
                            SecureField("Auth Token", text: $authToken)
                        }

                        Button(action: { showToken.toggle() }) {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                        }
                    }

                    Text("Get the token from the Cloude Agent menu bar app on your Mac")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    if connection.isConnected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(connection.isAuthenticated ? "Connected & Authenticated" : "Connected, authenticating...")
                        }

                        Button("Disconnect", role: .destructive) {
                            connection.disconnect()
                        }
                    } else {
                        if let error = connection.lastError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                            }
                        }

                        Button("Connect") {
                            connect()
                        }
                        .disabled(serverHost.isEmpty || authToken.isEmpty)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Load saved token from keychain
            if let saved = KeychainHelper.get(key: "authToken") {
                authToken = saved
            }
        }
        .onChange(of: authToken) { _, newValue in
            // Save token to keychain
            KeychainHelper.save(key: "authToken", value: newValue)
        }
    }

    private func connect() {
        guard let port = UInt16(serverPort) else { return }
        connection.connect(host: serverHost, port: port, token: authToken)
    }
}

// Simple keychain helper for storing auth token
enum KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.cloude.ios"
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data

        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.cloude.ios",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }
}
