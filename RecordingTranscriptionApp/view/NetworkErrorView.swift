import SwiftUI

struct NetworkErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    let onCancel: (() -> Void)?
    
    init(errorMessage: String = "Network connection failed", onRetry: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 网络错误图标
            Image(systemName: "wifi.slash")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            // 错误标题
            Text("Connection Failed")
                .font(.title2)
                .fontWeight(.bold)
            
            // 错误详情
            Text(errorMessage)
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
                        Text("Retry")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                // 取消按钮（可选）
                if let onCancel = onCancel {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
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

struct NetworkErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NetworkErrorView(
                errorMessage: "Unable to connect to transcription service. Please check your internet connection.",
                onRetry: {},
                onCancel: {}
            )
            .previewDisplayName("With Cancel Button")
            
            NetworkErrorView(
                onRetry: {}
            )
            .previewDisplayName("Retry Only")
        }
    }
} 