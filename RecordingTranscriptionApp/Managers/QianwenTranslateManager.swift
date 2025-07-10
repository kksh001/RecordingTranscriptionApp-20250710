import Foundation
import Network

class QianwenTranslateManager: ObservableObject {
    static let shared = QianwenTranslateManager()
    
    private let apiKeyManager = APIKeyManager.shared
    private let baseURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
    
    @Published var isTranslating = false
    @Published var lastError: Error?
    
    private init() {}
    
    // MARK: - Network Check
    private func checkNetworkConnectivity() async {
        // 简化的网络检测
        print("🌐 Checking network connectivity...")
    }
    
    // MARK: - Main Translation Function
    func translateText(_ text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> String {
        let apiKey = await MainActor.run {
            return apiKeyManager.getQianwenAPIKey()
        }
        
        guard let apiKey = apiKey else {
            throw TranslationError.noAPIKey
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyText
        }
        
        DispatchQueue.main.async {
            self.isTranslating = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isTranslating = false
            }
        }
        
        // 检测网络连接
        await checkNetworkConnectivity()
        
        let fromLang = languageDisplayName(sourceLanguage)
        let toLang = languageDisplayName(targetLanguage)
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "qwen-turbo",
            "input": [
                "messages": [
                    [
                        "role": "user",
                        "content": "Please translate the following \(fromLang) text to \(toLang): \(text)"
                    ]
                ]
            ],
            "parameters": [
                "temperature": 0.3,
                "max_tokens": 300,
                "top_p": 0.8
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        print("🌐 Sending translation request to Qianwen API...")
        print("📝 Text to translate: \(text)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 API Response Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                throw TranslationError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let apiResponse = try JSONDecoder().decode(QianwenResponse.self, from: data)
        
        guard let translatedText = apiResponse.output?.text else {
            throw TranslationError.invalidResponse
        }
        
        print("✅ Translation completed: \(translatedText)")
        return translatedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    // MARK: - Context-Aware Translation
    func translateWithContext(_ text: String, context: String = "", from sourceLanguage: String, to targetLanguage: String) async throws -> String {
        let apiKey = await MainActor.run {
            return apiKeyManager.getQianwenAPIKey()
        }
        
        guard let apiKey = apiKey else {
            throw TranslationError.noAPIKey
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyText
        }
        
        DispatchQueue.main.async {
            self.isTranslating = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isTranslating = false
            }
        }
        
        // 检测网络连接
        await checkNetworkConnectivity()
        
        // 构建带上下文的翻译提示
        let contextPrompt = buildContextualPrompt(text: text, context: context, from: sourceLanguage, to: targetLanguage)
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "qwen-turbo",
            "input": [
                "messages": [
                    [
                        "role": "user",
                        "content": contextPrompt
                    ]
                ]
            ],
            "parameters": [
                "temperature": 0.3,  // 降低温度以提高准确性
                "max_tokens": 500,
                "top_p": 0.8
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        print("🌐 Sending contextual translation request to Qianwen API...")
        print("📝 Text to translate: \(text)")
        if !context.isEmpty {
            print("📖 Context: \(context)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 API Response Status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                throw TranslationError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        let apiResponse = try JSONDecoder().decode(QianwenResponse.self, from: data)
        
        guard let translatedText = apiResponse.output?.text else {
            throw TranslationError.invalidResponse
        }
        
        print("✅ Translation completed: \(translatedText)")
        return translatedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    // 构建上下文感知的翻译提示
    private func buildContextualPrompt(text: String, context: String, from sourceLanguage: String, to targetLanguage: String) -> String {
        let fromLang = languageDisplayName(sourceLanguage)
        let toLang = languageDisplayName(targetLanguage)
        
        var prompt = "Please translate the following \(fromLang) text to \(toLang). "
        
        if !context.isEmpty {
            prompt += "Context for better understanding: \(context). "
        }
        
        prompt += "Ensure the translation is natural, accurate, and maintains the original meaning and tone. "
        prompt += "Text to translate: \(text)"
        
        return prompt
    }
    
    // MARK: - Language Detection
    func detectLanguage(_ text: String) -> String {
        // 简化的语言检测逻辑
        if text.range(of: "\\p{Han}", options: .regularExpression) != nil {
            return "zh"
        } else {
            return "en"
        }
    }
    
    // MARK: - Helper Methods
    private func languageDisplayName(_ code: String) -> String {
        switch code {
        case "zh": return "Chinese"
        case "en": return "English"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "ja": return "Japanese"
        default: return "Unknown"
        }
    }
    
    // MARK: - Connectivity Test
    func testConnectivity() async throws -> Bool {
        let apiKey = await MainActor.run {
            return apiKeyManager.getQianwenAPIKey()
        }
        
        guard let _ = apiKey else {
            throw TranslationError.noAPIKey
        }
        
        // 测试简单的翻译请求
        let testText = "Hello"
        _ = try await translateText(testText, from: "en", to: "zh")
        return true
    }
}

// MARK: - Supporting Types
enum TranslationError: Error, LocalizedError {
    case noAPIKey
    case emptyText
    case networkError(String)
    case apiError(String)
    case invalidResponse
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured"
        case .emptyText:
            return "Text is empty"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let message):
            return "API error: \(message)"
        case .invalidResponse:
            return "Invalid response from API"
        case .rateLimited:
            return "Rate limited by API"
        }
    }
}

struct QianwenResponse: Codable {
    let output: QianwenOutput?
    let usage: QianwenUsage?
    let requestId: String?
    
    enum CodingKeys: String, CodingKey {
        case output, usage
        case requestId = "request_id"
    }
}

struct QianwenOutput: Codable {
    let text: String?
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case finishReason = "finish_reason"
    }
}

struct QianwenUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let totalTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
} 