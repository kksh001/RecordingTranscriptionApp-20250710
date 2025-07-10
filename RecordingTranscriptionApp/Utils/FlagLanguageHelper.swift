import Foundation

/// 语言显示帮助器 - 提供语言代码和显示名称
struct FlagLanguageHelper {
    
    /// 获取语言的超紧凑显示（仅代码）
    static func getUltraCompactDisplay(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "en", "english":
            return "EN"
        case "zh", "chinese":
            return "中"
        case "es", "spanish":
            return "ES"
        case "fr", "french":
            return "FR"
        case "de", "german":
            return "DE"
        case "ja", "japanese":
            return "JP"
        case "ko", "korean":
            return "KR"
        case "pt", "portuguese":
            return "PT"
        case "ru", "russian":
            return "RU"
        case "ar", "arabic":
            return "AR"
        case "auto":
            return "Auto"
        default:
            return languageCode.uppercased()
        }
    }
    
    /// 获取语言的紧凑显示（与超紧凑显示相同）
    static func getCompactDisplay(for languageCode: String) -> String {
        return getUltraCompactDisplay(for: languageCode)
    }
    
    /// 获取语言的完整显示名称
    static func getFullDisplayName(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "en", "english":
            return "English"
        case "zh", "chinese":
            return "中文"
        case "es", "spanish":
            return "Español"
        case "fr", "french":
            return "Français"
        case "de", "german":
            return "Deutsch"
        case "ja", "japanese":
            return "日本語"
        case "ko", "korean":
            return "한국어"
        case "pt", "portuguese":
            return "Português"
        case "ru", "russian":
            return "Русский"
        case "ar", "arabic":
            return "العربية"
        case "auto":
            return "Auto Detect"
        default:
            return languageCode.capitalized
        }
    }
}