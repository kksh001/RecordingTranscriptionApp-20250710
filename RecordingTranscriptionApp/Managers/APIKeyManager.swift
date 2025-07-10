import Foundation
import Security

@MainActor
class APIKeyManager: ObservableObject {
    static let shared = APIKeyManager()
    
    @Published var hasGoogleTranslateKey: Bool = false
    @Published var hasQianwenKey: Bool = false
    @Published var isUsingDeveloperConfig: Bool = true
    
    // Legacy keychain identifiers (kept for backward compatibility)
    private let googleTranslateKeyIdentifier = "com.jimmy.RecordingTranscriptionApp.googleTranslateAPIKey"
    private let qianwenKeyIdentifier = "com.jimmy.RecordingTranscriptionApp.qianwenAPIKey"
    
    // Developer config manager reference
    private let developerConfigManager = DeveloperConfigManager.shared
    
    private init() {
        checkExistingKeys()
    }
    
    private func checkExistingKeys() {
        // Priority: Developer config > Legacy user config
        hasGoogleTranslateKey = getDeveloperGoogleTranslateAPIKey() != nil || getLegacyGoogleTranslateAPIKey() != nil
        hasQianwenKey = getDeveloperQianwenAPIKey() != nil || getLegacyQianwenAPIKey() != nil
        
        // Check if using developer configuration
        isUsingDeveloperConfig = developerConfigManager.isConfigured
    }
    
    // MARK: - Primary API Key Access (Developer Config Priority)
    
    func getGoogleTranslateAPIKey() -> String? {
        // Priority: Developer config first, then legacy user config
        if let developerKey = getDeveloperGoogleTranslateAPIKey() {
            return developerKey
        }
        return getLegacyGoogleTranslateAPIKey()
    }
    
    func getQianwenAPIKey() -> String? {
        // Priority: Developer config first, then legacy user config
        if let developerKey = getDeveloperQianwenAPIKey() {
            return developerKey
        }
        return getLegacyQianwenAPIKey()
    }
    
    // MARK: - Developer Config API Keys
    
    private func getDeveloperGoogleTranslateAPIKey() -> String? {
        return developerConfigManager.getAPIKey(for: .google)
    }
    
    private func getDeveloperQianwenAPIKey() -> String? {
        return developerConfigManager.getAPIKey(for: .qianwen)
    }
    
    // MARK: - Legacy User Config Support (Backward Compatibility)
    
    @available(*, deprecated, message: "Use developer pre-configured keys instead")
    func saveGoogleTranslateAPIKey(_ key: String) -> Bool {
        let result = saveToKeychain(key: key, identifier: googleTranslateKeyIdentifier)
        if result {
            hasGoogleTranslateKey = true
        }
        return result
    }
    
    private func getLegacyGoogleTranslateAPIKey() -> String? {
        return getFromKeychain(identifier: googleTranslateKeyIdentifier)
    }
    
    @available(*, deprecated, message: "Use developer pre-configured keys instead")
    func deleteGoogleTranslateAPIKey() -> Bool {
        let result = deleteFromKeychain(identifier: googleTranslateKeyIdentifier)
        if result {
            checkExistingKeys() // Refresh state
        }
        return result
    }
    
    @available(*, deprecated, message: "Use developer pre-configured keys instead")
    func saveQianwenAPIKey(_ key: String) -> Bool {
        let result = saveToKeychain(key: key, identifier: qianwenKeyIdentifier)
        if result {
            hasQianwenKey = true
        }
        return result
    }
    
    private func getLegacyQianwenAPIKey() -> String? {
        return getFromKeychain(identifier: qianwenKeyIdentifier)
    }
    
    @available(*, deprecated, message: "Use developer pre-configured keys instead")
    func deleteQianwenAPIKey() -> Bool {
        let result = deleteFromKeychain(identifier: qianwenKeyIdentifier)
        if result {
            checkExistingKeys() // Refresh state
        }
        return result
    }
    
    // MARK: - Service Status
    
    func isServiceConfigured(_ service: TranslationServiceType) -> Bool {
        switch service {
        case .google:
            return hasGoogleTranslateKey
        case .qianwen:
            return hasQianwenKey
        }
    }
    
    func getConfigurationSource(for service: TranslationServiceType) -> String {
        switch service {
        case .google:
            if getDeveloperGoogleTranslateAPIKey() != nil {
                return "Developer Pre-configured"
            } else if getLegacyGoogleTranslateAPIKey() != nil {
                return "User Configured (Legacy)"
            }
            return "Not Configured"
        case .qianwen:
            if getDeveloperQianwenAPIKey() != nil {
                return "Developer Pre-configured"
            } else if getLegacyQianwenAPIKey() != nil {
                return "User Configured (Legacy)"
            }
            return "Not Configured"
        }
    }
    
    func refreshConfiguration() {
        developerConfigManager.refreshConfiguration()
        checkExistingKeys()
    }
    
    // MARK: - Keychain 操作
    private func saveToKeychain(key: String, identifier: String) -> Bool {
        // 首先删除已存在的项
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identifier
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // 添加新项
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identifier,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getFromKeychain(identifier: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    private func deleteFromKeychain(identifier: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: identifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Validation
    
    func validateGoogleTranslateAPIKey(_ key: String) async -> Bool {
        // 简单的格式验证
        guard key.count >= 30 && key.hasPrefix("AIza") else {
            return false
        }
        
        // 可以添加实际的API验证调用
        return true
    }
    
    func validateQianwenAPIKey(_ key: String) async -> Bool {
        // 简单的格式验证
        guard !key.isEmpty else {
            return false
        }
        
        // 可以添加实际的API验证调用
        return true
    }
    
    // MARK: - Migration Support
    
    func migrateToDeveloperConfig() {
        // This method can be used to migrate from user config to developer config
        // Currently, developer config takes priority automatically
        print("Migration to developer config: Developer keys take priority over user keys")
        checkExistingKeys()
    }
    
    // MARK: - Testing Support
    
    func testAPIKeyAccess() -> (googleAvailable: Bool, qianwenAvailable: Bool) {
        let googleKey = getDeveloperGoogleTranslateAPIKey()
        let qianwenKey = getDeveloperQianwenAPIKey()
        return (googleKey != nil, qianwenKey != nil)
    }
    
    func getAPIKeyInfo() -> (googleLength: Int?, qianwenLength: Int?) {
        let googleKey = getDeveloperGoogleTranslateAPIKey()
        let qianwenKey = getDeveloperQianwenAPIKey()
        return (googleKey?.count, qianwenKey?.count)
    }
} 