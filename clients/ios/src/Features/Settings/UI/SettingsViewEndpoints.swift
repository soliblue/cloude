import SwiftData
import SwiftUI

struct SettingsViewEndpoints: View {
    @Query(sort: \Endpoint.createdAt) private var endpoints: [Endpoint]

    var body: some View {
        NavigationLink {
            EndpointsListView()
        } label: {
            SettingsRow(icon: "server.rack", color: ThemeColor.rust) {
                Text("Endpoints")
                Spacer()
                Text("\(endpoints.count)")
                    .foregroundColor(ThemeColor.secondary)
            }
        }
        .foregroundColor(.primary)
    }
}
