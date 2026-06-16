import SwiftUI
import UIKit

struct DaemonUpdateView: View {
    @Environment(\.theme) private var theme
    @State private var isFetchingMac = false
    @State private var isFetchingLinux = false
    @State private var shareItems: DaemonUpdateShareItems?
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
                    trailingIcon: "paperplane.fill",
                    trailingTint: .secondary,
                    isLoading: isFetchingMac,
                    action: airdropMac
                )

                sectionHeader("Linux")
                actionRow(
                    icon: "terminal",
                    color: ThemeColor.rust,
                    title: "Copy install command",
                    subtitle: "Paste into your Linux machine's terminal to install.",
                    trailingIcon: copiedAt == nil ? "doc.on.doc" : "checkmark",
                    trailingTint: copiedAt == nil ? .secondary : ThemeColor.success,
                    isLoading: isFetchingLinux,
                    action: copyLinuxCommand
                )
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.m)
        }
        .navigationTitle("Install Daemon")
        .navigationBarTitleDisplayMode(.inline)
        .background(theme.palette.background)
        .themedNavChrome()
        .sheet(item: $shareItems) { shareItems in
            DaemonUpdateShareSheet(items: shareItems.items)
        }
    }

    private func airdropMac() {
        isFetchingMac = true
        Task { @MainActor in
            if let assetURL = await DaemonUpdateService.latestAssetURL(
                tagPrefix: DaemonUpdate.macTagPrefix, assetName: DaemonUpdate.macAssetName),
                let local = await DaemonUpdateService.downloadToTemp(
                    assetURL, suggestedName: DaemonUpdate.macAssetName)
            {
                shareItems = DaemonUpdateShareItems(items: [local])
            }
            isFetchingMac = false
        }
    }

    private func copyLinuxCommand() {
        isFetchingLinux = true
        Task { @MainActor in
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
        icon: String, color: Color, title: String, subtitle: String,
        trailingIcon: String, trailingTint: Color, isLoading: Bool,
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
                Spacer(minLength: ThemeTokens.Spacing.m)
                Image(systemName: trailingIcon)
                    .appFont(size: ThemeTokens.Text.l, weight: .medium)
                    .foregroundStyle(trailingTint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, options: .repeating, isActive: isLoading)
                    .frame(width: ThemeTokens.Size.m, height: ThemeTokens.Size.m)
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
