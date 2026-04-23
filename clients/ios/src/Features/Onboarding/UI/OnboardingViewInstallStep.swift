import SwiftUI

struct OnboardingViewInstallStep: View {
    let store: OnboardingStore
    @Environment(\.theme) private var theme
    @Environment(\.appAccent) private var appAccent
    @Environment(\.openURL) private var openURL
    @State private var installer: InstallerFile?
    @State private var isDownloadingInstaller = false
    @State private var isDownloadErrorPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            Spacer()
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                Text("Install on your Mac")
                    .appFont(size: ThemeTokens.Text.xxl, weight: .semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("To control Claude from your phone, you'll need our little Mac companion.")
                    .appFont(size: ThemeTokens.Text.xl)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 520, alignment: .leading)
            }
            Image("OnboardingInstallIllustration")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.bottom, -ThemeTokens.Spacing.l)
                .accessibilityHidden(true)
            VStack(spacing: ThemeTokens.Spacing.m) {
                Button {
                    Task {
                        isDownloadingInstaller = true
                        if let url = await OnboardingInstallService.downloadInstaller() {
                            installer = InstallerFile(url: url)
                        } else {
                            isDownloadErrorPresented = true
                        }
                        isDownloadingInstaller = false
                    }
                } label: {
                    Text("AirDrop Installer")
                        .appFont(size: ThemeTokens.Text.xl, weight: .semibold)
                        .opacity(isDownloadingInstaller ? 0 : 1)
                        .overlay {
                            if isDownloadingInstaller {
                                ProgressView()
                                    .tint(.primary)
                            }
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ThemeTokens.Spacing.m)
                        .glassEffect(
                            .regular.tint(theme.palette.background).interactive(),
                            in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isDownloadingInstaller)
                Button {
                    store.step = .pair
                } label: {
                    Text("Continue")
                        .appFont(size: ThemeTokens.Text.l, weight: .semibold)
                        .foregroundColor(appAccent.color)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ThemeTokens.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.palette.background.ignoresSafeArea())
        .sheet(item: $installer) { file in
            OnboardingViewInstallStepShareSheet(items: [file.url])
        }
        .alert("Couldn't prepare the installer", isPresented: $isDownloadErrorPresented) {
            Button("Open in Safari") {
                openURL(OnboardingInstallService.releasePageURL)
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try again, or open the latest release in Safari and AirDrop it from there.")
        }
    }
}

private struct InstallerFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
