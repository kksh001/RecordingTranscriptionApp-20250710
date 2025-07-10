import SwiftUI

struct TranscriptionErrorView: View {
    let errorType: TranscriptionErrorType
    let onRetry: () -> Void
    let onCancel: (() -> Void)?
    
    enum TranscriptionErrorType {
        case serviceUnavailable
        case audioQualityPoor
        case languageDetectionFailed
        case quotaExceeded
        case processingTimeout
        
        var title: String {
            switch self {
            case .serviceUnavailable:
                return "Service Unavailable"
            case .audioQualityPoor:
                return "Audio Quality Issue"
            case .languageDetectionFailed:
                return "Language Detection Failed"
            case .quotaExceeded:
                return "Service Limit Reached"
            case .processingTimeout:
                return "Processing Timeout"
            }
        }
        
        var message: String {
            switch self {
            case .serviceUnavailable:
                return "The transcription service is currently unavailable. Please try again later."
            case .audioQualityPoor:
                return "The audio quality is too poor for accurate transcription. Please try recording in a quieter environment."
            case .languageDetectionFailed:
                return "Unable to detect the language in your recording. Please try speaking more clearly or select the language manually."
            case .quotaExceeded:
                return "You have reached the daily transcription limit. Please try again tomorrow or upgrade your plan."
            case .processingTimeout:
                return "The transcription is taking longer than expected. Please try again with a shorter recording."
            }
        }
        
        var icon: String {
            switch self {
            case .serviceUnavailable:
                return "server.rack"
            case .audioQualityPoor:
                return "waveform.path.badge.minus"
            case .languageDetectionFailed:
                return "globe.badge.chevron.backward"
            case .quotaExceeded:
                return "exclamationmark.triangle"
            case .processingTimeout:
                return "clock.badge.exclamationmark"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .serviceUnavailable, .processingTimeout:
                return .orange
            case .audioQualityPoor, .languageDetectionFailed:
                return .red
            case .quotaExceeded:
                return .purple
            }
        }
    }
    
    init(errorType: TranscriptionErrorType, onRetry: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self.errorType = errorType
        self.onRetry = onRetry
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 错误图标
            Image(systemName: errorType.icon)
                .font(.system(size: 80))
                .foregroundColor(errorType.iconColor)
            
            // 错误标题
            Text(errorType.title)
                .font(.title2)
                .fontWeight(.bold)
            
            // 错误详情
            Text(errorType.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            // 按钮组
            VStack(spacing: 12) {
                // 重试按钮
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(retryButtonText)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(errorType.iconColor)
                    .cornerRadius(12)
                }
                
                // 取消按钮（可选）
                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(errorType.iconColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(errorType.iconColor, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    private var retryButtonText: String {
        switch errorType {
        case .serviceUnavailable, .processingTimeout:
            return "Try Again"
        case .audioQualityPoor:
            return "Record Again"
        case .languageDetectionFailed:
            return "Retry Detection"
        case .quotaExceeded:
            return "Upgrade Plan"
        }
    }
}

struct TranscriptionErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TranscriptionErrorView(
                errorType: .serviceUnavailable,
                onRetry: {},
                onCancel: {}
            )
            .previewDisplayName("Service Unavailable")
            
            TranscriptionErrorView(
                errorType: .audioQualityPoor,
                onRetry: {}
            )
            .previewDisplayName("Audio Quality")
            
            TranscriptionErrorView(
                errorType: .quotaExceeded,
                onRetry: {},
                onCancel: {}
            )
            .previewDisplayName("Quota Exceeded")
        }
    }
} 