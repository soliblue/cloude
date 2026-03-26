import SwiftUI

struct ConnectionStatusLogo: View {
    @ObservedObject var connection: ConnectionManager
    @State private var isPulsing = false

    var body: some View {
        Image("logo-transparent")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: DS.Size.badge, height: DS.Size.badge)
            .padding(.horizontal, DS.Spacing.m)
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(
                connection.isAnyRunning
                    ? .easeInOut(duration: DS.Duration.pulse).repeatForever(autoreverses: true)
                    : .easeInOut(duration: DS.Duration.slow),
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
