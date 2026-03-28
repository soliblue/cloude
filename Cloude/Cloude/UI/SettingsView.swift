import SwiftUI

struct SettingsView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var environmentStore: EnvironmentStore
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.majorelle.rawValue
    private var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .majorelle }
    @State private var showThemePicker = false
    @AppStorage("debugOverlayEnabled") private var debugOverlayEnabled = false
    @AppStorage("wrapCodeLines") private var wrapCodeLines = true
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.themeSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .medium))
                    }
                    .agenticID("settings_close_button")
                }
            }
        }
        .agenticID("settings_view")
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
                        .font(.system(size: DS.Text.m))
                    Spacer()
                    Text(appTheme.rawValue)
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                }
            }
            .agenticID("settings_theme_button")
            .foregroundColor(.primary)
            .sheet(isPresented: $showThemePicker) {
                ThemePickerView()
            }

            SettingsRow(icon: "text.word.spacing", color: .cyan) {
                Toggle("Wrap Code Lines", isOn: $wrapCodeLines)
                    .font(.system(size: DS.Text.m))
                    .controlSize(.regular)
            }


            SettingsRow(icon: "ant.fill", color: .orange) {
                Toggle("Debug Overlay", isOn: $debugOverlayEnabled)
                    .font(.system(size: DS.Text.m))
                    .controlSize(.regular)
            }
        }
        .listRowBackground(Color.themeSecondary)
    }

}

#Preview {
    SettingsView(connection: ConnectionManager(), environmentStore: EnvironmentStore())
}
