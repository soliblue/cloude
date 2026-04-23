import SwiftUI

struct ContentView: View {
    @AppStorage(SleepPreventionService.defaultsKey) private var preventsIdleSystemSleep = false

    @StateObject private var provisioner = RemoteTunnelProvisioner.shared

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
                        Text(statusText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ContentViewCopyRow(label: "HOST", value: displayedHost)

            ContentViewCopyRow(label: "AUTH TOKEN", value: DaemonAuth.token)

            ContentViewProvisioningList(steps: provisioner.steps, message: provisioner.errorMessage)

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

            Toggle(isOn: $preventsIdleSystemSleep) {
                Label("Keep Mac Awake", systemImage: "moon.zzz")
            }
            .toggleStyle(.switch)
            .onChange(of: preventsIdleSystemSleep) { enabled in
                let assertionIsActive = SleepPreventionService.shared.setEnabled(enabled)
                if assertionIsActive != enabled {
                    preventsIdleSystemSleep = assertionIsActive
                }
            }

            ContentViewFolderAccessButton()

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

    private var displayedHost: String {
        provisioner.endpoint?.host ?? DaemonHost.localIPv4 ?? "provisioning"
    }

    private var statusText: String {
        provisioner.endpoint == nil ? "port \(HTTPServer.port)" : "remote 443"
    }

    private var pairingURL: URL? {
        if let endpoint = provisioner.endpoint {
            return DaemonPairingURL.current(endpoint: endpoint)
        }
        return nil
    }

}
