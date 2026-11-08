import Foundation
import CoreFoundation
import Security

enum SecureStore {
    private static let service = Bundle.main.bundleIdentifier ?? "ch.halo.cubemaster.playgrounds"
    private static let accessTokenKey = "ai.apiAccessToken"

    static func readAPIAccessToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw SecureStoreError.keychain(status)
        }
        guard
            let data = result as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            throw SecureStoreError.invalidToken
        }
        return token
    }

    static func saveAPIAccessToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SecureStoreError.keychain(addStatus)
            }
        } else if status != errSecSuccess {
            throw SecureStoreError.keychain(status)
        }
    }
}

private enum SecureStoreError: LocalizedError {
    case keychain(OSStatus)
    case invalidToken

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            return "Le trousseau Apple a refusé l’accès au jeton (code \(status))."
        case .invalidToken:
            return "Le jeton enregistré dans le trousseau est invalide."
        }
    }
}
