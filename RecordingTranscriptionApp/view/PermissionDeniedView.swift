import SwiftUI

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 被拒绝图标
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            // 标题
            Text("Microphone Permission Denied")
                .font(.title2)
                .fontWeight(.bold)
            
            // 说明文字
            Text("Please go to Settings > Privacy & Security > Microphone to enable microphone access for this app")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            // 前往设置按钮
            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

struct PermissionDeniedView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionDeniedView()
    }
} 