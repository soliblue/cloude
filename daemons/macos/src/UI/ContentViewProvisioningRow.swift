import SwiftUI

struct ContentViewProvisioningRow: View {
    let state: RemoteTunnelStepState

    var body: some View {
        HStack(spacing: 8) {
            icon
                .frame(width: 14, height: 14)
            Text(state.step.title)
                .font(.caption)
                .foregroundStyle(state.status == .waiting ? .secondary : .primary)
            Spacer()
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch state.status {
        case .waiting:
            Circle()
                .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                .frame(width: 10, height: 10)
        case .active:
            ProgressView()
                .controlSize(.mini)
                .frame(width: 14, height: 14)
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.red)
        }
    }
}
