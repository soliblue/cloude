import SwiftUI

extension EnvironmentCard {
    var formFields: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.m) {
                Image(systemName: "server.rack")
                    .font(.system(size: DS.Icon.m))
                    .foregroundColor(AppColor.blue)
                TextField("Host", text: hostBinding)
                    .font(.system(size: DS.Text.m))
                    .textFieldStyle(.plain)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }
            .padding(.vertical, DS.Spacing.m)

            Divider().padding(.leading, DS.Spacing.l)

            HStack(spacing: DS.Spacing.m) {
                Image(systemName: "number")
                    .font(.system(size: DS.Icon.m))
                    .foregroundColor(AppColor.blue)
                TextField("Port", text: portTextBinding)
                    .keyboardType(.numberPad)
                    .font(.system(size: DS.Text.m, design: .monospaced))
                    .textFieldStyle(.plain)
            }
            .padding(.vertical, DS.Spacing.m)

            Divider().padding(.leading, DS.Spacing.l)

            HStack(spacing: DS.Spacing.m) {
                Image(systemName: "key.fill")
                    .font(.system(size: DS.Icon.m))
                    .foregroundColor(AppColor.orange)

                Group {
                    if showToken {
                        TextField("Auth Token", text: tokenBinding)
                            .font(.system(size: DS.Text.m, design: .monospaced))
                            .textFieldStyle(.plain)
                    } else {
                        SecureField("Auth Token", text: tokenBinding)
                            .font(.system(size: DS.Text.m, design: .monospaced))
                            .textFieldStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .autocapitalization(.none)

                Button(action: { showToken.toggle() }) {
                    Image(systemName: showToken ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, DS.Spacing.m)
        }
        .padding(.horizontal, DS.Spacing.m)
        .background(Color.themeSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
    }

    var hostBinding: Binding<String> {
        Binding(
            get: { env.host },
            set: {
                env.host = $0
                onUpdate(env)
            }
        )
    }

    var portTextBinding: Binding<String> {
        Binding(
            get: { String(env.port) },
            set: {
                env.port = UInt16($0) ?? 8765
                onUpdate(env)
            }
        )
    }

    var tokenBinding: Binding<String> {
        Binding(
            get: { env.token },
            set: {
                env.token = $0
                onUpdate(env)
            }
        )
    }
}
