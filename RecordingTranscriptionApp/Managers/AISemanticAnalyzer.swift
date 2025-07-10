import Foundation
import Combine

/// AI语义分析管理器 - 替代硬编码用户话语预设
/// 🚀 解决硬编码欺骗问题：不再预设用户会说什么话
@MainActor
class AISemanticAnalyzer: ObservableObject {
    static let shared = AISemanticAnalyzer()
    
    private let qianwenManager = QianwenTranslateManager.shared
    private var analysisCache: [String: (result: Bool, timestamp: Date)] = [:]
    private let cacheExpiry: TimeInterval = 300 // 5分钟过期
    
    private var pendingAnalyses: [String] = []
    private let batchSize = 5
    private let batchTimeout: TimeInterval = 2.0
    
    private init() {}
    
    // MARK: - 核心AI分析函数
    
    /// 列表结构AI分析 - 替代硬编码contextualListPatterns
    func analyzeListStructure(_ text: String) async -> Bool {
        let prompt = """
        Analyze if this text contains a list structure, enumeration, or series.
        Consider any language and any expression style.
        Return only "true" or "false".
        Text: \(text)
        """
        
        return await performBooleanAnalysis(prompt, text: text)
    }
    
    /// 语义完整性AI分析 - 替代硬编码语义规则
    func analyzeSemanticCompleteness(_ text: String) async -> Bool {
        let prompt = """
        Is this text semantically complete? Does it express a complete thought?
        Consider any language and context.
        Return only "true" or "false".
        Text: \(text)
        """
        
        return await performBooleanAnalysis(prompt, text: text)
    }
    
    /// 内容连续性AI分析 - 替代硬编码continuationWords
    func analyzeContinuationIndicators(_ text: String) async -> Bool {
        let prompt = """
        Does this text end with words that indicate more content is coming?
        Consider any language and expression style.
        Return only "true" or "false".
        Text: \(text)
        """
        
        return await performBooleanAnalysis(prompt, text: text)
    }
    
    // MARK: - 私有辅助函数
    
    private func performBooleanAnalysis(_ prompt: String, text: String) async -> Bool {
        // 检查缓存
        if let cached = getCachedResult(text) {
            return cached
        }
        
        do {
            // 调用AI分析
            let result = try await qianwenManager.translateText(prompt, from: "en", to: "en")
            let boolResult = result.lowercased().contains("true")
            
            // 缓存结果
            setCachedResult(text, result: boolResult)
            
            return boolResult
        } catch {
            print("AI analysis failed: \(error)")
            // 降级到保守策略
            return conservativeFallbackAnalysis(text)
        }
    }
    
    private func getCachedResult(_ text: String) -> Bool? {
        guard let cached = analysisCache[text],
              Date().timeIntervalSince(cached.timestamp) < cacheExpiry else {
            return nil
        }
        return cached.result
    }
    
    private func setCachedResult(_ text: String, result: Bool) {
        analysisCache[text] = (result: result, timestamp: Date())
    }
    
    private func conservativeFallbackAnalysis(_ text: String) -> Bool {
        // 🔥 移除硬编码预设：AI失败时返回false，继续等待更多内容
        // 不预设用户会说什么话，完全依赖AI理解
        return false
    }
} 