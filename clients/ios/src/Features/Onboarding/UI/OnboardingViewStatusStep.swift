import SwiftData
import SwiftUI

struct OnboardingViewStatusStep: View {
    let store: OnboardingStore
    let onFinished: (Endpoint) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.appAccent) private var appAccent
    @Environment(\.modelContext) private var context
    @State private var savedEndpoint: Endpoint?

    private struct Copy {
        let symbol: String
        let tint: Color
        let title: String
        let subtitle: String
    }

    private var copy: Copy {
        switch store.probeResult {
        case .reachable:
            return Copy(
                symbol: "",
                tint: ThemeColor.success,
                title: "You're all set",
                subtitle: "Hope you enjoy it. Anything broken or weird, reach out [@_xsoli](https://x.com/_xsoli)."
            )
        case .unauthorized:
            return Copy(
                symbol: "lock.trianglebadge.exclamationmark.fill",
                tint: ThemeColor.danger,
                title: "Token rejected",
                subtitle: "Generate a new QR in Remote CC Daemon and try again."
            )
        case .unreachable:
            return Copy(
                symbol: "wifi.exclamationmark",
                tint: ThemeColor.orange,
                title: "Can't reach your Mac",
                subtitle: "Make sure your phone and Mac are on the same Wi-Fi."
            )
        case .invalid:
            return Copy(
                symbol: "exclamationmark.triangle.fill",
                tint: ThemeColor.danger,
                title: "Unexpected response",
                subtitle: "The host responded, but not like the daemon does."
            )
        case .none:
            return Copy(
                symbol: "dot.radiowaves.left.and.right",
                tint: .primary,
                title: "Checking connection",
                subtitle: "Running an authenticated ping against your Mac."
            )
        }
    }

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.l) {
            VStack(spacing: ThemeTokens.Spacing.s) {
                Text(copy.title)
                    .appFont(size: ThemeTokens.Text.xxl, weight: .semibold)
                    .multilineTextAlignment(.center)
                Text(.init(copy.subtitle))
                    .appFont(size: ThemeTokens.Text.xl)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .tint(appAccent.color)
                    .frame(maxWidth: 520)
            }
            hero
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let savedEndpoint {
                Button {
                    onFinished(savedEndpoint)
                } label: {
                    Text("Enjoy")
                        .appFont(size: ThemeTokens.Text.xl, weight: .semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ThemeTokens.Spacing.m)
                        .glassEffect(
                            .regular.tint(theme.palette.background).interactive(),
                            in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l)
                        )
                }
                .buttonStyle(.plain)
            } else if let result = store.probeResult, result != .reachable {
                Button {
                    store.reset()
                } label: {
                    Text("Try again")
                        .appFont(size: ThemeTokens.Text.xl, weight: .semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ThemeTokens.Spacing.m)
                        .glassEffect(
                            .regular.tint(theme.palette.background).interactive(),
                            in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ThemeTokens.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.palette.background.ignoresSafeArea())
        .task(id: store.draft) {
            if store.draft != nil, store.probeResult == nil {
                if let endpoint = await store.verifyAndSave(context: context) {
                    savedEndpoint = endpoint
                }
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        if store.isProbing {
            ProgressView().controlSize(.large)
        } else if store.probeResult == .reachable {
            Image("claude-painter")
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: copy.symbol)
                .appFont(size: ThemeTokens.Size.l)
                .foregroundColor(copy.tint)
                .contentTransition(.symbolEffect(.replace))
        }
    }
}
