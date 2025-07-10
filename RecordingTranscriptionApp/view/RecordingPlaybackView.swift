import SwiftUI
import AVFoundation

// MARK: - 数据模型
// 注意：PlaybackSegment 现在在 RecordingSessionManager.swift 中定义，支持完整的编辑功能

// MARK: - 音频播放管理器
class AudioPlaybackManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var playbackRate: Float = 1.0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func loadAudio(from url: URL) {
        do {
            // 检查文件是否存在
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            print("🎵 Loading audio from: \(url.path)")
            print("🎵 File exists: \(fileExists)")
            
            if fileExists {
                let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
                print("🎵 File size: \(fileSize) bytes")
                
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                duration = audioPlayer?.duration ?? 0
                print("🎵 Audio duration: \(duration) seconds")
                
                // 在模拟器中设置音频会话
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                
            } else {
                print("⚠️ Audio file not found, creating simulated playback")
                // 文件不存在，创建模拟播放
                audioPlayer = nil
                // 从文件名推断时长，或使用默认值
                if url.path.contains("Recording_") {
                    // 尝试从录音名称推断时长
                    duration = 10.0 // 默认10秒
                } else {
                    duration = 30.0 // 默认30秒
                }
                print("🎵 Simulated duration: \(duration) seconds")
            }
            
        } catch {
            print("❌ Failed to load audio: \(error)")
            // 为演示目的，设置一个模拟的时长
            audioPlayer = nil
            duration = 30.0
            print("🎵 Fallback to simulated duration: \(duration) seconds")
        }
    }
    
    func play() {
        if let player = audioPlayer {
            print("🎵 Starting real audio playback...")
            print("🎵 Player volume: \(player.volume)")
            print("🎵 Player is playing: \(player.isPlaying)")
            let success = player.play()
            print("🎵 Play command success: \(success)")
        } else {
            print("🎵 Starting simulated playback (no audio file)")
            // 没有真实的音频播放器，但我们仍然可以模拟播放进度
        }
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        if let player = audioPlayer {
            player.currentTime = 0
        }
        currentTime = 0
        isPlaying = false
        stopTimer()
    }
    
    func seek(to time: Double) {
        if let player = audioPlayer {
            player.currentTime = time
        }
        currentTime = time
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = self.audioPlayer {
                self.currentTime = player.currentTime
            } else {
                // 模拟播放进度
                self.currentTime += 0.1
            }
            
            // 检查是否播放结束
            if self.currentTime >= self.duration {
                self.stop()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 同步管理器
class SyncManager: ObservableObject {
    @Published var currentSegmentIndex: Int = 0
    @Published var highlightedSegment: UUID?
    @Published var scrollSyncEnabled = true // 防止无限循环的标志位
    
    func findCurrentSegment(for time: Double, in segments: [PlaybackSegment]) -> Int {
        for (index, segment) in segments.enumerated() {
            if time >= segment.startTime && time <= segment.endTime {
                return index
            }
        }
        return 0
    }
    
    func updateHighlight(for time: Double, in segments: [PlaybackSegment]) {
        let index = findCurrentSegment(for: time, in: segments)
        currentSegmentIndex = index
        if index < segments.count {
            highlightedSegment = segments[index].id
        }
    }
    
    // 智能音频跳转（3秒Buffer）
    func jumpToSegmentWithBuffer(_ segment: PlaybackSegment, audioManager: AudioPlaybackManager) {
        let bufferTime: Double = 3.0
        let targetTime = max(0, segment.startTime - bufferTime)
        audioManager.seek(to: targetTime)
        updateHighlight(for: targetTime, in: [segment]) // 临时传入单个segment，实际使用时需要完整segments数组
    }
    
    // 临时禁用滚动同步，防止无限循环
    func temporarilyDisableScrollSync() {
        scrollSyncEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.scrollSyncEnabled = true
        }
    }
}

// MARK: - 编辑状态管理
class EditingManager: ObservableObject {
    @Published var editingSegmentId: UUID?
    @Published var tempEditText = ""
    @Published var editingFieldType: EditFieldType = .transcription
    @Published var hasUnsavedChanges = false
    
    func startEditing(segmentId: UUID, currentText: String, fieldType: EditFieldType) {
        editingSegmentId = segmentId
        tempEditText = currentText
        editingFieldType = fieldType
    }
    
    func cancelEditing() {
        editingSegmentId = nil
        tempEditText = ""
    }
    
    func confirmEdit() -> (segmentId: UUID, newText: String, fieldType: EditFieldType)? {
        guard let segmentId = editingSegmentId, !tempEditText.isEmpty else { return nil }
        let result = (segmentId: segmentId, newText: tempEditText, fieldType: editingFieldType)
        cancelEditing()
        hasUnsavedChanges = true
        return result
    }
}

// MARK: - 主视图
struct RecordingPlaybackView: View {
    let recordingName: String
    let audioURL: URL
    let sessionId: UUID  // 新增：会话ID用于数据更新
    
    @State private var segments: [PlaybackSegment] = []
    @StateObject private var audioManager = AudioPlaybackManager()
    @StateObject private var syncManager = SyncManager()
    @StateObject private var editingManager = EditingManager()  // 新增：编辑管理器
    @EnvironmentObject var sessionManager: RecordingSessionManager  // 新增：会话管理器
    
    @State private var showSaveAlert = false
    @State private var retranslatingSegmentId: UUID? // 正在重新翻译的段落ID
    
    // 滚动同步状态
    @State private var isUserScrollingTranscription = false
    @State private var isUserScrollingTranslation = false
    @State private var lastScrollSource: ScrollSource = .none
    @State private var transcriptionScrollAction: ((String) -> Void)? = nil
    @State private var translationScrollAction: ((String) -> Void)? = nil
    
    enum ScrollSource {
        case none, audio, transcription, translation
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 音频播放控制区域
            audioControlSection
            
            Divider()
            
            // MARK: - 同步内容显示区域
            contentDisplaySection
        }
        .navigationTitle(recordingName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupAudio()
            loadMockData()
        }
        .alert("Save Changes", isPresented: $showSaveAlert) {
            Button("Save") { saveChanges() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Do you want to save them?")
        }
    }
    
    // MARK: - 音频播放控制区域
    private var audioControlSection: some View {
        VStack(spacing: 16) {
            // 时间信息
            Text("\(formatTime(audioManager.currentTime)) / \(formatTime(audioManager.duration))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 进度条
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { audioManager.currentTime },
                        set: { newValue in
                            audioManager.seek(to: newValue)
                            syncManager.updateHighlight(for: newValue, in: segments)
                        }
                    ),
                    in: 0...audioManager.duration
                )
                .accentColor(.blue)
                
                // 播放控制按钮
                HStack(spacing: 24) {
                    // 快退10秒
                    Button(action: {
                        let newTime = max(0, audioManager.currentTime - 10)
                        audioManager.seek(to: newTime)
                        syncManager.updateHighlight(for: newTime, in: segments)
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    // 播放/暂停
                    Button(action: {
                        if audioManager.isPlaying {
                            audioManager.pause()
                        } else {
                            audioManager.play()
                        }
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }
                    
                    // 快进10秒
                    Button(action: {
                        let newTime = min(audioManager.duration, audioManager.currentTime + 10)
                        audioManager.seek(to: newTime)
                        syncManager.updateHighlight(for: newTime, in: segments)
                    }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    // 停止
                    Button(action: {
                        audioManager.stop()
                        syncManager.updateHighlight(for: 0, in: segments)
                    }) {
                        Image(systemName: "stop.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .onChange(of: audioManager.currentTime) { _, newTime in
            lastScrollSource = .audio
            syncManager.updateHighlight(for: newTime, in: segments)
        }
    }
    
    // MARK: - 同步内容显示区域
    private var contentDisplaySection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(segments) { segment in
                        integratedSegmentView(segment: segment)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .onAppear {
                transcriptionScrollAction = { segmentId in
                    proxy.scrollTo(segmentId, anchor: .center)
                }
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in
                        isUserScrollingTranscription = true
                        lastScrollSource = .transcription
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isUserScrollingTranscription = false
                        }
                    }
            )
            .onChange(of: syncManager.highlightedSegment) { _, segmentId in
                if let segmentId = segmentId, lastScrollSource == .audio || lastScrollSource == .none {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        transcriptionScrollAction?(segmentId.uuidString)
                    }
                }
            }
        }
    }
    
    // MARK: - 整合段落视图（转写+翻译）
    private func integratedSegmentView(segment: PlaybackSegment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 时间戳
            Text("\(formatTime(segment.startTime)) - \(formatTime(segment.endTime))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 转写内容
            if editingManager.editingSegmentId == segment.id && editingManager.editingFieldType == .transcription {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $editingManager.tempEditText)
                        .frame(minHeight: 80)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .background(Color.blue.opacity(0.05))
                    
                    HStack {
                        Button("Cancel") {
                            editingManager.cancelEditing()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.secondary)
                        .cornerRadius(6)
                        
                        Spacer()
                        
                        Button("Save") {
                            handleEditConfirmation()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                        .cornerRadius(6)
                    }
                    .font(.subheadline)
                }
            } else {
                Text(segment.currentTranscription)
                    .font(.body)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .foregroundColor(syncManager.highlightedSegment == segment.id ? .primary : .primary)
                    .background(
                        syncManager.highlightedSegment == segment.id ?
                        Color.blue.opacity(0.15) : (segment.hasEdits ? Color.orange.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        segment.hasEdits ? 
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 3)
                            .frame(maxHeight: .infinity)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        : nil
                    )
                    .cornerRadius(6)
                    .onTapGesture {
                        editingManager.startEditing(
                            segmentId: segment.id,
                            currentText: segment.currentTranscription,
                            fieldType: .transcription
                        )
                    }
                    .onLongPressGesture {
                        let bufferTime: Double = 3.0
                        let targetTime = max(0, segment.startTime - bufferTime)
                        audioManager.seek(to: targetTime)
                        syncManager.updateHighlight(for: targetTime, in: segments)
                        lastScrollSource = .audio
                    }
            }
            
            // 翻译内容
            if editingManager.editingSegmentId == segment.id && editingManager.editingFieldType == .translation {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $editingManager.tempEditText)
                        .frame(minHeight: 80)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 2)
                        )
                        .background(Color.green.opacity(0.05))
                    
                    HStack {
                        Button("Cancel") {
                            editingManager.cancelEditing()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.secondary)
                        .cornerRadius(6)
                        
                        Spacer()
                        
                        Button("Save") {
                            handleEditConfirmation()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                        .cornerRadius(6)
                    }
                    .font(.subheadline)
                }
            } else {
                let translationText = segment.translation.isEmpty ? "翻译生成中..." : segment.translation
                Text(translationText)
                    .font(.body)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .foregroundColor(.secondary)
                    .background(
                        syncManager.highlightedSegment == segment.id ?
                        Color.green.opacity(0.15) : Color.clear
                    )
                    .cornerRadius(6)
                    .onTapGesture {
                        editingManager.startEditing(
                            segmentId: segment.id,
                            currentText: translationText,
                            fieldType: .translation
                        )
                    }
                    .onLongPressGesture {
                        let bufferTime: Double = 3.0
                        let targetTime = max(0, segment.startTime - bufferTime)
                        audioManager.seek(to: targetTime)
                        syncManager.updateHighlight(for: targetTime, in: segments)
                        lastScrollSource = .audio
                    }
            }
        }
        .id(segment.id)
        .padding(.vertical, 4)
    }
    
    // MARK: - 辅助方法
    private func setupAudio() {
        audioManager.loadAudio(from: audioURL)
    }
    
    private func loadMockData() {
        // 从会话管理器加载段落数据
        if let session = sessionManager.sessions.first(where: { $0.id == sessionId }) {
            segments = session.segments
            print("📱 Loaded \(segments.count) segments from session manager")
        } else {
            // 尝试从RealTimeTranscriptionManager加载实际录音数据
            let realtimeManager = RealTimeTranscriptionManager()
            let realtimeSegments = realtimeManager.exportRealtimeSegments()
            
            if !realtimeSegments.isEmpty {
                segments = realtimeSegments
                print("📱 Loaded \(segments.count) segments from realtime transcription")
                
                // 确保每个段落都有翻译，如果没有则生成
                for i in 0..<segments.count {
                    if segments[i].translation.isEmpty {
                        // 异步生成翻译
                        generateTranslationForHistorySegment(segments[i].transcription) { translation in
                            DispatchQueue.main.async {
                                if i < self.segments.count {
                                    self.segments[i].translation = translation
                                    print("📝 Generated translation for segment \(i+1): \(translation)")
                                }
                            }
                        }
                        print("📝 Started generating translation for segment \(i+1)")
                    }
                }
                print("📝 All segments now have translations")
            } else {
                // 如果没有找到实际数据，创建示例数据
                segments = createMockSegments()
                print("📱 No actual data found, using mock segments")
            }
        }
    }
    
    // 为历史记录段落生成翻译
    private func generateTranslationForHistorySegment(_ text: String, completion: @escaping (String) -> Void) {
        // 检查API Key是否配置
        guard APIKeyManager.shared.hasQianwenKey else {
            completion("Please configure Qianwen API key in Settings")
            return
        }
        
        // 检查文本是否为空
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completion("")
            return
        }
        
        // 检测语言并翻译
        Task {
            do {
                let sourceLanguage = QianwenTranslateManager.shared.detectLanguage(text)
                let targetLanguage = sourceLanguage == "zh" ? "en" : "zh"
                
                let translation = try await QianwenTranslateManager.shared.translateText(
                    text,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                await MainActor.run {
                    completion(translation)
                }
            } catch {
                await MainActor.run {
                    completion("Translation failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func createMockSegments() -> [PlaybackSegment] {
        return [
            PlaybackSegment(
                startTime: 0,
                endTime: 5,
                transcription: "Hello, welcome to today's meeting. Let's start with the agenda.",
                translation: "Hello, welcome to today's meeting. Let's start with the agenda."
            ),
            PlaybackSegment(
                startTime: 5,
                endTime: 12,
                transcription: "First item on the agenda is the quarterly review of our project progress.",
                translation: "The first item on the agenda is our quarterly project progress review."
            ),
            PlaybackSegment(
                startTime: 12,
                endTime: 18,
                transcription: "We have made significant progress in the development phase.",
                translation: "We have made significant progress in the development phase."
            ),
            PlaybackSegment(
                startTime: 18,
                endTime: 25,
                transcription: "The team has been working hard to meet all the deadlines.",
                translation: "The team has been working hard to meet all the deadlines."
            ),
            PlaybackSegment(
                startTime: 25,
                endTime: 30,
                transcription: "Let's discuss the next steps and upcoming milestones.",
                translation: "Let's discuss the next steps and upcoming milestones."
            )
        ]
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - 编辑功能方法
    
    private func handleEditConfirmation() {
        guard let editInfo = editingManager.confirmEdit() else { return }
        
        if let index = segments.firstIndex(where: { $0.id == editInfo.segmentId }) {
            var updatedSegment = segments[index]
            
            switch editInfo.fieldType {
            case .transcription:
                updatedSegment.updateTranscription(editInfo.newText, reason: "Manual edit")
            case .translation:
                updatedSegment.updateTranslation(editInfo.newText, reason: "Manual edit")
            }
            
            segments[index] = updatedSegment
            
            // 更新会话管理器中的数据
            sessionManager.updateSegment(
                sessionId: sessionId,
                segmentId: editInfo.segmentId,
                updatedSegment: updatedSegment
            )
        }
    }
    
    // MARK: - 重新翻译功能（Mock版本）
    private func retranslateSegment(_ segment: PlaybackSegment) {
        guard let index = segments.firstIndex(where: { $0.id == segment.id }) else { return }
        
        // 开始重新翻译状态
        retranslatingSegmentId = segment.id
        
        // Mock翻译过程 - 3秒后显示新的翻译结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let mockTranslations = [
                "This is the retranslated result - more accurate translation content.",
                "Optimized translation: more contextually appropriate expression.",
                "Smart retranslation: new translation based on edited content.",
                "Improved translation version: more natural language expression."
            ]
            
            var updatedSegment = segments[index]
            updatedSegment.updateTranslation(
                mockTranslations.randomElement() ?? "Retranslation completed",
                reason: "Automatic retranslation"
            )
            
            segments[index] = updatedSegment
            retranslatingSegmentId = nil
            
            // 更新会话管理器
            sessionManager.updateSegment(
                sessionId: sessionId,
                segmentId: segment.id,
                updatedSegment: updatedSegment
            )
        }
    }
    
    private func saveChanges() {
        // 批量保存所有段落到会话管理器
        sessionManager.updateSegments(sessionId: sessionId, segments: segments)
        sessionManager.markSessionSaved(sessionId: sessionId)
        editingManager.hasUnsavedChanges = false
        print("✅ Changes saved to session manager")
    }
}

// MARK: - 预览
struct RecordingPlaybackView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RecordingPlaybackView(
                recordingName: "Team Meeting - Q4 Review",
                audioURL: URL(fileURLWithPath: "/path/to/audio.m4a"),
                sessionId: UUID()
            )
            .environmentObject(RecordingSessionManager())
        }
    }
} 