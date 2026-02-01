import SwiftUI

struct ConnectionStatusLogo: View {
    @ObservedObject var connection: ConnectionManager
    @State private var isPulsing = false

    var body: some View {
        let isAuthenticated = connection.isAuthenticated
        let isConnected = connection.isConnected
        let isAnyRunning = connection.isAnyRunning
        let hasError = connection.lastError != nil && !isConnected

        let shouldDesaturate = !isAuthenticated
        let isConnecting = isConnected && !isAuthenticated
        let shouldPulse = isConnecting || isAnyRunning

        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: 45, height: 45)
            .clipShape(Circle())
            .saturation(shouldDesaturate ? 0 : 1)
            .opacity(isPulsing ? 0.5 : 1.0)
            .overlay {
                if hasError {
                    Circle().fill(Color.red.opacity(0.3))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: isConnected)
            .animation(
                shouldPulse
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .easeInOut(duration: 0.3),
                value: isPulsing
            )
            .onChange(of: shouldPulse) { _, newValue in
                isPulsing = newValue
            }
            .onAppear {
                if shouldPulse { isPulsing = true }
            }
    }
}
