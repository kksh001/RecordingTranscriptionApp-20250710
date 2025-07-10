import SwiftUI
import CoreLocation

struct NewRecordingView: View {
    enum RecordingState {
        case idle, recording, paused, finished, optimizingTranscription
    }

    // 测试模式开关 - 用于绕过权限检查测试UI状态
    @State private var isTestMode: Bool = false // 改为false启用真实录制
    
    @State private var recordingState: RecordingState = .idle
    @State private var showFinishAlert = false
    @State private var showTranscriptionView = false
    @State private var transcriptText: String = ""
    @State private var translatedText: String = ""
    @State private var transcriptWordCount: Int = 0
    @StateObject private var permissionManager = MicrophonePermissionManager()
    @StateObject private var audioRecordingManager = AudioRecordingManager()
    @StateObject private var realtimeTranscriptionManager = RealTimeTranscriptionManager()
    @EnvironmentObject var sessionManager: RecordingSessionManager
    
    // 错误处理
    @State private var showErrorAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
                // 测试模式指示器
                if isTestMode {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "testtube.2")
                                .foregroundColor(.orange)
                                                    Text("Test Mode - Permission Check Bypassed")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Button("Disable Test Mode") {
                            isTestMode = false
                        }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        // 快速测试按钮
                        HStack(spacing: 8) {
                            Button("Test Optimization") {
                                testOptimizingState()
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                            
                            Button("Test Translation") {
                                testTranslationView()
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                            
                            Button("Reset") {
                                resetRecording()
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                }
                
                // 权限检查 - 测试模式下跳过
                if !isTestMode && !permissionManager.isPermissionGranted {
                    if permissionManager.isPermissionDenied {
                        PermissionDeniedView()
                    } else {
                        MicrophonePermissionView(onPermissionRequested: {
                            permissionManager.requestPermission()
                        })
                    }
                } else {
                    recordingInterface
                }
            }
                    .onAppear {
            permissionManager.checkPermissionStatus()
        }
        .onChange(of: audioRecordingManager.errorMessage) { _, errorMessage in
            if errorMessage != nil {
                showErrorAlert = true
            }
        }
        .alert("Recording Error", isPresented: $showErrorAlert) {
            Button("OK") {
                audioRecordingManager.clearError()
            }
        } message: {
            Text(audioRecordingManager.errorMessage ?? "Unknown error occurred")
        }
    }
    
    private var recordingInterface: some View {
        VStack(spacing: 0) {
            Spacer()
            // 计时器区域
            timerArea
            // 波形图区域
            waveformArea
            // 主按钮区域
            mainButtonArea
            // 辅助按钮区域
            auxiliaryButtonArea
            Spacer()
        }
        .padding(.horizontal)
        .overlay(transcriptionOverlay)
        .navigationTitle("New Recording")
        .alert(isPresented: $showFinishAlert, content: finishAlert)
        .overlay(optimizationOverlay)
        .sheet(isPresented: $showTranscriptionView, content: transcriptionSheet)
    }
    
    @ViewBuilder
    private var timerArea: some View {
        Group {
            if recordingState != .idle {
                Text(audioRecordingManager.formatDuration(audioRecordingManager.currentRecordingDuration))
                    .font(.largeTitle)
                    .monospacedDigit()
                    .frame(height: 40)
            } else {
                Color.clear.frame(height: 40)
            }
        }
        .padding(.bottom, 32)
    }
    
    @ViewBuilder
    private var waveformArea: some View {
        Group {
            if recordingState == .recording {
                RealTimeWaveformView(
                    audioLevels: audioRecordingManager.audioLevels,
                    isRecording: audioRecordingManager.isRecording && !audioRecordingManager.isPaused
                )
                .frame(height: 40)
                .padding(.horizontal)
            } else if recordingState == .paused {
                StaticWaveformView()
                    .frame(height: 40)
                    .padding(.horizontal)
            } else {
                Color.clear.frame(height: 40)
                    .padding(.horizontal)
            }
        }
        .padding(.bottom, 32)
    }
    
    @ViewBuilder
    private var mainButtonArea: some View {
        ZStack {
            Button(action: {
                handleRecordingButton()
            }) {
            ZStack {
                Circle()
                        .fill(buttonColor)
                        .frame(width: 88, height: 88)
                    Image(systemName: buttonIcon)
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                }
            }
            .disabled(recordingState == .finished)
        }
        .frame(height: 100)
        .padding(.bottom, 32)
    }
    
    private var buttonColor: Color {
        switch recordingState {
        case .recording: return .red
        case .paused: return .orange
        case .finished: return .green
        default: return .blue
        }
    }
    
    private var buttonIcon: String {
        switch recordingState {
        case .recording: return "pause.circle.fill"
        case .paused: return "play.circle.fill"
        case .finished: return "checkmark.circle.fill"
        default: return "mic.circle.fill"
        }
    }
    
    @ViewBuilder
    private var auxiliaryButtonArea: some View {
        Group {
            if recordingState == .recording || recordingState == .paused {
                Button(action: {
                    finishRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 72, height: 72)
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                    }
                }
            } else if recordingState == .finished {
                Button(action: {
                    resetRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 72, height: 72)
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Color.clear.frame(width: 72, height: 72)
            }
        }
        .frame(height: 80)
    }
    
    @ViewBuilder
    private var transcriptionOverlay: some View {
        VStack {
            if recordingState == .recording || recordingState == .paused {
                transcriptionStatusArea
            }
            
            Spacer()
            
            transcriptionIndicator
        }
    }
    
    @ViewBuilder
    private var transcriptionStatusArea: some View {
        VStack(spacing: 8) {
            if !realtimeTranscriptionManager.currentTranscript.isEmpty {
                Text(realtimeTranscriptionManager.currentTranscript)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            if realtimeTranscriptionManager.isTranscribing {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.5)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: realtimeTranscriptionManager.isTranscribing)
                    Text("Transcribing...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private var transcriptionIndicator: some View {
        HStack {
            Spacer()
            TranscriptionStatusIndicator(
                recordingState: recordingState,
                transcriptWordCount: realtimeTranscriptionManager.realtimeSegments.count,
                action: {
                    switch recordingState {
                    case .recording, .paused:
                        showTranscriptionView = true
                    case .finished:
                        if !sessionManager.sessions.isEmpty {
                            showTranscriptionView = true
                        }
                    case .idle, .optimizingTranscription:
                        break
                    }
                }
            )
            .padding(.trailing, 24)
            .padding(.bottom, 32)
        }
    }
    
    private func finishAlert() -> Alert {
        Alert(
            title: Text("Recording Finished"),
            message: Text("Do you want to confirm and save the recording?"),
            primaryButton: .default(Text("Confirm & Save"), action: {
                print("🚨 Alert Confirm & Save button pressed!")
                saveRecording()
            }),
            secondaryButton: .cancel(Text("Continue Editing"), action: {
                print("🚨 Alert Continue Editing button pressed!")
            })
        )
    }
    
    @ViewBuilder
    private var optimizationOverlay: some View {
        Group {
            if recordingState == .optimizingTranscription {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.blue)
                        
                        Text("Optimizing Transcription...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Almost done")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
            }
        }
    }
    
    @ViewBuilder
    private func transcriptionSheet() -> some View {
        switch recordingState {
        case .recording, .paused:
            RealTimeTranscriptionView(manager: realtimeTranscriptionManager)
        case .finished:
            if let latestSession = sessionManager.sessions.first {
                RecordingPlaybackView(
                    recordingName: latestSession.name,
                    audioURL: URL(fileURLWithPath: latestSession.filePath),
                    sessionId: latestSession.id
                )
                .environmentObject(sessionManager)
            } else {
                TranscriptionTranslationView(
                    transcriptText: transcriptText,
                    translatedText: translatedText
                )
            }
        default:
            Text("No transcription available")
                .foregroundColor(.secondary)
        }
    }

    private var buttonTitle: String {
        switch recordingState {
        case .idle: return "Start Recording"
        case .recording: return "Pause Recording"
        case .paused: return "Resume Recording"
        case .finished: return "Finished"
        case .optimizingTranscription: return "Processing..."
        }
    }

    private func handleRecordingButton() {
        switch recordingState {
        case .idle:
            startRecording()
        case .recording:
            pauseRecording()
        case .paused:
            resumeRecording()
        case .finished:
            break
        case .optimizingTranscription:
            break // 优化过程中不允许操作
        }
    }

    private func startRecording() {
        // 测试模式下跳过权限检查
        if !isTestMode {
            // 再次检查权限
            guard permissionManager.isPermissionGranted else {
                permissionManager.checkPermissionStatus()
                return
            }
        }
        
        // 启动真实录制
        audioRecordingManager.startRecording()
        recordingState = .recording
        
        // 启动实时转写
        Task {
            do {
                try await realtimeTranscriptionManager.startRealTimeTranscription()
                print("✅ Real-time transcription started with recording")
            } catch {
                print("❌ Failed to start real-time transcription: \(error)")
            }
        }
    }

    private func pauseRecording() {
        audioRecordingManager.pauseRecording()
        recordingState = .paused
        
        // 暂停实时转写
        realtimeTranscriptionManager.pauseRealTimeTranscription()
    }

    private func resumeRecording() {
        audioRecordingManager.resumeRecording()
        recordingState = .recording
        
        // 恢复实时转写
        do {
            try realtimeTranscriptionManager.resumeRealTimeTranscription()
        } catch {
            print("❌ Failed to resume real-time transcription: \(error)")
        }
    }

    private func finishRecording() {
        print("🛑 finishRecording() called")
        audioRecordingManager.stopRecording()
        recordingState = .optimizingTranscription
        
        // 停止实时转写
        realtimeTranscriptionManager.stopRealTimeTranscription()
        
        // 模拟转写优化过程 (2-3秒)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            print("🎯 Setting recordingState to .finished and showing alert")
            recordingState = .finished
            showFinishAlert = true
        }
    }

    private func resetRecording() {
        // 如果正在录制，先停止
        if audioRecordingManager.isRecording {
            audioRecordingManager.stopRecording()
        }
        
        recordingState = .idle
        showFinishAlert = false
    }
    
    private func saveRecording() {
        // 获取录音信息进行调试
        let recordingInfo = audioRecordingManager.getCurrentRecordingInfo()
        print("🎙️ Saving recording:")
        print("   URL: \(recordingInfo.url?.absoluteString ?? "nil")")
        print("   Name: \(recordingInfo.name)")
        print("   Duration: \(recordingInfo.duration)")
        
        // 检查是否有实时转写数据
        let hasRealtimeData = !realtimeTranscriptionManager.realtimeSegments.isEmpty
        print("🔄 Real-time transcription data: \(hasRealtimeData ? "Available (\(realtimeTranscriptionManager.realtimeSegments.count) segments)" : "None")")
        
        if hasRealtimeData {
            // 使用实时转写数据保存会话
            let realtimeSegments = realtimeTranscriptionManager.exportRealtimeSegments()
            sessionManager.addSessionWithRealTimeTranscription(
                from: audioRecordingManager,
                realtimeSegments: realtimeSegments
            )
            print("✅ Session saved with real-time transcription data")
        } else {
            // 使用传统方式保存
            if recordingInfo.url == nil {
                print("⚠️ No recording URL found, creating test session")
                let testSession = RecordingSession(
                    name: "Test Recording \(Date().timeIntervalSince1970)",
                    duration: recordingInfo.duration > 0 ? recordingInfo.duration : 8.0,
                    date: Date(),
                    fileSize: "1.2 MB",
                    sessionStatus: .completed,
                    sourceLanguage: "English",
                    targetLanguage: "Chinese",
                    hasTranslation: false,
                    priority: .normal,
                    sessionType: .memo,
                    filePath: "/test/path/recording.m4a",
                    wordCount: Int(recordingInfo.duration * 2.5),
                    transcriptionQuality: .good
                )
                sessionManager.sessions.insert(testSession, at: 0)
                print("✅ Test session added. Total sessions: \(sessionManager.sessions.count)")
            } else {
                // 保存录音到会话管理器
                sessionManager.addSession(from: audioRecordingManager)
                print("✅ Session saved with traditional method")
            }
        }
        
        print("📝 Sessions count after adding: \(sessionManager.sessions.count)")
        
        // 重置录音状态并清空实时转写数据（因为已经保存）
        resetRecording()
        realtimeTranscriptionManager.clearSegments() // 清空已保存的数据
        
        // 显示保存成功的反馈（可选）
        // 这里可以添加一个Toast消息或者其他UI反馈
    }


    
    // MARK: - 测试函数
    private func testOptimizingState() {
        // 模拟录音过程
        startRecording()
        
        // 2秒后进入优化状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            finishRecording()
        }
    }
    
