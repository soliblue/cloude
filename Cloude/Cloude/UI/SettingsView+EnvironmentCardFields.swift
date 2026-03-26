// SettingsView+EnvironmentCardFields.swift

import SwiftUI

extension EnvironmentCard {
    var formFields: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: DS.Icon.m))
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
                    .font(.system(size: DS.Icon.m))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                TextField("Port", text: portBinding)
                    .keyboardType(.numberPad)
                    .font(.system(size: DS.Text.m, design: .monospaced))
                    .onChange(of: env.port) { _, _ in onUpdate(env) }
            }
            .padding(.vertical, 10)

            Divider().padding(.leading, 36)

            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: DS.Icon.m))
                    .foregroundColor(.orange)
                    .frame(width: 24)

                Group {
                    if showToken {
                        TextField("Auth Token", text: $env.token)
                            .font(.system(size: DS.Text.m, design: .monospaced))
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
        .background(Color.themeSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var portBinding: Binding<String> {
        Binding(
            get: { String(env.port) },
            set: { env.port = UInt16($0) ?? 8765 }
        )
    }
}
