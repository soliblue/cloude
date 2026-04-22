import SwiftUI

struct ContentView: View {
    @State private var isTokenCopied = false
    @State private var isHostCopied = false

    private let pairingURL = DaemonPairingURL.current()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image("logo-transparent")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(DaemonHost.computerName)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("port \(HTTPServer.port)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ContentViewCopyRow(
                label: "HOST",
                value: DaemonHost.localIPv4 ?? "unavailable",
                isCopied: isHostCopied
            ) {
                if let host = DaemonHost.localIPv4 {
                    copy(host, flag: $isHostCopied)
                }
            }

            ContentViewCopyRow(
                label: "AUTH TOKEN",
                value: DaemonAuth.token,
                isCopied: isTokenCopied
            ) {
                copy(DaemonAuth.token, flag: $isTokenCopied)
            }

            if let url = pairingURL,
                let image = DaemonQR.image(from: url.absoluteString)
            {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .padding(8)
                    .frame(maxWidth: .infinity)
            }

            Divider()

            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private func copy(_ value: String, flag: Binding<Bool>) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { flag.wrappedValue = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { flag.wrappedValue = false }
        }
    }
}
