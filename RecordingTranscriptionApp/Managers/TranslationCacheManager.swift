import Foundation
import CryptoKit

/// 翻译缓存项
struct TranslationCacheItem: Codable {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let serviceType: TranslationServiceType
    let timestamp: Date
    let cacheKey: String
    
    var isExpired: Bool {
        let cacheExpiry = Calendar.current.date(byAdding: .hour, value: 24, to: timestamp) ?? Date()
        return Date() > cacheExpiry
    }
}

/// 翻译缓存统计
struct CacheStatistics {
    let totalEntries: Int
    let hitCount: Int
    let missCount: Int
    let hitRate: Double
    let cacheSize: String
    let expiredEntries: Int
    
    var hitRatePercentage: String {
        return String(format: "%.1f%%", hitRate * 100)
    }
}

@MainActor
class TranslationCacheManager: ObservableObject {
    static let shared = TranslationCacheManager()
    
    @Published var isEnabled = true
    @Published var cacheStatistics = CacheStatistics(totalEntries: 0, hitCount: 0, missCount: 0, hitRate: 0.0, cacheSize: "0 KB", expiredEntries: 0)
    
    private var cache: [String: TranslationCacheItem] = [:]
    private var hitCount = 0
    private var missCount = 0
    private let cacheQueue = DispatchQueue(label: "translation.cache", qos: .utility)
    private let maxCacheSize = 1000 // 最大缓存条目数
    
    private init() {
        loadCacheFromDisk()
        scheduleCleanup()
        updateStatistics()
    }
    
    // MARK: - Public Methods
    
    /// 获取缓存的翻译
    func getCachedTranslation(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String,
        service: TranslationServiceType
    ) -> String? {
        guard isEnabled else { return nil }
        
        let cacheKey = generateCacheKey(
            text: text,
            from: sourceLanguage,
            to: targetLanguage,
            service: service
        )
        
        if let cachedItem = cache[cacheKey], !cachedItem.isExpired {
            hitCount += 1
            updateStatistics()
            return cachedItem.translatedText
        }
        
        missCount += 1
        updateStatistics()
        return nil
    }
    
    /// 缓存翻译结果
    func cacheTranslation(
        originalText: String,
        translatedText: String,
        from sourceLanguage: String,
        to targetLanguage: String,
        service: TranslationServiceType
    ) {
        guard isEnabled else { return }
        
        let cacheKey = generateCacheKey(
            text: originalText,
            from: sourceLanguage,
            to: targetLanguage,
            service: service
        )
        
        let cacheItem = TranslationCacheItem(
            originalText: originalText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            serviceType: service,
            timestamp: Date(),
            cacheKey: cacheKey
        )
        
        cache[cacheKey] = cacheItem
        
        // 检查缓存大小限制
        if cache.count > maxCacheSize {
            cleanOldEntries()
        }
        
        saveCacheToDisk()
        updateStatistics()
    }
    
    /// 清理所有缓存
    func clearAllCache() {
        cache.removeAll()
        hitCount = 0
        missCount = 0
        saveCacheToDisk()
        updateStatistics()
    }
    