    private func testTranslationView() {
        // 直接跳转到转写翻译界面
        recordingState = .finished
        showTranscriptionView = true
    }
    
    private func testSaveRecording() {
        // 直接测试保存功能
        saveRecording()
    }
}



// MARK: - 实时转写状态指示器组件
struct TranscriptionStatusIndicator: View {
    let recordingState: NewRecordingView.RecordingState
    let transcriptWordCount: Int
    let action: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 背景圆形
                Circle()
                    .fill(statusColor)
                    .frame(width: 56, height: 56)
                    .scaleEffect(isAnimating && recordingState == .recording ? 1.1 : 1.0)
                    .animation(
                        recordingState == .recording ? 
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : 
                        .easeInOut(duration: 0.3),
                        value: isAnimating
                    )
                
                // 状态图标
                Image(systemName: statusIcon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                
                // 修复的徽章数字 - 使用overlay而非VStack嵌套
                if shouldShowBadge {
                    Text("\(transcriptWordCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 20, y: -20)  // 相对于Circle的偏移
                }
            }
        }
        .onChange(of: recordingState) { _, newState in
            withAnimation {
                isAnimating = newState == .recording
            }
        }
        .onAppear {
            isAnimating = recordingState == .recording
        }
    }
    
    private var statusColor: Color {
        switch recordingState {
        case .idle, .finished:
            return .blue
        case .recording:
            return .green
        case .paused:
            return .yellow
        case .optimizingTranscription:
            return .orange
        }
    }
    
    private var statusIcon: String {
        switch recordingState {
        case .idle, .finished:
            return "doc.text"
        case .recording:
            return "waveform.and.mic"
        case .paused:
            return "pause.circle"
        case .optimizingTranscription:
            return "gearshape.2"
        }
    }
    
    private var shouldShowBadge: Bool {
        return recordingState == .recording || recordingState == .paused
    }
}

struct NewRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 默认状态
        NewRecordingView()
                .previewDisplayName("Default State")
            
            // 状态指示器预览 - 不同状态
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    TranscriptionStatusIndicator(
                        recordingState: .idle,
                        transcriptWordCount: 0,
                        action: {}
                    )
                    Text("Idle (Blue)")
                }
                
                HStack(spacing: 20) {
                    TranscriptionStatusIndicator(
                        recordingState: .recording,
                        transcriptWordCount: 42,
                        action: {}
                    )
                    Text("Recording (Green)")
                }
                
                HStack(spacing: 20) {
                    TranscriptionStatusIndicator(
                        recordingState: .paused,
                        transcriptWordCount: 28,
                        action: {}
                    )
                    Text("Paused (Yellow)")
                }
                
                HStack(spacing: 20) {
                    TranscriptionStatusIndicator(
                        recordingState: .finished,
                        transcriptWordCount: 0,
                        action: {}
                    )
                    Text("Finished (Blue)")
                }
            }
            .padding()
            .previewDisplayName("Status Indicators")
        }
    }
} 
