import SwiftUI
import UIKit

struct DaemonUpdateView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var isFetchingMac = false
    @State private var isFetchingLinux = false
    @State private var shareItems: [Any]?
    @State private var copiedAt: Date?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                sectionHeader("Mac")
                actionRow(
                    icon: "laptopcomputer",
                    color: ThemeColor.purple,
                    title: "AirDrop Mac daemon",
                    subtitle: "Downloads the latest .dmg, then sends it via AirDrop.",
                    isLoading: isFetchingMac,
                    action: airdropMac
                )

                sectionHeader("Linux")
                actionRow(
                    icon: "terminal",
                    color: ThemeColor.rust,
                    title: copiedAt == nil ? "Copy install command" : "Copied",
                    subtitle: "Paste into your Linux machine's terminal to install.",
                    isLoading: isFetchingLinux,
                    action: copyLinuxCommand
                )
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.m)
        }
        .navigationTitle("Install Daemon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .background(theme.palette.background)
        .themedNavChrome()
        .sheet(item: Binding(get: { shareItems.map { ShareItemsBox(items: $0) } }, set: { shareItems = $0?.items })) {
            box in
            DaemonUpdateShareSheet(items: box.items)
        }
    }

    private func airdropMac() {
        isFetchingMac = true
        Task {
            if let assetURL = await DaemonUpdateService.latestAssetURL(
                tagPrefix: DaemonUpdate.macTagPrefix, assetName: DaemonUpdate.macAssetName),
                let local = await DaemonUpdateService.downloadToTemp(
                    assetURL, suggestedName: DaemonUpdate.macAssetName)
            {
                shareItems = [local]
            }
            isFetchingMac = false
        }
    }

    private func copyLinuxCommand() {
        isFetchingLinux = true
        Task {
            if let assetURL = await DaemonUpdateService.latestAssetURL(
                tagPrefix: DaemonUpdate.linuxTagPrefix, assetName: DaemonUpdate.linuxAssetName)
            {
                UIPasteboard.general.string = DaemonUpdateService.linuxInstallCommand(downloadURL: assetURL)
                copiedAt = .now
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    copiedAt = nil
                }
            }
            isFetchingLinux = false
        }
    }

    private func actionRow(
        icon: String, color: Color, title: String, subtitle: String, isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: ThemeTokens.Spacing.m) {
                Image(systemName: icon)
                    .appFont(size: ThemeTokens.Text.l, weight: .medium)
                    .foregroundColor(color)
                    .frame(width: ThemeTokens.Size.m)
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(title)
                        .appFont(size: ThemeTokens.Text.l, weight: .medium)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .appFont(size: ThemeTokens.Text.s)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if isLoading {
                    ProgressView()
                }
            }
            .padding(.vertical, ThemeTokens.Spacing.m)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .appFont(size: ThemeTokens.Text.s, weight: .medium)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}

private struct ShareItemsBox: Identifiable {
    let id = UUID()
    let items: [Any]
}
