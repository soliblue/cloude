import SwiftData
import SwiftUI

struct SessionEmptyViewEndpointRow: View {
    let session: Session
    @Query(sort: \Endpoint.createdAt) private var endpoints: [Endpoint]
    @Binding var folderSheetEndpoint: Endpoint?

    var body: some View {
        SessionEmptyViewPickerRow(
            icon: session.endpoint?.symbolName ?? "laptopcomputer",
            title: "Endpoint",
            value: label
        ) {
            ForEach(endpoints) { endpoint in
                Button {
                    SessionActions.setEndpoint(endpoint, for: session, clearsPath: true)
                    folderSheetEndpoint = endpoint
                } label: {
                    Label(
                        endpoint.displayName,
                        systemImage: session.endpoint?.id == endpoint.id
                            ? "checkmark" : endpoint.symbolName
                    )
                    if endpoint.name?.isEmpty == false {
                        Text(endpoint.addressLabel)
                    }
                }
            }
        }
    }

    private var label: String {
        if let endpoint = session.endpoint {
            return endpoint.displayName
        }
        return "Choose endpoint"
    }
}
