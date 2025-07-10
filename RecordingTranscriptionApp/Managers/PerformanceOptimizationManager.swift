import Foundation
import Combine

/// 性能优化管理器 - Phase 3核心组件
class PerformanceOptimizationManager: ObservableObject {
    static let shared = PerformanceOptimizationManager()
    
    @Published var optimizationEnabled = true
    @Published var batchProcessingEnabled = true
    @Published var cacheOptimizationEnabled = true
    @Published var degradationMode = false
    @Published var currentPerformanceLevel: PerformanceLevel = .optimal
    
    private let batchProcessor = BatchProcessor()
    private let errorRecoveryManager = ErrorRecoveryManager()
    private var performanceMetrics = PerformanceMetrics()
    
    // 配置参数
    private let batchSize = 5
    private let batchTimeout: TimeInterval = 2.0
    private let maxConcurrentRequests = 3
    private let responseTimeThreshold: TimeInterval = 5.0
    private let errorRateThreshold: Double = 0.3
    
    private init() {
        setupPerformanceMonitoring()
    }
    
    // MARK: - 批量请求优化
    /// 优化批量翻译请求
    @MainActor
    func optimizedBatchTranslation(
        requests: [TranslationRequest],
        priority: RequestPriority = .normal
    ) async throws -> [String] {
        guard optimizationEnabled && batchProcessingEnabled else {
            return try await fallbackSequentialProcessing(requests)
        }
        
        let startTime = Date()
        
        do {
            let results = try await batchProcessor.processBatch(
                requests: requests,
                strategy: .adaptive,
                priority: priority
            )
            
            let processingTime = Date().timeIntervalSince(startTime)
            recordBatchPerformance(
                requestCount: requests.count,
                processingTime: processingTime,
                success: true
            )
            
            return results
            
        } catch {
            return try await handleBatchError(error, requests: requests)
        }
    }
    
    /// 智能请求合并
    func mergeCompatibleRequests(_ requests: [TranslationRequest]) -> [MergedRequest] {
        var mergedRequests: [MergedRequest] = []
        var processedIndices = Set<Int>()
        
        for (index, request) in requests.enumerated() {
            if processedIndices.contains(index) { continue }
            
            var compatibleRequests = [request]
            var compatibleIndices = [index]
            
            // 查找兼容的请求
            for (otherIndex, otherRequest) in requests.enumerated() {
                if otherIndex != index && !processedIndices.contains(otherIndex) {
                    if areRequestsCompatible(request, otherRequest) {
                        compatibleRequests.append(otherRequest)
                        compatibleIndices.append(otherIndex)
                    }
                }
            }
            
            let mergedRequest = MergedRequest(
                requests: compatibleRequests,
                indices: compatibleIndices,
                mergedText: compatibleRequests.map(\.text).joined(separator: "\n\n"),
                priority: compatibleRequests.map(\.priority).max() ?? .normal
            )
            mergedRequests.append(mergedRequest)
            processedIndices.formUnion(compatibleIndices)
        }
        
        return mergedRequests
    }
    
    // MARK: - 缓存策略优化
    /// 优化缓存策略
    @MainActor
    func optimizeCacheStrategy() async {
        guard cacheOptimizationEnabled else { return }
        
        print("🚀 Starting cache optimization...")
        
        // 执行缓存分析和优化
        await TranslationCacheManager.shared.optimizeEvictionPolicy()
        await TranslationCacheManager.shared.cleanupExpiredEntries()
        
        print("✅ Cache optimization completed")
    }
    
    // MARK: - 错误分类和恢复
    /// 分类和恢复错误
    func classifyAndRecoverFromError(_ error: Error, context: ErrorContext) async -> ErrorRecoveryResult {
        let classification = errorRecoveryManager.classifyError(error)
        
        print("🔍 Error classified as: \(classification)")
        
        switch classification {
        case .network:
            return ErrorRecoveryResult(classification: .network, action: .retry, delay: 2.0, maxRetries: 3)
        case .apiLimit:
            return ErrorRecoveryResult(classification: .apiLimit, action: .degrade, delay: 60.0, maxRetries: 1)
        case .authentication:
            return ErrorRecoveryResult(classification: .authentication, action: .fallback, delay: 0, maxRetries: 0)
        case .serviceUnavailable:
            return ErrorRecoveryResult(classification: .serviceUnavailable, action: .fallback, delay: 5.0, maxRetries: 2)
        case .invalidInput:
            return ErrorRecoveryResult(classification: .invalidInput, action: .fail, delay: 0, maxRetries: 0)
        case .unknown:
            return ErrorRecoveryResult(classification: .unknown, action: .retry, delay: 1.0, maxRetries: 2)
        }
    }
    
