import SwiftUI

extension SettingsView {
    var environmentsCarousel: some View {
        Section {
            VStack(spacing: 0) {
                TabView(selection: $selectedEnvironmentPage) {
                    ForEach(Array(environmentStore.environments.enumerated()), id: \.element.id) { index, env in
                        EnvironmentCard(
                            env: env,
                            isConnected: connection.connection(for: env.id)?.phase == .authenticated,
                            isConnecting: connection.connection(for: env.id)?.phase == .connected,
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
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: DS.Size.xxl)

                environmentPageIndicators
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: -8, leading: 0, bottom: 0, trailing: 0))
        .listSectionSpacing(0)
    }

    private var environmentPageIndicators: some View {
        let totalPages = environmentStore.environments.count + 1
        return HStack(spacing: DS.Spacing.s) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == selectedEnvironmentPage ? Color.accentColor : Color.secondary.opacity(DS.Opacity.m))
                    .frame(width: DS.Size.s, height: DS.Size.s)
            }
        }
        .padding(.top, DS.Text.step)
        .padding(.bottom, DS.Spacing.s)
        .frame(maxWidth: .infinity)
    }

    private func connectEnvironment(_ env: ServerEnvironment) {
        environmentStore.setActive(env.id)
        connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
    }

    private func syncIfActive(_ env: ServerEnvironment) {
        if let conn = connection.connection(for: env.id), conn.phase == .authenticated {
            conn.disconnect(clearCredentials: false)
        }
    }
}
