import SwiftData
import SwiftUI

struct SessionEmptyViewEndpointRow: View {
    let session: Session
    @Query(sort: \Endpoint.createdAt) private var endpoints: [Endpoint]
    @Binding var folderSheetEndpoint: Endpoint?
    @Environment(\.theme) private var theme
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented = true
        } label: {
            HStack(spacing: ThemeTokens.Spacing.s) {
                Image(systemName: session.endpoint?.symbolName ?? "laptopcomputer")
                    .appFont(size: ThemeTokens.Text.l)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Endpoint")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                        .foregroundColor(.secondary)
                    Text(label)
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.m)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(endpoints) { endpoint in
                    Button {
                        SessionActions.setEndpoint(endpoint, for: session)
                        folderSheetEndpoint = endpoint
                        isPopoverPresented = false
                    } label: {
                        HStack(spacing: ThemeTokens.Spacing.s) {
                            Image(systemName: endpoint.symbolName)
                                .appFont(size: ThemeTokens.Text.m)
                            Text(endpoint.host.isEmpty ? "Unnamed" : "\(endpoint.host):\(endpoint.port)")
                                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            Spacer(minLength: 0)
                            if session.endpoint?.id == endpoint.id {
                                Image(systemName: "checkmark")
                                    .appFont(size: ThemeTokens.Text.s, weight: .semibold)
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, ThemeTokens.Spacing.m)
                        .padding(.vertical, ThemeTokens.Spacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, ThemeTokens.Spacing.xs)
            .frame(minWidth: 240)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var label: String {
        if let endpoint = session.endpoint, !endpoint.host.isEmpty {
            return "\(endpoint.host):\(endpoint.port)"
        }
        return "Choose endpoint"
    }
}
