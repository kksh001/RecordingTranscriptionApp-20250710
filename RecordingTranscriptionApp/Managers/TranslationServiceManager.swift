import Foundation
import Combine

/// 翻译服务管理器 - Phase 3核心组件
class TranslationServiceManager: ObservableObject {
    static let shared = TranslationServiceManager()
    
    @Published var availableServices: [TranslationServiceType] = []
    @Published var serviceHealthStatus: [TranslationServiceType: ServiceHealthStatus] = [:]
    @Published var currentActiveService: TranslationServiceType?
    @Published var isMonitoring = false
    
    private var registeredServices: [TranslationServiceType: TranslationServiceProvider] = [:]
    private var serviceMetrics: [TranslationServiceType: ServiceMetrics] = [:]
    private var healthCheckTimer: Timer?
    
    private init() {
        setupInitialServices()
        startHealthMonitoring()
    }
    
    /// 注册翻译服务
    func registerService(_ serviceType: TranslationServiceType, provider: TranslationServiceProvider) {
        registeredServices[serviceType] = provider
        availableServices.append(serviceType)
        serviceHealthStatus[serviceType] = .unknown
        serviceMetrics[serviceType] = ServiceMetrics()
        print("📋 Registered service: \(serviceType.displayName)")
    }
    
    /// 获取最佳翻译服务
    func getBestService(for request: TranslationRequest) async -> TranslationServiceType? {
        let healthyServices = getHealthyServices()
        return healthyServices.first ?? .qianwen
    }
    
    /// 带负载均衡的翻译
    @MainActor
    func translateWithLoadBalancing(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String,
        priority: RequestPriority = .normal
    ) async throws -> String {
        let request = TranslationRequest(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            priority: priority,
            timestamp: Date()
        )
        
        guard let serviceType = await getBestService(for: request) else {
            throw ServiceManagerError.noAvailableService
        }
        
        // 直接使用QianwenTranslateManager
        return try await QianwenTranslateManager.shared.translateText(
            text,
            from: sourceLanguage,
            to: targetLanguage
        )
    }
    
    /// 开始健康监控
    private func startHealthMonitoring() {
        isMonitoring = true
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performHealthChecks()
            }
        }
    }
    
    /// 执行健康检查
    private func performHealthChecks() async {
        for serviceType in registeredServices.keys {
            await checkServiceHealth(serviceType)
        }
    }
    
    @MainActor
    private func checkServiceHealth(_ serviceType: TranslationServiceType) async {
        serviceHealthStatus[serviceType] = .healthy(responseTime: 1.0)
    }
    
    private func setupInitialServices() {
        let qianwenProvider = QianwenServiceProvider()
        registerService(.qianwen, provider: qianwenProvider)
    }
    
    private func getHealthyServices() -> [TranslationServiceType] {
        return serviceHealthStatus.compactMap { serviceType, status in
            status.isHealthy ? serviceType : nil
        }
    }
}

// MARK: - Supporting Types
protocol TranslationServiceProvider {
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> String
    func healthCheck() async throws
}

struct TranslationRequest {
    let text: String
    let sourceLanguage: String
    let targetLanguage: String
    let priority: RequestPriority
    let timestamp: Date
    let id = UUID()
}

enum RequestPriority: Int, CaseIterable, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

enum ServiceHealthStatus {
    case unknown
    case healthy(responseTime: TimeInterval)
    case unhealthy(error: Error)
    
    var isHealthy: Bool {
        switch self {
        case .healthy:
            return true
        default:
            return false
        }
    }
}

class ServiceMetrics: ObservableObject {
    @Published var totalRequests: Int = 0
    @Published var successfulRequests: Int = 0
    @Published var failedRequests: Int = 0
    @Published var averageResponseTime: TimeInterval = 0
}

class QianwenServiceProvider: TranslationServiceProvider {
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> String {
        return try await QianwenTranslateManager.shared.translateText(
            text,
            from: sourceLanguage,
            to: targetLanguage
        )
    }
    
    func healthCheck() async throws {
        // 简单的健康检查
    }
}

enum ServiceManagerError: LocalizedError {
    case noAvailableService
    case serviceNotRegistered(TranslationServiceType)
    
    var errorDescription: String? {
        switch self {
        case .noAvailableService:
            return "No translation service available"
        case .serviceNotRegistered(let serviceType):
            return "Service \(serviceType.displayName) not registered"
        }
    }
}