import SwiftUI
import CloudeShared

struct SettingsView: View {
    @ObservedObject var connection: ConnectionManager

    @AppStorage("serverHost") private var serverHost = ""
    @AppStorage("serverPort") private var serverPort = "8765"
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("requireBiometricAuth") var requireBiometricAuth = false
    @AppStorage("defaultCostLimitUsd") private var defaultCostLimitUsd: Double = 0
    @AppStorage("enableSuggestions") private var enableSuggestions = false
    @AppStorage("ttsMode") private var ttsMode: TTSMode = .off
    @AppStorage("kokoroVoice") private var kokoroVoice: KokoroVoice = .af_heart
    @State private var authToken = ""
    @State private var showToken = false
    @State private var ipCopied = false
    @State private var showUsageStats = false
    @State private var usageStats: UsageStats?
    @State private var awaitingUsageStats = false

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
                tailscaleSection
                processesSection
                costLimitsSection
                featuresSection
                ttsSection
                usageSection
                securitySection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.oceanBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.oceanSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
        .onReceive(connection.events) { event in
            if case let .usageStats(stats) = event, awaitingUsageStats {
                awaitingUsageStats = false
                usageStats = stats
                showUsageStats = true
            }
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
        .listRowBackground(Color.oceanSecondary)
    }

    private var costLimitsSection: some View {
        Section {
            SettingsRow(icon: "dollarsign.circle.fill", color: .green) {
                Picker("Default Cost Limit", selection: $defaultCostLimitUsd) {
                    Text("Off").tag(0.0)
                    Text("$1").tag(1.0)
                    Text("$5").tag(5.0)
                    Text("$10").tag(10.0)
                    Text("$25").tag(25.0)
                    Text("$50").tag(50.0)
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("Cost Limits")
        } footer: {
            Text("Default cost warning for new conversations. Per-conversation limits can be set from the chat header.")
        }
        .listRowBackground(Color.oceanSecondary)
    }

    private var featuresSection: some View {
        Section {
            SettingsRow(icon: "text.bubble", color: .indigo) {
                Toggle("Smart Suggestions", isOn: $enableSuggestions)
            }
        } header: {
            Text("Features")
        } footer: {
            Text("Show a suggested reply after each response")
        }
        .listRowBackground(Color.oceanSecondary)
    }

    private var ttsSection: some View {
        Section {
            SettingsRow(icon: ttsMode.icon, color: .purple) {
                Picker("Text to Speech", selection: $ttsMode) {
                    ForEach(TTSMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }

            if ttsMode == .natural {
                SettingsRow(icon: "person.wave.2", color: .indigo) {
                    Picker("Voice", selection: $kokoroVoice) {
                        ForEach(KokoroVoice.allCases, id: \.self) { voice in
                            Text("\(voice.label) (\(voice.accent) \(voice.gender))").tag(voice)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        } header: {
            Text("Text to Speech")
        } footer: {
            Text(ttsMode.description)
        }
        .listRowBackground(Color.oceanSecondary)
    }

    private var usageSection: some View {
        Section {
            Button(action: {
                awaitingUsageStats = true
                connection.getUsageStats()
            }) {
                SettingsRow(icon: "chart.bar.fill", color: .blue) {
                    Text("Usage Statistics")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
        .listRowBackground(Color.oceanSecondary)
        .sheet(isPresented: $showUsageStats) {
            if let stats = usageStats {
                UsageStatsSheet(stats: stats)
            }
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
