// SettingsView+Environments.swift

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
            .frame(height: DS.Size.xxl)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: -8, leading: 0, bottom: -12, trailing: 0))
        .listSectionSpacing(0)
    }

    private func connectEnvironment(_ env: ServerEnvironment) {
        environmentStore.setActive(env.id)
        connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
    }

    private func syncIfActive(_ env: ServerEnvironment) {
        if let conn = connection.connection(for: env.id), conn.isAuthenticated {
            conn.disconnect(clearCredentials: false)
        }
    }
}
