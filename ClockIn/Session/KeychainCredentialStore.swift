import Foundation
import Security

/// Stores the credentials as one generic-password item in the data-protection keychain
/// (design decision D6). Every status other than success and "not found" is an error.
struct KeychainCredentialStore: CredentialStore {
    private let service = AppIdentity.bundleIdentifier
    private let account = "credentials"
    private let logger = Log.logger(.session)

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    func load() throws -> Credentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                logger.error("Keychain item is not data")
                throw KeychainError(status: errSecDecode)
            }
            return try JSONDecoder().decode(Credentials.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            logger.error("Keychain read failed with status \(status, privacy: .public)")
            throw KeychainError(status: status)
        }
    }

    func save(_ credentials: Credentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            logger.notice("Credentials updated in keychain")
            return
        }
        guard updateStatus == errSecItemNotFound else {
            logger.error("Keychain update failed with status \(updateStatus, privacy: .public)")
            throw KeychainError(status: updateStatus)
        }
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            logger.error("Keychain add failed with status \(addStatus, privacy: .public)")
            throw KeychainError(status: addStatus)
        }
        logger.notice("Credentials added to keychain")
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Keychain delete failed with status \(status, privacy: .public)")
            throw KeychainError(status: status)
        }
        logger.notice("Credentials removed from keychain")
    }
}