    /// 自动错误恢复
    @MainActor
    func attemptAutomaticRecovery(from error: Error, maxAttempts: Int = 3) async -> Bool {
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            print("🔄 Recovery attempt \(attempts)/\(maxAttempts)")
            
            let recoveryAction = errorRecoveryManager.getRecoveryAction(for: error)
            let success = await executeRecoveryAction(recoveryAction)
            
            if success {
                print("✅ Automatic recovery successful")
                return true
            }
            
            // 等待后重试
            try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 1_000_000_000))
        }
        
        print("❌ Automatic recovery failed after \(maxAttempts) attempts")
        return false
    }
    
    // MARK: - 降级策略
    /// 激活降级模式
    @MainActor
    func activateDegradationMode(reason: DegradationReason) {
        degradationMode = true
        currentPerformanceLevel = .degraded
        
        print("⚠️ Degradation mode activated: \(reason)")
        
        adjustPerformanceParameters(for: .degraded)
        
        NotificationCenter.default.post(
            name: .performanceDegradationActivated,
            object: reason
        )
    }
    
    /// 退出降级模式
    @MainActor
    func deactivateDegradationMode() {
        degradationMode = false
        currentPerformanceLevel = .optimal
        
        print("✅ Degradation mode deactivated")
        
        adjustPerformanceParameters(for: .optimal)
        
        NotificationCenter.default.post(
            name: .performanceDegradationDeactivated,
            object: nil
        )
    }
    
    // MARK: - 性能监控
    /// 获取性能报告
    func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            timestamp: Date(),
            currentLevel: currentPerformanceLevel,
            degradationMode: degradationMode,
            batchProcessingStats: batchProcessor.getStatistics(),
            systemMetrics: performanceMetrics.getSystemMetrics()
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func setupPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }
    
    private func updatePerformanceMetrics() {
        performanceMetrics.update()
        Task {
            await checkDegradationTriggers()
        }
    }
    
    private func areRequestsCompatible(_ request1: TranslationRequest, _ request2: TranslationRequest) -> Bool {
        return request1.sourceLanguage == request2.sourceLanguage &&
               request1.targetLanguage == request2.targetLanguage &&
               abs(request1.priority.rawValue - request2.priority.rawValue) <= 1
    }
    
    private func fallbackSequentialProcessing(_ requests: [TranslationRequest]) async throws -> [String] {
        var results: [String] = []
        
        for request in requests {
            let result = try await TranslationServiceManager.shared.translateWithLoadBalancing(
                text: request.text,
                from: request.sourceLanguage,
                to: request.targetLanguage,
                priority: request.priority
            )
            results.append(result)
        }
        
        return results
    }
    
    private func handleBatchError(_ error: Error, requests: [TranslationRequest]) async throws -> [String] {
        let recoveryResult = await classifyAndRecoverFromError(error, context: .batchProcessing)
        
        switch recoveryResult.action {
        case .retry:
            return try await optimizedBatchTranslation(requests: requests)
        case .fallback:
            return try await fallbackSequentialProcessing(requests)
        case .degrade:
            await activateDegradationMode(reason: .errorRate)
            return try await fallbackSequentialProcessing(requests)
        case .fail:
            throw error
        }
    }
    
    private func recordBatchPerformance(requestCount: Int, processingTime: TimeInterval, success: Bool) {
        performanceMetrics.recordBatchOperation(
            requestCount: requestCount,
            processingTime: processingTime,
            success: success
        )
    }
    
    private func executeRecoveryAction(_ action: RecoveryAction) async -> Bool {
        switch action {
        case .retry, .fallback:
            return true
        case .degrade:
            await activateDegradationMode(reason: .errorRate)
            return true
        case .fail:
            return false
        }
    }
    
    private func adjustPerformanceParameters(for level: PerformanceLevel) {
        switch level {
        case .optimal:
            batchProcessor.setMaxBatchSize(batchSize)
        case .degraded:
            batchProcessor.setMaxBatchSize(batchSize / 2)
        case .minimal:
            batchProcessor.setMaxBatchSize(1)
        }
    }
    
    private func checkDegradationTriggers() async {
        let metrics = await performanceMetrics.getCurrentMetrics()
        
        if shouldTriggerDegradation(metrics) {
            let reason = determineDegradationReason(metrics)
            await activateDegradationMode(reason: reason)
        } else if degradationMode && shouldExitDegradation(metrics) {
            await deactivateDegradationMode()
        }
    }
    
    private func shouldTriggerDegradation(_ metrics: SystemMetrics) -> Bool {
        return metrics.errorRate > errorRateThreshold ||
               metrics.averageResponseTime > responseTimeThreshold
    }
    
    private func determineDegradationReason(_ metrics: SystemMetrics) -> DegradationReason {
        if metrics.errorRate > errorRateThreshold {
            return .errorRate
        } else if metrics.averageResponseTime > responseTimeThreshold {
            return .responseTime
        } else {
            return .systemLoad
        }
    }
    
    private func shouldExitDegradation(_ metrics: SystemMetrics) -> Bool {
        return metrics.errorRate < errorRateThreshold * 0.5 &&
               metrics.averageResponseTime < responseTimeThreshold * 0.8
    }
}

