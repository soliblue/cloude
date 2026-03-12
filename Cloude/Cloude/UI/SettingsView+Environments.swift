import SwiftUI

extension SettingsView {
    var environmentsCarousel: some View {
        Section {
            TabView(selection: $selectedEnvironmentPage) {
                ForEach(Array(environmentStore.environments.enumerated()), id: \.element.id) { index, env in
                    EnvironmentCard(
                        env: env,
                        isActive: env.id == environmentStore.activeEnvironmentId,
                        isConnected: connection.connection(for: env.id)?.isAuthenticated ?? false,
                        isConnecting: (connection.connection(for: env.id)?.isConnected ?? false) && !(connection.connection(for: env.id)?.isAuthenticated ?? false),
                        onConnect: { connectEnvironment(env) },
                        onDisconnect: { connection.disconnectEnvironment(env.id, clearCredentials: false) },
                        onUpdate: { environmentStore.update($0); syncIfActive($0) },
                        onDelete: environmentStore.environments.count > 1 ? { environmentStore.delete(env.id) } : nil
                    )
                    .tag(index)
                }

                AddEnvironmentCard { env in
                    environmentStore.add(env)
                    selectedEnvironmentPage = environmentStore.environments.count - 1
                }
                .tag(environmentStore.environments.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 235)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: -8, leading: 0, bottom: -12, trailing: 0))
        .listSectionSpacing(0)
    }

    private func connectEnvironment(_ env: ServerEnvironment) {
        environmentStore.setActive(env.id)
        connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token)
    }

    private func syncIfActive(_ env: ServerEnvironment) {
        if let conn = connection.connection(for: env.id), conn.isAuthenticated {
            conn.disconnect(clearCredentials: false)
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
    @State private var showSymbolPicker = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { showSymbolPicker = true }) {
                    Image(systemName: env.symbol)
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showSymbolPicker, onDismiss: { onUpdate(env) }) {
                    SymbolPickerSheet(selectedSymbol: $env.symbol)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let onDelete {
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Delete \(env.host)?", isPresented: $showDeleteConfirm) {
                        Button("Delete", role: .destructive, action: onDelete)
                    }

                    Divider().frame(height: 20)
                }

                Button(action: {
                    if isConnected { onDisconnect() }
                    else if !isConnecting { onConnect() }
                }) {
                    Image(systemName: "power")
                        .font(.system(size: 16))
                        .foregroundStyle(isConnected || isConnecting ? Color.accentColor : .secondary)
                        .modifier(StreamingPulseModifier(isStreaming: isConnecting))
                }
                .buttonStyle(.plain)
                .disabled(env.host.isEmpty || env.token.isEmpty)
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    TextField("Host", text: $env.host)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .onChange(of: env.host) { _, _ in onUpdate(env) }
                }
                .padding(.vertical, 10)

                Divider().padding(.leading, 36)

                HStack(spacing: 12) {
                    Image(systemName: "number")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    TextField("Port", text: portBinding)
                        .keyboardType(.numberPad)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: env.port) { _, _ in onUpdate(env) }
                }
                .padding(.vertical, 10)

                Divider().padding(.leading, 36)

                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                        .frame(width: 24)

                    Group {
                        if showToken {
                            TextField("Auth Token", text: $env.token)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("Auth Token", text: $env.token)
                        }
                    }
                    .autocapitalization(.none)
                    .onChange(of: env.token) { _, _ in onUpdate(env) }

                    Button(action: { showToken.toggle() }) {
                        Image(systemName: showToken ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 12)
            .background(Color.oceanSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer().frame(height: 2)
        }
        .padding(.horizontal, 4)
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
    let onAdd: (ServerEnvironment) -> Void

    var body: some View {
        Button(action: {
            onAdd(ServerEnvironment(host: "", port: 8765, token: ""))
        }) {
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}
