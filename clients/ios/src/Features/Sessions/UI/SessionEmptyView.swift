import SwiftData
import SwiftUI

struct SessionEmptyView: View {
    let session: Session
    @Environment(\.theme) private var theme
    @Query(sort: \Endpoint.createdAt) private var endpoints: [Endpoint]
    @State private var pickerEndpoint: Endpoint?

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
            Text("Choose an environment")
                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(endpoints) { endpoint in
                Button {
                    pickerEndpoint = endpoint
                } label: {
                    HStack(spacing: ThemeTokens.Spacing.s) {
                        Image(systemName: endpoint.symbolName)
                            .appFont(size: ThemeTokens.Icon.m)
                        Text(endpoint.host.isEmpty ? "Unnamed" : endpoint.host)
                            .appFont(size: ThemeTokens.Text.m)
                        Spacer()
                    }
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    .padding(.vertical, ThemeTokens.Spacing.s)
                    .background(theme.palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ThemeTokens.Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .sheet(item: $pickerEndpoint) { endpoint in
            SessionEmptyViewFolderSheet(session: session, endpoint: endpoint)
        }
    }
}
