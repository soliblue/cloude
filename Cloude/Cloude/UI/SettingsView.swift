import SwiftUI

struct SettingsView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var environmentStore: EnvironmentStore
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.vanGogh.rawValue
    private var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .vanGogh }
    @State private var showThemePicker = false
    @AppStorage("requireBiometricAuth") var requireBiometricAuth = false
    @AppStorage("debugOverlayEnabled") private var debugOverlayEnabled = false
    @AppStorage("wrapCodeLines") private var wrapCodeLines = true
    @AppStorage("showCodeLineNumbers") private var showCodeLineNumbers = true
    @AppStorage("textSizeStep") private var textSizeStep: Int = TextSizeScale.defaultStep
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
            .background(Color.themeBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.themeSecondary, for: .navigationBar)
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
    }

    private var preferencesSection: some View {
        Section {
            Button(action: { showThemePicker = true }) {
                SettingsRow(icon: "paintpalette.fill", color: .purple) {
                    Text("Theme")
                    Spacer()
                    Text(appTheme.rawValue)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            .sheet(isPresented: $showThemePicker) {
                ThemePickerView()
            }

            SettingsRow(icon: "text.word.spacing", color: .cyan) {
                Toggle("Wrap Code Lines", isOn: $wrapCodeLines)
            }

            SettingsRow(icon: "list.number", color: .cyan) {
                Toggle("Code Line Numbers", isOn: $showCodeLineNumbers)
            }

            SettingsRow(icon: "textformat.size", color: .accentColor) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Text Size")
                        Spacer()
                        Text(TextSizeScale.label(for: textSizeStep))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "textformat.size.smaller")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(textSizeStep) },
                                set: { textSizeStep = Int($0.rounded()) }
                            ),
                            in: 0...Double(TextSizeScale.steps.count - 1),
                            step: 1
                        )
                        .tint(.accentColor)
                        Image(systemName: "textformat.size.larger")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            securityRow

            SettingsRow(icon: "ant.fill", color: .orange) {
                Toggle("Debug Overlay", isOn: $debugOverlayEnabled)
            }
        }
        .listRowBackground(Color.themeSecondary)
    }

}

#Preview {
    SettingsView(connection: ConnectionManager(), environmentStore: EnvironmentStore())
}
