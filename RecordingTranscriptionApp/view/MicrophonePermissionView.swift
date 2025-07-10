import SwiftUI

struct MicrophonePermissionView: View {
    let onPermissionRequested: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 麦克风图标
            Image(systemName: "mic.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            // 标题
            Text("Microphone Permission Required")
                .font(.title2)
                .fontWeight(.bold)
            
            // 说明文字
            Text("To record and transcribe your voice, we need access to your microphone")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            // 授权按钮
            Button(action: onPermissionRequested) {
                Text("Allow Microphone Access")
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
}

struct MicrophonePermissionView_Previews: PreviewProvider {
    static var previews: some View {
        MicrophonePermissionView(onPermissionRequested: {})
    }
} 