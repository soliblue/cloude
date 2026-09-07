import SwiftData
import SwiftUI

struct SessionEmptyView: View {
    let session: Session
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @Environment(\.theme) private var theme
    @State private var folderSheetEndpoint: Endpoint?
    @State private var historyEndpoint: Endpoint?

    var body: some View {
        ScrollView {
            VStack(spacing: ThemeTokens.Spacing.l) {
                SessionEmptyViewHero()
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
                    Divider()
                    SessionEmptyViewProviderRow(session: session)
                    Divider()
                    SessionEmptyViewModelRow(session: session)
                    Divider()
                    SessionEmptyViewEffortRow(session: session)
                }
                .glassEffect(
                    .regular.tint(theme.palette.background).interactive(),
                    in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l)
                )
                if session.provider == .codex { SessionModelStatusView(session: session) }
                if let endpoint = session.endpoint, endpoint.supportsCodex == true {
                    Button("Open remote Codex chats", systemImage: "clock.arrow.circlepath") {
                        historyEndpoint = endpoint
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(ThemeTokens.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollIndicators(.hidden)
        .dismissesKeyboardOnTap()
        .sheet(item: $folderSheetEndpoint) { endpoint in
            SessionEmptyViewFolderSheet(session: session, endpoint: endpoint).id(session.connectionKey)
        }
        .sheet(item: $historyEndpoint) { endpoint in
            SessionRemoteHistoryView(endpoint: endpoint).id(
                "\(endpoint.id)|\(endpoint.connectionRevision?.uuidString ?? "")")
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
