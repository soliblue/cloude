import SwiftUI

struct LockScreenView: View {
    let onUnlock: () -> Void
    @State private var isAuthenticating = false
    @State private var showError = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

            VStack(spacing: 8) {
                Text("Cloude is Locked")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Authenticate to access your conversations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 16) {
                Button(action: authenticate) {
                    HStack(spacing: 10) {
                        if isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: BiometricAuth.biometricIcon)
                        }
                        Text("Unlock with \(BiometricAuth.biometricName)")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)

                if showError {
                    Text("Authentication failed. Please try again.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color.oceanBackground)
        .onAppear {
            authenticate()
        }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        showError = false

        Task {
            let success = await BiometricAuth.authenticate()
            await MainActor.run {
                isAuthenticating = false
                if success {
                    onUnlock()
                } else {
                    showError = true
                }
            }
        }
    }
}

#Preview {
    LockScreenView(onUnlock: {})
}
