import SwiftUI
import CloudeShared

struct SettingsView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var environmentStore: EnvironmentStore
    var onShowMemories: (() -> Void)?
    var onShowPlans: (() -> Void)?

    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.oceanDark.rawValue
    private var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .oceanDark }
    @State private var showThemePicker = false
    @AppStorage("requireBiometricAuth") var requireBiometricAuth = false
    @AppStorage("enableSuggestions") private var enableSuggestions = false
    @AppStorage("wrapCodeLines") private var wrapCodeLines = true
    @AppStorage("showCodeLineNumbers") private var showCodeLineNumbers = true
    @State private var showUsageStats = false
    @State private var usageStats: UsageStats?
    @State private var awaitingUsageStats = false
    @State var selectedEnvironmentPage: Int = 0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                environmentsCarousel
                    .listSectionSeparator(.hidden)
                processesSection
                preferencesSection
                aboutSection
            }
            .contentMargins(.top, 8, for: .scrollContent)
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
        .preferredColorScheme(appTheme.colorScheme)
        .onAppear {
            if let activeId = environmentStore.activeEnvironmentId,
               let index = environmentStore.environments.firstIndex(where: { $0.id == activeId }) {
                selectedEnvironmentPage = index
            }
            if connection.isAuthenticated {
                connection.getProcesses()
            }
        }
        .onReceive(connection.events) { event in
            if case let .usageStats(stats) = event, awaitingUsageStats {
                awaitingUsageStats = false
                usageStats = stats
                showUsageStats = true
            }
        }
    }

    private var preferencesSection: some View {
        Section {
            Button(action: { showThemePicker = true }) {
                SettingsRow(icon: appTheme.icon, color: .purple) {
                    Text("Theme")
                    Spacer()
                    Text(appTheme.rawValue)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            .sheet(isPresented: $showThemePicker) {
                ThemePickerView()
            }

            SettingsRow(icon: "text.bubble", color: .indigo) {
                Toggle("Smart Suggestions", isOn: $enableSuggestions)
            }

            SettingsRow(icon: "text.word.spacing", color: .cyan) {
                Toggle("Wrap Code Lines", isOn: $wrapCodeLines)
            }

            SettingsRow(icon: "list.number", color: .cyan) {
                Toggle("Code Line Numbers", isOn: $showCodeLineNumbers)
            }

            securityRow

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

            Button(action: {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onShowMemories?() }
            }) {
                SettingsRow(icon: "brain", color: .pink) {
                    Text("Memories")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)

            Button(action: {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onShowPlans?() }
            }) {
                SettingsRow(icon: "list.bullet.clipboard", color: .green) {
                    Text("Plans")
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

}

#Preview {
    SettingsView(connection: ConnectionManager(), environmentStore: EnvironmentStore())
}
