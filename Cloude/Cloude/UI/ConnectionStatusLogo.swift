import SwiftUI

struct ConnectionStatusLogo: View {
    @ObservedObject var connection: ConnectionManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPulsing = false

    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: 45, height: 45)
            .clipShape(Circle())
            .background {
                Circle()
                    .fill(colorScheme == .dark ? Color.black : Color.clear)
            }
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(
                connection.isAnyRunning
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.3),
                value: isPulsing
            )
            .onChange(of: connection.isAnyRunning) { _, newValue in
                isPulsing = newValue
            }
            .onAppear {
                if connection.isAnyRunning { isPulsing = true }
            }
    }
}
