import SwiftData
import SwiftUI

struct SessionEmptyView: View {
    let session: Session
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @Environment(\.theme) private var theme
    @State private var folderSheetEndpoint: Endpoint?

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.l) {
            Spacer(minLength: 0)
            SessionEmptyViewHero()
                .frame(maxHeight: ThemeTokens.Size.xl)
                .padding(.bottom, ThemeTokens.Spacing.l)
            VStack(spacing: 0) {
                SessionEmptyViewEndpointRow(
                    session: session,
                    folderSheetEndpoint: $folderSheetEndpoint
                )
                Divider()
                SessionEmptyViewFolderRow(
                    session: session,
                    folderSheetEndpoint: $folderSheetEndpoint
                )
                SessionEmptyViewRecentList(currentSession: session)
            }
            .glassEffect(
                .regular.tint(theme.palette.background).interactive(),
                in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l)
            )
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(ThemeTokens.Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $folderSheetEndpoint) { endpoint in
            SessionEmptyViewFolderSheet(session: session, endpoint: endpoint)
        }
        .onAppear {
            handle(folderPickerRequest)
        }
        .onChange(of: folderPickerRequest) { _, request in
            handle(request)
        }
    }

    private func handle(_ request: SessionFolderPickerRequest?) {
        if let request,
            request.sessionId == session.id,
            let endpoint = session.endpoint,
            endpoint.id == request.endpointId
        {
            folderSheetEndpoint = endpoint
            folderPickerRequest = nil
        }
    }
}
