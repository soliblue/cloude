import SwiftUI

struct ConnectionObserver<Content: View>: View {
    @ObservedObject var connection: Connection
    let content: (Connection) -> Content

    var body: some View {
        content(connection)
    }
}
