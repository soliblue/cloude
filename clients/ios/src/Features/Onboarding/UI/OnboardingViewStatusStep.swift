import SwiftData
import SwiftUI

struct OnboardingViewStatusStep: View {
    let store: OnboardingStore
    let onFinished: (Endpoint) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.appAccent) private var appAccent
    @Environment(\.modelContext) private var context
    @State private var savedEndpoint: Endpoint?
    @State private var isSaving = false

    private enum StepState {
        case pending
        case active
        case done
        case failed
    }

    private var connectState: StepState {
        if store.isProbing { return .active }
        if let result = store.probeResult {
            return result == .reachable ? .done : .failed
        }
        return .pending
    }

    private var saveState: StepState {
        if savedEndpoint != nil { return .done }
        if isSaving { return .active }
        return .pending
    }

    private var hostLabel: String {
        store.draft?.name ?? store.draft?.host ?? "your Mac"
    }

    private var connectSubtitle: String? {
        switch store.probeResult {
        case .unauthorized: return "Token rejected. Generate a new QR and try again."
        case .unreachable: return "Make sure your phone and Mac are on the same Wi-Fi."
        case .invalid: return "The host responded, but not like the daemon does."
        case .reachable, .none: return nil
        }
    }

    private var hasError: Bool {
        store.probeResult != nil && store.probeResult != .reachable
    }

    private var isButtonEnabled: Bool {
        savedEndpoint != nil || hasError
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            Spacer()
            VStack(spacing: 0) {
                stepRow(
                    title: Text("Connecting to")
                        + Text(" \(hostLabel)").font(
                            .system(size: ThemeTokens.Text.l, design: .monospaced).weight(.medium)),
                    subtitle: connectSubtitle,
                    state: connectState
                )
                Divider()
                    .padding(.leading, ThemeTokens.Size.m + ThemeTokens.Spacing.m * 2)
                stepRow(
                    title: Text("Storing token in")
                        + Text(" Keychain").font(.system(size: ThemeTokens.Text.l, design: .monospaced).weight(.medium)),
                    subtitle: nil,
                    state: saveState
                )
            }
            .padding(ThemeTokens.Spacing.s)
            .frame(maxWidth: .infinity)
            .glassEffect(
                .regular.tint(theme.palette.surface),
                in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l)
            )
            Button {
                if hasError {
                    store.reset()
                } else if let savedEndpoint {
                    onFinished(savedEndpoint)
                }
            } label: {
                Text(hasError ? "Try again" : "Continue")
                    .appFont(size: ThemeTokens.Text.xl, weight: .semibold)
                    .foregroundColor(appAccent.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ThemeTokens.Spacing.m)
                    .contentTransition(.opacity)
            }
            .buttonStyle(.plain)
            .disabled(!isButtonEnabled)
            .opacity(isButtonEnabled ? 1 : ThemeTokens.Opacity.m)
            Spacer()
        }
        .padding(ThemeTokens.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.background.ignoresSafeArea())
        .task(id: store.draft) {
            if store.draft != nil, store.probeResult == nil {
                if let endpoint = await store.verifyAndSave(context: context) {
                    withAnimation(.easeOut(duration: ThemeTokens.Duration.s)) { isSaving = true }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    withAnimation(.easeOut(duration: ThemeTokens.Duration.s)) {
                        savedEndpoint = endpoint
                        isSaving = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func stepRow(title: Text, subtitle: String?, state: StepState) -> some View {
        HStack(alignment: .top, spacing: ThemeTokens.Spacing.m) {
            stepIcon(state)
                .frame(width: ThemeTokens.Size.m, height: ThemeTokens.Size.m)
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                title
                    .appFont(size: ThemeTokens.Text.l, weight: .medium)
                    .foregroundColor(state == .pending ? .secondary : .primary)
                if let subtitle {
                    Text(subtitle)
                        .appFont(size: ThemeTokens.Text.m)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, ThemeTokens.Spacing.s)
        .padding(.horizontal, ThemeTokens.Spacing.m)
    }

    @ViewBuilder
    private func stepIcon(_ state: StepState) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle")
                .appFont(size: ThemeTokens.Text.l)
                .foregroundColor(.secondary.opacity(ThemeTokens.Opacity.m))
        case .active:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .appFont(size: ThemeTokens.Text.l)
                .foregroundColor(ThemeColor.success)
                .contentTransition(.symbolEffect(.replace))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .appFont(size: ThemeTokens.Text.l)
                .foregroundColor(ThemeColor.danger)
                .contentTransition(.symbolEffect(.replace))
        }
    }
}
