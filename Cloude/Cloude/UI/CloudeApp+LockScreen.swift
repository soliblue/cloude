import SwiftUI

struct LockScreenView: View {
    let onUnlock: () -> Void
    @State private var isAuthenticating = false
    @State private var showError = false

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            Image("logo-transparent")
                .resizable()
                .scaledToFit()
                .frame(width: DS.Size.xxl / 2, height: DS.Size.xxl / 2)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l))

            VStack(spacing: DS.Spacing.s) {
                Text("Cloude is Locked")
                    .font(.system(size: DS.Icon.l))
                    .fontWeight(.semibold)

                Text("Authenticate to access your conversations")
                    .font(.system(size: DS.Text.m))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: DS.Spacing.l) {
                Button(action: authenticate) {
                    HStack(spacing: DS.Spacing.m) {
                        if isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: BiometricAuth.biometricIcon)
                        }
                        Text("Unlock with \(BiometricAuth.biometricName)")
                            .font(.system(size: DS.Text.m))
                    }
                    .font(.system(size: DS.Text.m, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.l)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)

                if showError {
                    Text("Authentication failed. Please try again.")
                        .font(.system(size: DS.Text.s))
                        .foregroundColor(.pastelRed)
                }
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .background(Color.themeBackground)
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
