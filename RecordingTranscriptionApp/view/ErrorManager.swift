import SwiftUI
import Foundation

class ErrorManager: ObservableObject {
    @Published var currentError: AppError?
    @Published var isShowingError: Bool = false
    
    enum AppError: Identifiable {
        case network(NetworkError)
        case transcription(TranscriptionErrorView.TranscriptionErrorType)
        case storage(StorageError)
        case recording(RecordingError)
        
        var id: String {
            switch self {
            case .network(let error):
                return "network_\(error.rawValue)"
            case .transcription(let error):
                return "transcription_\(error)"
            case .storage(let error):
                return "storage_\(error.rawValue)"
            case .recording(let error):
                return "recording_\(error.rawValue)"
            }
        }
    }
    
    enum NetworkError: String, CaseIterable {
        case connectionFailed = "connection_failed"
        case timeout = "timeout"
        case serverError = "server_error"
        case noInternet = "no_internet"
        
        var message: String {
            switch self {
            case .connectionFailed:
                return "Unable to connect to the service. Please check your internet connection."
            case .timeout:
                return "The request timed out. Please try again."
            case .serverError:
                return "Server is experiencing issues. Please try again later."
            case .noInternet:
                return "No internet connection detected. Please check your network settings."
            }
        }
    }
    
    enum StorageError: String, CaseIterable {
        case insufficientSpace = "insufficient_space"
        case saveFailed = "save_failed"
        case fileCorrupted = "file_corrupted"
        
        var message: String {
            switch self {
            case .insufficientSpace:
                return "Not enough storage space available. Please free up some space and try again."
            case .saveFailed:
                return "Failed to save the recording. Please try again."
            case .fileCorrupted:
                return "The recording file appears to be corrupted. Please record again."
            }
        }
    }
    
    enum RecordingError: String, CaseIterable {
        case deviceUnavailable = "device_unavailable"
        case audioSessionFailed = "audio_session_failed"
        case recordingInterrupted = "recording_interrupted"
        
        var message: String {
            switch self {
            case .deviceUnavailable:
                return "Microphone is not available. Please check your device settings."
            case .audioSessionFailed:
                return "Failed to initialize audio session. Please restart the app."
            case .recordingInterrupted:
                return "Recording was interrupted. Please try again."
            }
        }
    }
    
    func showError(_ error: AppError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.isShowingError = true
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.isShowingError = false
        }
    }
    
    // 便捷方法
    func showNetworkError(_ error: NetworkError) {
        showError(.network(error))
    }
    
    func showTranscriptionError(_ error: TranscriptionErrorView.TranscriptionErrorType) {
        showError(.transcription(error))
    }
    
    func showStorageError(_ error: StorageError) {
        showError(.storage(error))
    }
    
    func showRecordingError(_ error: RecordingError) {
        showError(.recording(error))
    }
}

// MARK: - Error Display View
struct ErrorDisplayView: View {
    let error: ErrorManager.AppError
    let onRetry: () -> Void
    let onCancel: (() -> Void)?
    
    var body: some View {
        Group {
            switch error {
            case .network(let networkError):
                NetworkErrorView(
                    errorMessage: networkError.message,
                    onRetry: onRetry,
                    onCancel: onCancel
                )
            case .transcription(let transcriptionError):
                TranscriptionErrorView(
                    errorType: transcriptionError,
                    onRetry: onRetry,
                    onCancel: onCancel
                )
            case .storage(let storageError):
                GenericErrorView(
                    title: "Storage Error",
                    message: storageError.message,
                    icon: "externaldrive.badge.exclamationmark",
                    iconColor: .orange,
                    onRetry: onRetry,
                    onCancel: onCancel
                )
            case .recording(let recordingError):
                GenericErrorView(
                    title: "Recording Error",
                    message: recordingError.message,
                    icon: "mic.slash.fill",
                    iconColor: .red,
                    onRetry: onRetry,
                    onCancel: onCancel
                )
            }
        }
    }
}

// MARK: - Generic Error View
struct GenericErrorView: View {
    let title: String
    let message: String
    let icon: String
    let iconColor: Color
    let onRetry: () -> Void
    let onCancel: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 错误图标
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(iconColor)
            
            // 错误标题
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            // 错误详情
            Text(message)
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
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(iconColor)
                    .cornerRadius(12)
                }
                
                // 取消按钮（可选）
                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(iconColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(iconColor, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
} 