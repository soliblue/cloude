import Foundation
import SwiftData
import UIKit
import UserNotifications

@MainActor
final class PushNotificationCoordinator {
    static let shared = PushNotificationCoordinator()

    private var context: ModelContext?
    private var token: String?
    private let registrations = PushRegistrationCore()
    private let transport: (Endpoint, String) async -> Int

    init(transport: ((Endpoint, String) async -> Int)? = nil) {
        self.transport = transport ?? Self.send
    }

    func configure(context: ModelContext) {
        self.context = context
        registerIfPossible()
    }

    func registerAll() {
        registerIfPossible()
    }

    func didReceive(deviceToken: Data) {
        token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: StorageKey.pushDeviceToken)
        registerIfPossible()
    }

    func didFailToRegister(error: Error) {
        AppLogger.bootstrapInfo("push registration failed: \(error.localizedDescription)")
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                if let error {
                    self.didFailToRegister(error: error)
                } else if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    private func registerIfPossible() {
        if token == nil {
            token = UserDefaults.standard.string(forKey: StorageKey.pushDeviceToken)
        }
        guard let context else { return }
        guard let token else {
            registrations.sync([])
            return
        }
        let descriptor = FetchDescriptor<Endpoint>()
        let endpoints = (try? context.fetch(descriptor)) ?? []
        let keys = Set(
            endpoints.map { endpoint in
                PushRegistrationKey(
                    endpointId: endpoint.id, revision: endpoint.connectionRevision ?? endpoint.id, token: token)
            })
        registrations.sync(keys)
        for endpoint in endpoints {
            let key = PushRegistrationKey(
                endpointId: endpoint.id, revision: endpoint.connectionRevision ?? endpoint.id, token: token)
            guard !registrations.isRegistered(key), !registrations.isInFlight(key) else { continue }
            Task { @MainActor [weak self, endpoint] in
                guard let self else { return }
                guard self.isCurrent(key, endpointId: endpoint.id) else { return }
                _ = await self.registrations.register(key) { [weak self, transport] _ in
                    guard let self, self.isCurrent(key, endpointId: endpoint.id) else { return 0 }
                    let status = await transport(endpoint, token)
                    return self.isCurrent(key, endpointId: endpoint.id) ? status : 0
                }
            }
        }
    }

    private func isCurrent(_ key: PushRegistrationKey, endpointId: UUID) -> Bool {
        guard token == key.token, let context, let endpoints = try? context.fetch(FetchDescriptor<Endpoint>()),
            let endpoint = endpoints.first(where: { $0.id == endpointId })
        else { return false }
        return key.revision == (endpoint.connectionRevision ?? endpoint.id)
    }

    private static func send(endpoint: Endpoint, token: String) async -> Int {
        if let url = HTTPClient.url(endpoint: endpoint, path: "/push/device", query: [:]) {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "X-Push-Device-Token")
            HTTPClient.sign(&request, endpoint: endpoint)
            if let (_, response) = try? await URLSession.shared.data(for: request),
                let response = response as? HTTPURLResponse
            {
                return response.statusCode
            }
        }
        return 0
    }
}
