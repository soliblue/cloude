import SwiftUI

struct CostBanner: View {
    let currentCost: Double
    let limit: Double
    let onDismiss: () -> Void
    let onNewChat: () -> Void

    private var percentUsed: Double {
        currentCost / limit
    }

    private var bannerColor: Color {
        if percentUsed >= 0.9 {
            return .red
        } else if percentUsed >= 0.75 {
            return .orange
        } else {
            return .yellow
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(bannerColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Context Window Cost Limit")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(String(format: "$%.2f / $%.2f limit", currentCost, limit))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onNewChat) {
                Text("New Chat")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(bannerColor)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(uiColor: .systemGray5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bannerColor.opacity(0.15))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(bannerColor.opacity(0.3)),
            alignment: .bottom
        )
    }
}
