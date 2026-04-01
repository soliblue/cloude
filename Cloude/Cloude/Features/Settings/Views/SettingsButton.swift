import SwiftUI

struct SettingsButton: View {
    let connection: ConnectionManager
    @State private var isRotating = false

    var body: some View {
        Image(systemName: "gearshape")
            .font(.system(size: DS.Icon.m))
            .foregroundColor(.secondary)
            .frame(width: DS.Size.m, height: DS.Size.m)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                connection.isAnyRunning
                    ? .linear(duration: 5.0).repeatForever(autoreverses: false)
                    : .easeOut(duration: DS.Duration.m),
                value: isRotating
            )
            .onChange(of: connection.isAnyRunning) { _, newValue in
                isRotating = newValue
            }
            .onAppear {
                if connection.isAnyRunning { isRotating = true }
            }
    }
}