// MARK: - Supporting Types and Enums

enum PerformanceLevel {
    case optimal
    case degraded
    case minimal
}

enum DegradationReason {
    case errorRate
    case responseTime
    case systemLoad
    case apiQuota
    case networkIssues
}

enum BatchProcessingStrategy {
    case sequential
    case parallel
    case adaptive
}

enum ErrorClassification {
    case network
    case apiLimit
    case authentication
    case serviceUnavailable
    case invalidInput
    case unknown
}

enum RecoveryAction {
    case retry
    case fallback
    case degrade
    case fail
}

enum ErrorContext {
    case batchProcessing
    case singleRequest
    case healthCheck
    case cacheOperation
}

struct MergedRequest {
    let requests: [TranslationRequest]
    let indices: [Int]
    let mergedText: String
    let priority: RequestPriority
}

struct ErrorRecoveryResult {
    let classification: ErrorClassification
    let action: RecoveryAction
    let delay: TimeInterval
    let maxRetries: Int
}

struct PerformanceReport {
    let timestamp: Date
    let currentLevel: PerformanceLevel
    let degradationMode: Bool
    let batchProcessingStats: BatchProcessingStats
    let systemMetrics: SystemMetrics
}

struct BatchProcessingStats {
    let totalBatches: Int
    let successfulBatches: Int
    let averageBatchSize: Double
    let averageProcessingTime: TimeInterval
}

struct SystemMetrics {
    let errorRate: Double
    let averageResponseTime: TimeInterval
    let memoryUsage: Double
    let cpuUsage: Double
}

// MARK: - Supporting Classes

class BatchProcessor {
    private var maxBatchSize = 5
    private var stats = BatchProcessingStats(totalBatches: 0, successfulBatches: 0, averageBatchSize: 0, averageProcessingTime: 0)
    
    func processBatch(
        requests: [TranslationRequest],
        strategy: BatchProcessingStrategy,
        priority: RequestPriority
    ) async throws -> [String] {
        // 简化实现：依次处理请求
        var results: [String] = []
        
        for request in requests {
            let result = try await TranslationServiceManager.shared.translateWithLoadBalancing(
                text: request.text,
                from: request.sourceLanguage,
                to: request.targetLanguage,
                priority: request.priority
            )
            results.append(result)
        }
        
        return results
    }
    
    func setMaxBatchSize(_ size: Int) {
        maxBatchSize = size
    }
    
    func getStatistics() -> BatchProcessingStats {
        return stats
    }
}

class ErrorRecoveryManager {
    private var stats = ErrorRecoveryStats(totalErrors: 0, successfulRecoveries: 0, recoveryRate: 0, averageRecoveryTime: 0)
    
    func classifyError(_ error: Error) -> ErrorClassification {
        if error.localizedDescription.contains("network") {
            return .network
        } else if error.localizedDescription.contains("API") {
            return .apiLimit
        } else {
            return .unknown
        }
    }
    
    func getRecoveryAction(for error: Error) -> RecoveryAction {
        return .retry
    }
}

struct ErrorRecoveryStats {
    let totalErrors: Int
    let successfulRecoveries: Int
    let recoveryRate: Double
    let averageRecoveryTime: TimeInterval
}

class PerformanceMetrics {
    func update() {
        // 更新性能指标
    }
    
    func getCurrentMetrics() async -> SystemMetrics {
        return SystemMetrics(errorRate: 0.1, averageResponseTime: 2.0, memoryUsage: 0.5, cpuUsage: 0.3)
    }
    
    func getSystemMetrics() -> SystemMetrics {
        return SystemMetrics(errorRate: 0.1, averageResponseTime: 2.0, memoryUsage: 0.5, cpuUsage: 0.3)
    }
    
    func recordBatchOperation(requestCount: Int, processingTime: TimeInterval, success: Bool) {
        // 记录批量操作指标
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let performanceDegradationActivated = Notification.Name("performanceDegradationActivated")
    static let performanceDegradationDeactivated = Notification.Name("performanceDegradationDeactivated")
}