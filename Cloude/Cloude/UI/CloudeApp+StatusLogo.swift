import SwiftUI

struct ConnectionStatusLogo: View {
    @ObservedObject var connection: ConnectionManager
    @State private var isPulsing = false

    var body: some View {
        Image("logo-transparent")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: DS.Size.l, height: DS.Size.l)
            .padding(.horizontal, DS.Spacing.m)
            .opacity(isPulsing ? DS.Opacity.m : 1.0)
            .animation(
                connection.isAnyRunning
                    ? .easeInOut(duration: DS.Duration.l).repeatForever(autoreverses: true)
                    : .easeInOut(duration: DS.Duration.m),
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
