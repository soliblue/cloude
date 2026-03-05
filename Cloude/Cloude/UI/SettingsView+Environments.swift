import SwiftUI

extension SettingsView {
    var environmentsCarousel: some View {
        Section {
            TabView(selection: $selectedEnvironmentPage) {
                ForEach(environmentStore.environments) { env in
                    EnvironmentCard(
                        env: env,
                        isActive: env.id == environmentStore.activeEnvironmentId,
                        isConnected: env.id == environmentStore.activeEnvironmentId && connection.isAuthenticated,
                        isConnecting: env.id == environmentStore.activeEnvironmentId && connection.isConnected && !connection.isAuthenticated,
                        onConnect: { connectEnvironment(env) },
                        onDisconnect: { connection.disconnect() },
                        onUpdate: { environmentStore.update($0); syncIfActive($0) },
                        onDelete: environmentStore.environments.count > 1 ? { environmentStore.delete(env.id) } : nil
                    )
                    .tag(env.id)
                }

                AddEnvironmentCard(unusedCharacters: environmentStore.unusedCharacters()) { env in
                    environmentStore.add(env)
                    selectedEnvironmentPage = env.id
                }
                .tag("add" as AnyHashable)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 260)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    private func connectEnvironment(_ env: ServerEnvironment) {
        environmentStore.setActive(env.id)
        connection.connect(host: env.host, port: env.port, token: env.token)
    }

    private func syncIfActive(_ env: ServerEnvironment) {
        if env.id == environmentStore.activeEnvironmentId {
            connection.connect(host: env.host, port: env.port, token: env.token)
        }
    }
}

struct EnvironmentCard: View {
    @State var env: ServerEnvironment
    let isActive: Bool
    let isConnected: Bool
    let isConnecting: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onUpdate: (ServerEnvironment) -> Void
    let onDelete: (() -> Void)?

    @State private var showToken = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                if let onDelete {
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Delete \(env.name)?", isPresented: $showDeleteConfirm) {
                        Button("Delete", role: .destructive, action: onDelete)
                    }
                }

                Spacer()

                Image(env.character)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 50)

                Spacer()

                Color.clear.frame(width: 13, height: 13)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    TextField("Host", text: $env.host)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .font(.system(.subheadline))
                        .onChange(of: env.host) { _, _ in onUpdate(env) }

                    Text(":")
                        .foregroundColor(.secondary)

                    TextField("Port", text: portBinding)
                        .keyboardType(.numberPad)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(width: 50)
                        .onChange(of: env.port) { _, _ in onUpdate(env) }
                }

                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .frame(width: 20)

                    Group {
                        if showToken {
                            TextField("Auth Token", text: $env.token)
                                .font(.system(.subheadline, design: .monospaced))
                        } else {
                            SecureField("Auth Token", text: $env.token)
                                .font(.system(.subheadline))
                        }
                    }
                    .autocapitalization(.none)
                    .onChange(of: env.token) { _, _ in onUpdate(env) }

                    Button(action: { showToken.toggle() }) {
                        Image(systemName: showToken ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isConnected {
                    Button("Disconnect", action: onDisconnect)
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.small)
                } else {
                    Button("Connect", action: onConnect)
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(env.host.isEmpty || env.token.isEmpty)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.oceanSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private var statusColor: Color {
        if isConnected { return .green }
        if isConnecting { return .yellow }
        return .gray
    }

    private var statusText: String {
        if isConnected { return "Connected" }
        if isConnecting { return "Connecting..." }
        return "Not connected"
    }

    private var portBinding: Binding<String> {
        Binding(
            get: { String(env.port) },
            set: { env.port = UInt16($0) ?? 8765 }
        )
    }
}

struct AddEnvironmentCard: View {
    let unusedCharacters: [String]
    let onAdd: (ServerEnvironment) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("Add Environment")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Add") {
                let character = unusedCharacters.first ?? ServerEnvironment.availableCharacters[0]
                onAdd(ServerEnvironment(name: "New", host: "", port: 8765, token: "", character: character))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.oceanSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}