    /// 清理过期缓存
    func clearExpiredCache() {
        let expiredKeys = cache.compactMap { key, item in
            item.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
        
        saveCacheToDisk()
        updateStatistics()
    }
    
    /// 预热缓存（常用翻译对）
    func preheatCache() {
        let commonTranslations = [
            ("Hello", "你好", "en", "zh", TranslationServiceType.qianwen),
            ("Thank you", "谢谢", "en", "zh", TranslationServiceType.qianwen),
            ("Good morning", "早上好", "en", "zh", TranslationServiceType.qianwen),
            ("How are you?", "你好吗？", "en", "zh", TranslationServiceType.qianwen)
        ]
        
        for (original, translated, from, to, service) in commonTranslations {
            cacheTranslation(
                originalText: original,
                translatedText: translated,
                from: from,
                to: to,
                service: service
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func generateCacheKey(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String,
        service: TranslationServiceType
    ) -> String {
        let combined = "\(text)|\(sourceLanguage)|\(targetLanguage)|\(service.rawValue)"
        let inputData = Data(combined.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func cleanOldEntries() {
        // 按时间戳排序，删除最老的条目
        let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
        let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize + 100) // 删除100个最老条目
        
        for (key, _) in entriesToRemove {
            cache.removeValue(forKey: key)
        }
    }
    
    private func scheduleCleanup() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in
                self.clearExpiredCache()
            }
        }
    }
    
    private func updateStatistics() {
        let totalRequests = hitCount + missCount
        let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
        let expiredCount = cache.values.filter { $0.isExpired }.count
        
        // 计算缓存大小
        let cacheData = try? JSONEncoder().encode(Array(cache.values))
        let cacheSizeBytes = cacheData?.count ?? 0
        let cacheSizeString = ByteCountFormatter.string(fromByteCount: Int64(cacheSizeBytes), countStyle: .file)
        
        cacheStatistics = CacheStatistics(
            totalEntries: cache.count,
            hitCount: hitCount,
            missCount: missCount,
            hitRate: hitRate,
            cacheSize: cacheSizeString,
            expiredEntries: expiredCount
        )
    }
    
    // MARK: - Persistence
    
    private var cacheFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("translation_cache.json")
    }
    
    private func saveCacheToDisk() {
        let cacheArray = Array(cache.values)
        let fileURL = cacheFileURL
        
        cacheQueue.async {
            do {
                let data = try JSONEncoder().encode(cacheArray)
                try data.write(to: fileURL)
            } catch {
                print("❌ Failed to save cache: \(error)")
            }
        }
    }
    
    private func loadCacheFromDisk() {
        let fileURL = cacheFileURL
        
        cacheQueue.async {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            
            do {
                let data = try Data(contentsOf: fileURL)
                let cacheArray = try JSONDecoder().decode([TranslationCacheItem].self, from: data)
                
                Task { @MainActor in
                    // 只加载未过期的缓存
                    for item in cacheArray where !item.isExpired {
                        self.cache[item.cacheKey] = item
                    }
                    self.updateStatistics()
                }
            } catch {
                print("❌ Failed to load cache: \(error)")
            }
        }
    }
}

// MARK: - Performance Optimization Extensions
extension TranslationCacheManager {
    
    /// 优化缓存驱逐策略
    func optimizeEvictionPolicy() {
        // 智能清理：优先删除过期和低频使用的条目
        let currentTime = Date()
        var itemsToRemove: [String] = []
        
        // 1. 删除所有过期条目
        for (key, item) in cache {
            if item.isExpired {
                itemsToRemove.append(key)
            }
        }
        
        // 2. 如果缓存仍然过大，删除最老的条目
        if cache.count - itemsToRemove.count > maxCacheSize * 3/4 {
            let sortedItems = cache
                .filter { !itemsToRemove.contains($0.key) }
                .sorted { $0.value.timestamp < $1.value.timestamp }
            
            let additionalRemovalCount = (cache.count - itemsToRemove.count) - maxCacheSize * 3/4
            itemsToRemove.append(contentsOf: sortedItems.prefix(additionalRemovalCount).map { $0.key })
        }
        
        // 执行删除
        for key in itemsToRemove {
            cache.removeValue(forKey: key)
        }
        
        saveCacheToDisk()
        updateStatistics()
        
        print("🔧 Cache optimization completed: removed \(itemsToRemove.count) items")
    }
    
    /// 清理过期条目
    func cleanupExpiredEntries() {
        let expiredKeys = cache.compactMap { key, item in
            item.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
        
        saveCacheToDisk()
        updateStatistics()
        
        print("🧹 Cleanup completed: removed \(expiredKeys.count) expired entries")
    }
}


