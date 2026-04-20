import SwiftUI

extension SettingsView {
    var environmentsCarousel: some View {
        Section {
            VStack(spacing: 0) {
                TabView(selection: $selectedEnvironmentPage) {
                    ForEach(Array(environmentStore.environments.enumerated()), id: \.element.id) { index, env in
                        environmentCard(env: env)
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

    @ViewBuilder
    private func environmentCard(env: ServerEnvironment) -> some View {
        if let connection = environmentStore.connectionStore.connection(for: env.id) {
            ConnectionObserver(connection: connection) { connection in
                card(env: env, isConnected: connection.isReady, isConnecting: connection.isConnecting)
            }
        } else {
            card(env: env, isConnected: false, isConnecting: false)
        }
    }

    private func card(env: ServerEnvironment, isConnected: Bool, isConnecting: Bool) -> some View {
        EnvironmentCard(
            env: env,
            isConnected: isConnected,
            isConnecting: isConnecting,
            onConnect: { environmentStore.setActive(env.id); environmentStore.connectionStore.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol) },
            onDisconnect: { environmentStore.connectionStore.disconnectEnvironment(env.id, clearCredentials: false) },
            onUpdate: { environmentStore.update($0); if let conn = environmentStore.connectionStore.connection(for: $0.id), conn.isReady { conn.disconnect(clearCredentials: false) } },
            onDelete: environmentStore.environments.count > 1 ? { environmentStore.delete(env.id) } : nil
        )
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

}
