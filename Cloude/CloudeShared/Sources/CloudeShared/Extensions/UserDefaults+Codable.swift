import Foundation

public extension UserDefaults {
    func setCodable<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            set(data, forKey: key)
        }
    }

    func codable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func codable<T: Decodable>(_ type: T.Type, forKey key: String, default defaultValue: T) -> T {
        codable(type, forKey: key) ?? defaultValue
    }
}
