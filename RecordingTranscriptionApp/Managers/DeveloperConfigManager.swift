import Foundation
import Security

// MARK: - Keychain Helper
class Keychain {
    func save(key: String, data: Data) -> OSStatus {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil)
    }
    
    func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr {
            return dataTypeRef as! Data?
        } else {
            return nil
        }
    }
    
    func delete(key: String) -> OSStatus {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key
        ] as [String: Any]
        
        return SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Developer Config Manager
@MainActor
class DeveloperConfigManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = DeveloperConfigManager()
    
    // MARK: - Published Properties
    @Published var isConfigured: Bool = false
    @Published var availableServices: Set<TranslationServiceType> = []
    
    // MARK: - Private Properties
    private let keychain = Keychain()
    
    // MARK: - Developer Pre-configured API Keys
    // Note: In production, these should be securely stored or loaded from a secure configuration
    private let developerAPIKeys: [TranslationServiceType: String] = [
        .qianwen: "sk-5c0fe17b51834972af3ff0c6953750cd", // 🔑 真实通义千问API密钥
        .google: "AIzaSyB4sxehiTrzITnxyz1234567890abcdefg" // Placeholder for Google API key
    ]
    
    // MARK: - Keychain Identifiers
    private let qianwenDeveloperKeyIdentifier = "com.jimmy.RecordingTranscriptionApp.developer.qianwenAPIKey"
    private let googleDeveloperKeyIdentifier = "com.jimmy.RecordingTranscriptionApp.developer.googleAPIKey"
    
    // MARK: - Initialization
    private init() {
        setupDeveloperKeys()
        checkConfiguration()
    }
    
    // MARK: - Setup Methods
    
    private func setupDeveloperKeys() {
        // Store developer pre-configured API keys to keychain
        for (service, key) in developerAPIKeys {
            storeDeveloperKey(service: service, key: key)
        }
    }
    
    private func storeDeveloperKey(service: TranslationServiceType, key: String) {
        let identifier = getKeyIdentifier(for: service)
        guard let data = key.data(using: .utf8) else { return }
        
        let status = keychain.save(key: identifier, data: data)
        if status == errSecSuccess {
            print("✅ Developer API key stored for \(service.displayName)")
        } else {
            print("❌ Failed to store developer API key for \(service.displayName): \(status)")
        }
    }
    
    private func checkConfiguration() {
        var services: Set<TranslationServiceType> = []
        
        for service in TranslationServiceType.allCases {
            if getAPIKey(for: service) != nil {
                services.insert(service)
            }
        }
        
        availableServices = services
        isConfigured = !services.isEmpty
        
        print("🔧 Developer Config Status: \(isConfigured ? "Configured" : "Not Configured")")
        print("📱 Available Services: \(services.map { $0.displayName }.joined(separator: ", "))")
    }
    
    // MARK: - Public Methods
    
    func getAPIKey(for service: TranslationServiceType) -> String? {
        let identifier = getKeyIdentifier(for: service)
        guard let data = keychain.load(key: identifier),
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }
    
    func isServiceAvailable(_ service: TranslationServiceType) -> Bool {
        return availableServices.contains(service)
    }
    
    func refreshConfiguration() {
        setupDeveloperKeys()
        checkConfiguration()
    }
    
    // MARK: - Private Helper Methods
    
    private func getKeyIdentifier(for service: TranslationServiceType) -> String {
        switch service {
        case .qianwen:
            return qianwenDeveloperKeyIdentifier
        case .google:
            return googleDeveloperKeyIdentifier
        }
    }
    
    // MARK: - Debug Methods
    
    func debugInfo() -> String {
        var info = "Developer Config Manager Debug Info:\n"
        info += "- Configuration Status: \(isConfigured)\n"
        info += "- Available Services: \(availableServices.count)\n"
        
        for service in TranslationServiceType.allCases {
            let hasKey = getAPIKey(for: service) != nil
            info += "- \(service.displayName): \(hasKey ? "✅" : "❌")\n"
        }
        
        return info
    }
}