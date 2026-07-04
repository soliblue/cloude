import SwiftUI
import UIKit

struct OnboardingViewInstallStep: View {
    let store: OnboardingStore
    @Environment(\.theme) private var theme
    @Environment(\.appAccent) private var appAccent
    @Environment(\.openURL) private var openURL
    @State private var isLinux = false
    @State private var installer: InstallerFile?
    @State private var isDownloadingInstaller = false
    @State private var isFetchingLinux = false
    @State private var didCopyCommand = false
    @State private var isDownloadErrorPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            Spacer()
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                Text("Install the daemon")
                    .appFont(size: ThemeTokens.Text.xxl, weight: .semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("To control Claude from your phone, you'll need the companion daemon running on your computer.")
                    .appFont(size: ThemeTokens.Text.xl)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 520, alignment: .leading)
            }
            Picker("Platform", selection: $isLinux) {
                Text("Mac").tag(false)
                Text("Linux").tag(true)
            }
            .pickerStyle(.segmented)
            Image("OnboardingInstallIllustration")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.bottom, -ThemeTokens.Spacing.l)
                .accessibilityHidden(true)
            VStack(spacing: ThemeTokens.Spacing.m) {
                Button(action: primaryAction) {
                    primaryLabel
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ThemeTokens.Spacing.m)
                        .glassEffect(
                            .regular.tint(theme.palette.background).interactive(),
                            in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isDownloadingInstaller || isFetchingLinux)
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
            Text("Try again, or open the latest release in Safari.")
        }
    }

    @ViewBuilder private var primaryLabel: some View {
        let title = isLinux ? (didCopyCommand ? "Copied" : "Copy install command") : "AirDrop Installer"
        let busy = isDownloadingInstaller || isFetchingLinux
        Text(title)
            .appFont(size: ThemeTokens.Text.xl, weight: .semibold)
            .opacity(busy ? 0 : 1)
            .overlay {
                if busy { ProgressView().tint(.primary) }
            }
    }

    private func primaryAction() {
        if isLinux {
            copyLinuxCommand()
        } else {
            airdropMac()
        }
    }

    private func airdropMac() {
        Task {
            isDownloadingInstaller = true
            if let url = await OnboardingInstallService.downloadInstaller() {
                installer = InstallerFile(url: url)
            } else {
                isDownloadErrorPresented = true
            }
            isDownloadingInstaller = false
        }
    }

    private func copyLinuxCommand() {
        Task {
            isFetchingLinux = true
            if let command = await DaemonUpdateService.latestLinuxInstallCommand() {
                UIPasteboard.general.string = command
                didCopyCommand = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    didCopyCommand = false
                }
            } else {
                isDownloadErrorPresented = true
            }
            isFetchingLinux = false
        }
    }
}

private struct InstallerFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
