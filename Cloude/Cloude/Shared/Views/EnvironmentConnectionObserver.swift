import SwiftUI

struct EnvironmentConnectionObserver<Content: View>: View {
    @ObservedObject var connection: EnvironmentConnection
    let content: (EnvironmentConnection) -> Content

    var body: some View {
        content(connection)
    }
}
