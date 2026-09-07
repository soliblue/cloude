import SwiftUI
import UIKit

struct DaemonUpdateView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var iconFrame = ThemeTokens.Size.m
    @State private var isFetchingMac = false
    @State private var isFetchingLinux = false
    @State private var shareItems: [Any]?
    @State private var copiedAt: Date?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                sectionHeader("Linux")
                actionRow(
                    icon: "terminal",
                    color: ThemeColor.rust,
                    title: "Copy install command",
                    subtitle: "Run as your normal Linux user with sudo access.",
                    trailingIcon: copiedAt == nil ? "doc.on.doc" : "checkmark",
                    trailingTint: copiedAt == nil ? ThemeColor.secondary : ThemeColor.success,
                    isLoading: isFetchingLinux,
                    action: copyLinuxCommand
                )

                sectionHeader("Mac")
                actionRow(
                    icon: "laptopcomputer",
                    color: ThemeColor.purple,
                    title: "Get Mac installer",
                    subtitle: "Downloads the latest .dmg, then sends it via AirDrop.",
                    trailingIcon: "paperplane.fill",
                    trailingTint: ThemeColor.secondary,
                    isLoading: isFetchingMac,
                    action: airdropMac
                )
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.m)
        }
        .navigationTitle("Install Daemon")
        .navigationBarTitleDisplayMode(.inline)
        .background(theme.palette.background)
        .themedNavChrome()
        .sheet(item: Binding(get: { shareItems.map { ShareItemsBox(items: $0) } }, set: { shareItems = $0?.items })) {
            box in
            DaemonUpdateShareSheet(items: box.items)
        }
        .alert(
            "Download failed",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func airdropMac() {
        isFetchingMac = true
        Task { @MainActor in
            if let assetURL = await DaemonUpdateService.latestAsset(
                tagPrefix: DaemonUpdate.macTagPrefix, assetName: DaemonUpdate.macAssetName),
                let local = await DaemonUpdateService.downloadToTemp(
                    assetURL, suggestedName: DaemonUpdate.macAssetName)
            {
                shareItems = [local]
            } else {
                errorMessage = "Could not fetch the latest Mac daemon release."
            }
            isFetchingMac = false
        }
    }

    private func copyLinuxCommand() {
        isFetchingLinux = true
        Task { @MainActor in
            if let command = await DaemonUpdateService.latestLinuxInstallCommand() {
                UIPasteboard.general.string = command
                copiedAt = .now
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    copiedAt = nil
                }
            } else {
                errorMessage = "Could not fetch the latest Linux daemon release."
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
                    .frame(width: iconFrame)
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(title)
                        .appFont(size: ThemeTokens.Text.l, weight: .medium)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .appFont(size: ThemeTokens.Text.s)
                        .foregroundColor(ThemeColor.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: ThemeTokens.Spacing.m)
                Image(systemName: trailingIcon)
                    .appFont(size: ThemeTokens.Text.l, weight: .medium)
                    .foregroundStyle(trailingTint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, options: .repeating, isActive: isLoading && !reduceMotion)
                    .frame(width: iconFrame, height: iconFrame)
            }
            .padding(.vertical, ThemeTokens.Spacing.m)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .appFont(size: ThemeTokens.Text.s, weight: .medium)
            .foregroundColor(ThemeColor.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ShareItemsBox: Identifiable {
    let id = UUID()
    let items: [Any]
}
