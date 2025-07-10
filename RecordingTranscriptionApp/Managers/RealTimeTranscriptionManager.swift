import Foundation
import AVFoundation
import Speech
import Combine

// MARK: - Real-time Transcription Manager
class RealTimeTranscriptionManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isTranscribing = false
    @Published var isPaused = false
    @Published var currentTranscript = ""
    @Published var realtimeSegments: [RealtimeSegment] = []
    @Published var transcriptionError: String?
    @Published var transcriptionQuality: TranscriptionQuality = .unknown
    @Published var detectedLanguage: String = "en-US"
    @Published var confidence: Float = 0.0
    
    // MARK: - Configuration
    @Published var enableRealTimeTranscription = true
    @Published var transcriptionBufferSize: TimeInterval = 10.0
    @Published var qualityThreshold: Float = 0.7
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    // Timer and state management
    private var transcriptionTimer: Timer?
    private var segmentTimer: Timer?
    private var lastTranscriptionTime = Date()
    private var currentSegmentStartTime = Date()
    private var segmentInterval: TimeInterval = 6.0 // 🔥 增加到6秒 - 减少频繁切分
    private var maxSegmentDuration: TimeInterval = 15.0 // 🔥 增加最大时长到15秒
    private var minSegmentDuration: TimeInterval = 3.0 // 🔥 增加最小时长到3秒 - 避免过短分段
    
    // Language support
    private let supportedLanguages = ["en-US", "zh-CN", "es-ES", "fr-FR", "de-DE", "ja-JP"]
    
    // 语义切分相关
    private var lastTranscriptLength: Int = 0
    private var noChangeCounter: Int = 0
    private var lastSignificantUpdate: Date = Date()
    private var pendingTranscript: String = ""
    
    // 📝 已处理文本位置跟踪
    private var lastProcessedLength: Int = 0
    
    // MARK: - Industry Best Practice: Hybrid Segmentation Strategy
    
    // 配置参数 - 基于Google E2E Segmenter和Meta研究
    private var windowSize: TimeInterval = 10.0 // 主要窗口大小
    private var strideLength: TimeInterval = 2.0 // 重叠步长
    private var minSegmentLength: TimeInterval = 1.5 // 最小段落长度  
    private var maxSegmentLength: TimeInterval = 15.0 // 最大段落长度
    
    // 多信号检测状态
    private var acousticBoundaryDetected: Bool = false
    private var semanticBoundaryDetected: Bool = false
    private var currentWindowBuffer: String = ""
    private var strideBuffer: String = ""
    private var lastBoundaryTime: Date = Date()
    
    // 滑动窗口缓冲区 - 参考Wav2Vec2最佳实践
    private var audioSegmentBuffer: [(text: String, timestamp: Date, confidence: Float)] = []
    private var processingWindow: (start: Date, end: Date)?
    
    override init() {
        super.init()
        setupSpeechRecognition()
    }
    
    deinit {
        stopRealTimeTranscription()
    }
    
    // MARK: - Setup
    private func setupSpeechRecognition() {
        // 初始语言设置为系统语言或英语
        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        let speechLocale = mapToSpeechLocale(locale)
        detectedLanguage = speechLocale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: speechLocale))
        speechRecognizer?.delegate = self
    }
    
    private func mapToSpeechLocale(_ languageCode: String) -> String {
        switch languageCode {
        case "en": return "en-US"
        case "zh": return "zh-CN"
        case "es": return "es-ES"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "ja": return "ja-JP"
        default: return "en-US"
        }
    }
    
    // MARK: - Permission Management
    func requestTranscriptionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    // MARK: - Real-time Transcription Control
    func startRealTimeTranscription() async throws {
        print("🎤 Starting real-time transcription...")
        
        guard enableRealTimeTranscription else { 
            print("❌ Real-time transcription disabled")
            return 
        }
        
        // 检查权限
        let hasPermission = await requestTranscriptionPermission()
        guard hasPermission else {
            DispatchQueue.main.async {
                self.transcriptionError = "Speech recognition permission denied"
                print("❌ Speech recognition permission denied")
            }
            return
        }
        
        // 检查语音识别可用性
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            DispatchQueue.main.async {
                self.transcriptionError = "Speech recognition not available"
                print("❌ Speech recognition not available")
            }
            return
        }
        
        try startAudioEngine()
        setupRecognitionRequest()
        
        DispatchQueue.main.async {
            self.isTranscribing = true
            self.transcriptionError = nil
            self.currentTranscript = ""
            self.currentSegmentStartTime = Date()
            
            // 🔥 重置文本处理状态
            self.lastProcessedLength = 0
            self.lastTranscriptLength = 0
            self.lastSignificantUpdate = Date()
            
            // 重置混合分割状态
            self.acousticBoundaryDetected = false
            self.semanticBoundaryDetected = false
            self.currentWindowBuffer = ""
            self.strideBuffer = ""
            self.lastBoundaryTime = Date()
            self.audioSegmentBuffer.removeAll()
            self.processingWindow = nil
            
            print("✅ Real-time transcription started successfully")
        }
        
        startTranscriptionTimer()
        startSegmentTimer()
    }
    
    func stopRealTimeTranscription() {
        print("🛑 Stopping real-time transcription...")
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        transcriptionTimer?.invalidate()
        segmentTimer?.invalidate()
        
        DispatchQueue.main.async {
            self.isTranscribing = false
            self.isPaused = false
            self.recognitionRequest = nil
            self.recognitionTask = nil
            print("✅ Real-time transcription stopped")
            print("📊 Segments retained: \(self.realtimeSegments.count)")
        }
    }
    
    func pauseRealTimeTranscription() {
        print("⏸️ Pausing real-time transcription...")
        audioEngine.pause()
        transcriptionTimer?.invalidate()
        segmentTimer?.invalidate()
        
        DispatchQueue.main.async {
            self.isTranscribing = false
            self.isPaused = true
        }
    }
    
    func resumeRealTimeTranscription() throws {
        print("▶️ Resuming real-time transcription...")
        try audioEngine.start()
        startTranscriptionTimer()
        startSegmentTimer()
        
        DispatchQueue.main.async {
            self.isTranscribing = true
            self.isPaused = false
        }
    }
    
    // MARK: - Audio Engine Setup
    private func startAudioEngine() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 移除之前的tap（如果存在）
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
            self.processAudioBuffer(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        print("🎵 Audio engine started successfully")
    }
    
    private func setupRecognitionRequest() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // 使用云端识别获得更好质量
        
        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
        }
        
        guard let speechRecognizer = speechRecognizer else { return }
        
        print("🔍 Setting up speech recognition task...")
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self.processTranscriptionResult(result)
                }
                
                if let error = error {
                    print("❌ Speech recognition error: \(error.localizedDescription)")
                    self.transcriptionError = error.localizedDescription
                    // 不要立即停止，允许继续尝试
                }
            }
        }
    }
    
    // MARK: - Audio Processing
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // 简化的音频质量分析
        let audioQuality = analyzeSimpleAudioQuality(buffer)
        
        DispatchQueue.main.async {
            self.updateAudioQualityMetrics(audioQuality)
        }
    }
    
    private func analyzeSimpleAudioQuality(_ buffer: AVAudioPCMBuffer) -> AudioQualityMetrics {
        guard let channelData = buffer.floatChannelData?[0] else {
            return AudioQualityMetrics(signalToNoiseRatio: 0, averageAmplitude: 0, peakAmplitude: 0, spectralCentroid: 0, timestamp: Date())
        }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        var peak: Float = 0
        
        for i in 0..<frameLength {
            let sample = abs(channelData[i])
            sum += sample
            peak = max(peak, sample)
        }
        
        let average = frameLength > 0 ? sum / Float(frameLength) : 0
        let snr = peak > 0 ? 20 * log10(peak / (average + 0.001)) : 0
        
        return AudioQualityMetrics(
            signalToNoiseRatio: snr,
            averageAmplitude: average,
            peakAmplitude: peak,
            spectralCentroid: 0, // 简化实现
            timestamp: Date()
        )
    }
    
    // MARK: - Transcription Processing
    private func processTranscriptionResult(_ result: SFSpeechRecognitionResult) {
        // 🔥 简化：只使用语义切分，禁用混合分割避免冲突
        let transcriptText = result.bestTranscription.formattedString
        currentTranscript = transcriptText
        
        // 更新置信度和质量
        let avgConfidence = result.bestTranscription.segments.map { $0.confidence }.reduce(0, +) / Float(result.bestTranscription.segments.count)
        confidence = avgConfidence
        transcriptionQuality = determineQualityFromConfidence(avgConfidence)
        
        // 🔥 使用改进的语义切分
        checkForSemanticSegmentation(transcriptText, isFinal: result.isFinal)
        
        print("📝 Live transcription: '\(currentTranscript)' (confidence: \(confidence))")
    }
    
    // 智能语义切分检测
    private func checkForSemanticSegmentation(_ currentText: String, isFinal: Bool) {
        let currentLength = currentText.count
        let lengthChanged = currentLength != lastTranscriptLength
        
        if lengthChanged {
            lastSignificantUpdate = Date()
            noChangeCounter = 0
            lastTranscriptLength = currentLength
            
            // 🔥 真正的语义切分：每次文本变化时检查语义完整性
            checkForSemanticCompletion(currentText, isFinal: isFinal)
        } else {
            noChangeCounter += 1
            
            // 辅助：检查停顿后的强制切分
            checkForPauseBasedSegmentation(currentText)
        }
    }
    
    // 语义完整性检测（即时触发，不等待停顿）
    private func checkForSemanticCompletion(_ currentText: String, isFinal: Bool) {
        var shouldCreateSegment = false
        var segmentReason = ""
        
        // 🔥 增加最小内容长度要求 - 避免短语切分
        let minContentLength = 25 // 至少25个字符才考虑切分
        guard currentText.count >= minContentLength else {
            return // 内容太短，不进行切分
        }
        
        // 1. 句子完整性检测（优先级最高，立即触发）
        if detectSentenceEnd(currentText) {
            // 🔥 句子结束也要求足够长度
            if currentText.count >= 15 {
                shouldCreateSegment = true
                segmentReason = "sentence completion (immediate)"
            }
        }
        
        // 2. 语法完整的从句或短语
        else if detectGrammaticalPause(currentText) && currentText.count >= 30 {
            shouldCreateSegment = true
            segmentReason = "grammatical pause"
        }
        
        // 3. SFSpeechRecognizer标记为final（更严格条件）
        else if isFinal && currentText.count >= 20 {
            shouldCreateSegment = true
            segmentReason = "speech recognizer final"
        }
        
        // 4. 语义意义单元检测（要求更长内容）
        else if detectSemanticUnit(currentText) && currentText.count >= 40 {
            shouldCreateSegment = true
            segmentReason = "semantic unit complete"
        }
        
        if shouldCreateSegment {
            print("🎯 SEMANTIC: Creating segment - Reason: \(segmentReason)")
            createSemanticSegment()
        }
    }
    
    // 停顿基础的辅助切分（备用机制）
    private func checkForPauseBasedSegmentation(_ currentText: String) {
        let timeSinceLastChange = Date().timeIntervalSince(lastSignificantUpdate)
        
        // 🔥 增加停顿时间阈值到4秒，减少频繁切分
        if timeSinceLastChange >= 4.0 && !currentText.isEmpty {
            // 🔥 提高内容长度要求到30字符
            if currentText.count >= 30 && !hasRecentSegment() {
                print("⏸️ PAUSE: Creating segment due to extended pause")
                createSemanticSegment()
            }
        }
        
        // 强制切分（避免极长段落）
        if timeSinceLastChange >= maxSegmentDuration {
            print("⚡ FORCE: Creating segment due to max duration")
            createSemanticSegment()
        }
    }
    
    // 增强的句子结束检测
    private func detectSentenceEnd(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }
        
        // 中英文句子结束标志
        let sentenceEnders = [".", "!", "?", "。", "！", "？"]
        
        // 检查是否以句子结束符结尾（包括后面可能有空格）
        for ender in sentenceEnders {
            if trimmedText.hasSuffix(ender) {
                // 确保不是缩写词（如Dr. Mr. etc.）
                if !isAbbreviation(beforePunctuation: ender, in: trimmedText) {
                    return true
                }
            }
        }
        
        // 检查省略号
        if trimmedText.hasSuffix("...") || trimmedText.hasSuffix("…") {
            return true
        }
        
        return false
    }
    
    // 语法停顿检测（从句、短语边界）
    private func detectGrammaticalPause(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count >= 10 else { return false }
        
        // 检测常见的语法停顿点
        let pausePatterns = [
            // 英文语法停顿
            ", and ", ", but ", ", so ", ", because ", ", although ", ", however ",
            ", while ", ", when ", ", where ", ", which ", ", that ",
            // 中文语法停顿  
            "，而且", "，但是", "，所以", "，因为", "，虽然", "，然而",
            "，当", "，在", "，如果", "，除非", "，直到"
        ]
        
        for pattern in pausePatterns {
            if trimmedText.contains(pattern) {
                // 检查停顿后是否有完整的从句
                let components = trimmedText.components(separatedBy: pattern)
                if components.count >= 2 && components.last?.count ?? 0 >= 5 {
                    return true
                }
            }
        }
        
        return false
    }
    
    // 语义单元检测
    private func detectSemanticUnit(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count >= 20 else { return false }
        
        // 检测完整的语义单元标志
        let semanticMarkers = [
            // 英文语义边界
            " first ", " second ", " third ", " finally ", " in conclusion ",
            " moreover ", " furthermore ", " on the other hand ", " in addition ",
            // 中文语义边界
            "首先", "其次", "然后", "最后", "总之", "另外", "此外", "另一方面"
        ]
        
        for marker in semanticMarkers {
            if trimmedText.lowercased().contains(marker.lowercased()) {
                return true
            }
        }
        
        // 检测问答对话模式
        if trimmedText.contains("?") && trimmedText.contains(".") {
            return true
        }
        
        return false
    }
    
    // 检查是否为缩写词
    private func isAbbreviation(beforePunctuation punct: String, in text: String) -> Bool {
        guard let range = text.range(of: punct, options: .backwards) else { return false }
        let beforePunct = String(text[..<range.lowerBound])
        
        let abbreviations = ["Dr", "Mr", "Mrs", "Ms", "Prof", "etc", "vs", "Inc", "Ltd"]
        
        for abbr in abbreviations {
            if beforePunct.hasSuffix(abbr) {
                return true
            }
        }
        
        return false
    }
    
    // 检查是否有最近的段落
    private func hasRecentSegment() -> Bool {
        guard let lastSegment = realtimeSegments.last else { return false }
        return Date().timeIntervalSince(lastSegment.timestamp) < 3.0
    }
    
    private func determineQualityFromConfidence(_ confidence: Float) -> TranscriptionQuality {
        switch confidence {
        case 0.9...1.0: return .excellent
        case 0.7..<0.9: return .good
        case 0.5..<0.7: return .fair
        default: return .poor
        }
    }
    
    private func restartRecognitionSession() {
        // 避免过于频繁的重启
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isTranscribing {
                self.recognitionRequest?.endAudio()
                self.recognitionTask?.cancel()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if self.isTranscribing {
                        self.setupRecognitionRequest()
                    }
                }
            }
        }
    }
    
    // MARK: - Quality Metrics
    private func updateAudioQualityMetrics(_ quality: AudioQualityMetrics) {
        // 简化的质量更新
        if quality.signalToNoiseRatio > 20 {
            transcriptionQuality = .excellent
        } else if quality.signalToNoiseRatio > 10 {
            transcriptionQuality = .good
        } else if quality.signalToNoiseRatio > 5 {
            transcriptionQuality = .fair
        } else {
            transcriptionQuality = .poor
        }
    }
    
    // MARK: - Timer Management
    private func startTranscriptionTimer() {
        transcriptionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // 定期检查转写状态
            if self.isTranscribing && !self.currentTranscript.isEmpty {
                // 可以在这里添加额外的处理逻辑
            }
        }
    }
    
    private func startSegmentTimer() {
        print("🔥 Starting semantic check timer with interval: \(segmentInterval) seconds")
        segmentTimer?.invalidate() // 确保之前的定时器被清理
        
        DispatchQueue.main.async {
            self.segmentTimer = Timer.scheduledTimer(withTimeInterval: self.segmentInterval, repeats: true) { timer in
                // 定时器现在主要用于语义检测的辅助检查
                self.performSemanticCheck()
            }
            
            if let timer = self.segmentTimer {
                RunLoop.main.add(timer, forMode: .common)
                print("✅ Semantic check timer started successfully")
            } else {
                print("❌ Failed to create semantic check timer")
            }
        }
    }
    
    // 定期语义检查（辅助触发）
    private func performSemanticCheck() {
        guard isTranscribing else { return }
        
        let timeSinceLastChange = Date().timeIntervalSince(lastSignificantUpdate)
        
        // 如果很久没有变化，但有内容，可能需要强制分段
        if timeSinceLastChange >= 4.0 && !currentTranscript.isEmpty {
            let hasSignificantContent = currentTranscript.count > 10
            let noRecentSegments = realtimeSegments.isEmpty || 
                Date().timeIntervalSince(realtimeSegments.last?.timestamp ?? Date()) > 5.0
            
            if hasSignificantContent && noRecentSegments {
                print("⏰ Timer triggered semantic segmentation due to inactivity")
                createSemanticSegment()
            }
        }
    }
    
    private func createTimedSegment() {
        print("🔥 createTimedSegment called, isTranscribing: \(self.isTranscribing), segments count: \(self.realtimeSegments.count)")
        
        DispatchQueue.main.async {
            // 只有在正在转录时才处理
            guard self.isTranscribing else {
                print("❌ Not transcribing, skip segment creation")
                return
            }
            
            print("⏰ Timer triggered - creating segment...")
            print("📝 Current transcript: '\(self.currentTranscript)'")
            print("🎯 Current segments count: \(self.realtimeSegments.count)")
            
            // 提取这一段的新内容（去除累加）
            let segmentText = self.currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            let previousCombinedText = self.realtimeSegments.map { $0.text }.joined(separator: " ")
            let newText = self.extractNewContent(from: segmentText, excluding: previousCombinedText)
            let finalText = newText.isEmpty ? "[No new speech]" : newText
            
            // 暂时不生成翻译，避免阻塞主线程
            let translation = ""
            
            let segment = RealtimeSegment(
                id: UUID(),
                text: finalText,
                timestamp: self.currentSegmentStartTime,
                confidence: self.confidence,
                language: self.detectedLanguage,
                quality: self.transcriptionQuality,
                duration: Date().timeIntervalSince(self.currentSegmentStartTime),
                translation: translation
            )
            
            // 异步生成翻译
            Task {
                let asyncTranslation = await self.generateTranslationForText(finalText)
                await MainActor.run {
                    // 更新segment的翻译
                    if let index = self.realtimeSegments.firstIndex(where: { $0.text == finalText }) {
                        self.realtimeSegments[index].translation = asyncTranslation
                    }
                }
            }
            
            self.realtimeSegments.append(segment)
            print("✅ Created timed segment #\(self.realtimeSegments.count): '\(finalText)' at \(self.currentSegmentStartTime)")
            print("📊 New content only: '\(finalText)'")
            
            // 开始新的时间段，但保留当前转录内容作为基础
            self.currentSegmentStartTime = Date()
            print("🔄 New segment started at: \(self.currentSegmentStartTime)")
        }
    }
    
    // MARK: - Language Management
    func switchLanguage(to languageCode: String) {
        guard supportedLanguages.contains(languageCode) else { return }
        
        let wasTranscribing = isTranscribing
        
        if wasTranscribing {
            stopRealTimeTranscription()
        }
        
        detectedLanguage = languageCode
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
        speechRecognizer?.delegate = self
        
        if wasTranscribing {
            Task {
                try? await startRealTimeTranscription()
            }
        }
    }
    
    // MARK: - Export Functions
    func exportRealtimeSegments() -> [PlaybackSegment] {
        // 计算录音开始时间（第一个segment的时间戳）
        let recordingStartTime = realtimeSegments.first?.timestamp ?? Date()
        
        return realtimeSegments.map { segment in
            // 计算相对于录音开始的时间（秒）
            let relativeStartTime = segment.timestamp.timeIntervalSince(recordingStartTime)
            let relativeEndTime = relativeStartTime + segment.duration
            
            var playbackSegment = PlaybackSegment(
                startTime: relativeStartTime,
                endTime: relativeEndTime,
                transcription: segment.text,
                translation: segment.translation // 使用已保存的翻译，如果为空稍后异步更新
            )
            
            // 设置质量信息
            playbackSegment.confidence = segment.confidence
            playbackSegment.language = segment.language
            playbackSegment.transcriptionQuality = segment.quality
            playbackSegment.audioQualityMetrics = AudioQualityMetrics(
                signalToNoiseRatio: 15.0, // 默认值
                averageAmplitude: 0.1,
                peakAmplitude: 0.3,
                spectralCentroid: 2000,
                timestamp: segment.timestamp
            )
            
            return playbackSegment
        }
    }
    
    func clearSegments() {
        realtimeSegments.removeAll()
        currentTranscript = ""
    }
    
    // 强制创建段落（外部调用）
    func forceCreateSegment() {
        createSemanticSegment()
    }
    
    // 备用的定时切分方法（保留）
    private func createTimedSegmentBackup() {
        print("🔥 createTimedSegmentBackup called (fallback method)")
        
        DispatchQueue.main.async {
            guard self.isTranscribing else {
                print("❌ Not transcribing, skip backup segment creation")
                return
            }
            
            let segmentText = self.currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            let previousCombinedText = self.realtimeSegments.map { $0.text }.joined(separator: " ")
            let newText = self.extractNewContent(from: segmentText, excluding: previousCombinedText)
            let finalText = newText.isEmpty ? "[No new speech]" : newText
            
            // 暂时不生成翻译，避免阻塞主线程
            let translation = ""
            
            let segment = RealtimeSegment(
                id: UUID(),
                text: finalText,
                timestamp: self.currentSegmentStartTime,
                confidence: self.confidence,
                language: self.detectedLanguage,
                quality: self.transcriptionQuality,
                duration: Date().timeIntervalSince(self.currentSegmentStartTime),
                translation: translation
            )
            
            // 异步生成翻译
            Task {
                let asyncTranslation = await self.generateTranslationForText(finalText)
                await MainActor.run {
                    // 更新segment的翻译
                    if let index = self.realtimeSegments.firstIndex(where: { $0.text == finalText }) {
                        self.realtimeSegments[index].translation = asyncTranslation
                    }
                }
            }
            
            self.realtimeSegments.append(segment)
            print("✅ Created backup timed segment #\(self.realtimeSegments.count): '\(finalText)'")
            
            self.currentSegmentStartTime = Date()
            print("🔄 New backup segment started at: \(self.currentSegmentStartTime)")
        }
    }
    
    // 提取新内容，去除累加的重复部分
    private func extractNewContent(from currentText: String, excluding previousText: String) -> String {
        // 如果没有之前的内容，返回当前全部内容
        guard !previousText.isEmpty else {
            return currentText
        }
        
        // 移除前缀中已存在的部分
        if currentText.hasPrefix(previousText) {
            let startIndex = currentText.index(currentText.startIndex, offsetBy: previousText.count)
            return String(currentText[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 寻找重叠部分并移除
        let currentWords = currentText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let previousWords = previousText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // 从后往前找重叠
        var newWords: [String] = []
        var foundOverlap = false
        
        for i in 0..<currentWords.count {
            let word = currentWords[i]
            if !foundOverlap && previousWords.contains(word) {
                // 找到重叠的起始点，跳过已有的词
                continue
            }
            foundOverlap = true
            newWords.append(word)
        }
        
        return newWords.joined(separator: " ")
    }
    
    // 为实时转录文本生成翻译（修复版）
    private func generateTranslationForText(_ text: String) async -> String {
        // 检查文本是否为空或占位符
        if text.isEmpty || text.contains("[No") || text.contains("No new speech") {
            return ""
        }
        
        // 检查API Key是否配置 - 需要在MainActor中检查
        let hasAPIKey = await MainActor.run {
            return APIKeyManager.shared.hasQianwenKey
        }
        
        guard hasAPIKey else {
            return "Please configure Qianwen API key in Settings"
        }
        
        // 🔥 关键修复：不返回假的"Translating..."，直接进行真实翻译
        let sourceLanguage = QianwenTranslateManager.shared.detectLanguage(text)
        let targetLanguage = sourceLanguage == "zh" ? "en" : "zh"
        
        // 构建上下文（前一段内容）
        let context = buildTranslationContext()
        
        // 🔥 直接进行同步翻译（改为异步但立即触发）
        Task {
            do {
                let translation = try await QianwenTranslateManager.shared.translateWithContext(
                    text,
                    context: context,
                    from: sourceLanguage, 
                    to: targetLanguage
                )
                
                print("✅ Translation completed: '\(text)' -> '\(translation)'")
                
                // 立即更新对应segment的翻译
                await MainActor.run {
                    updateSegmentTranslation(originalText: text, translation: translation)
                }
            } catch {
                print("❌ Translation failed: \(error)")
                await MainActor.run {
                    updateSegmentTranslation(originalText: text, translation: "Translation error: \(error.localizedDescription)")
                }
            }
        }
        
        // 🔥 返回空字符串，等待异步更新
        // 这样不会显示假的"Translating..."，而是空白直到真正的翻译完成
        return ""
    }
    
    // 构建翻译上下文
    private func buildTranslationContext() -> String {
        // 获取最近的2-3个段落作为上下文
        let recentSegments = Array(realtimeSegments.suffix(3))
        let contextTexts = recentSegments.map { $0.text }
        
        if contextTexts.isEmpty {
            return ""
        }
        
        return "Previous context: " + contextTexts.joined(separator: " ")
    }
    
    // 更新segment的翻译
    private func updateSegmentTranslation(originalText: String, translation: String) {
        if let index = realtimeSegments.firstIndex(where: { $0.text == originalText }) {
            realtimeSegments[index].translation = translation
        }
    }
    
    private func createSemanticSegment() {
        print("🔥 createSemanticSegment called, isTranscribing: \(self.isTranscribing), segments count: \(self.realtimeSegments.count)")
        
        DispatchQueue.main.async {
            // 只有在正在转录时才处理
            guard self.isTranscribing else {
                print("❌ Not transcribing, skip segment creation")
                return
            }
            
            let currentText = self.currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 🔥 简化逻辑：使用字符位置追踪
            let startPosition = self.lastProcessedLength
            let newContent: String
            
            if startPosition < currentText.count {
                let startIndex = currentText.index(currentText.startIndex, offsetBy: startPosition)
                newContent = String(currentText[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                newContent = ""
            }
            
            // 🔥 提高新内容最小长度要求到15字符
            guard !newContent.isEmpty && newContent.count >= 15 else {
                print("📝 New content too short: '\(newContent)' (length: \(newContent.count))")
                return
            }
            
            print("🎯 NEW content: '\(newContent)'")
            print("📊 Full transcript: '\(currentText)'")
            print("🔢 Previous length: \(self.lastProcessedLength), Current: \(currentText.count)")
            
            // 为新内容生成翻译 - 使用Task来处理async调用
            Task {
                let translation = await self.generateTranslationForText(newContent)
                
                await MainActor.run {
                    let segment = RealtimeSegment(
                        id: UUID(),
                        text: newContent,
                        timestamp: self.currentSegmentStartTime,
                        confidence: self.confidence,
                        language: self.detectedLanguage,
                        quality: self.transcriptionQuality,
                        duration: Date().timeIntervalSince(self.currentSegmentStartTime),
                        translation: translation
                    )
                    
                    self.realtimeSegments.append(segment)
                    print("✅ Created semantic segment #\(self.realtimeSegments.count): '\(newContent)'")
                    
                    // 🔥 更新处理位置
                    self.lastProcessedLength = currentText.count
                    
                    // 重置时间段
                    self.currentSegmentStartTime = Date()
                    self.lastSignificantUpdate = Date()
                    self.lastTranscriptLength = currentText.count
                    print("🔄 Updated processed length to: \(self.lastProcessedLength)")
                }
            }
            
            // 临时创建不带翻译的segment，翻译异步更新
            let tempSegment = RealtimeSegment(
                id: UUID(),
                text: newContent,
                timestamp: self.currentSegmentStartTime,
                confidence: self.confidence,
                language: self.detectedLanguage,
                quality: self.transcriptionQuality,
                duration: Date().timeIntervalSince(self.currentSegmentStartTime),
                translation: "" // 稍后异步更新
            )
            
            self.realtimeSegments.append(tempSegment)
            print("✅ Created temporary segment #\(self.realtimeSegments.count): '\(newContent)' (translation pending)")
            
            // 🔥 更新处理位置
            self.lastProcessedLength = currentText.count
            
            // 重置时间段
            self.currentSegmentStartTime = Date()
            self.lastSignificantUpdate = Date()
            self.lastTranscriptLength = currentText.count
            print("🔄 Updated processed length to: \(self.lastProcessedLength)")
        }
    }
    
    // MARK: - Hybrid Segmentation Algorithm (Industry Best Practice)
    
    private func processTranscriptionWithHybridSegmentation(_ result: SFSpeechRecognitionResult) {
        let transcriptText = result.bestTranscription.formattedString
        currentTranscript = transcriptText
        
        // 更新置信度和质量
        let avgConfidence = result.bestTranscription.segments.map { $0.confidence }.reduce(0, +) / Float(result.bestTranscription.segments.count)
        confidence = avgConfidence
        transcriptionQuality = determineQualityFromConfidence(avgConfidence)
        
        // 添加到滑动窗口缓冲区
        let bufferEntry = (text: transcriptText, timestamp: Date(), confidence: avgConfidence)
        audioSegmentBuffer.append(bufferEntry)
        
        // 维护缓冲区大小（保持最近30秒的数据）
        let bufferTimeLimit = TimeInterval(30)
        audioSegmentBuffer = audioSegmentBuffer.filter { 
            Date().timeIntervalSince($0.timestamp) <= bufferTimeLimit 
        }
        
        // 多信号边界检测
        performMultiSignalBoundaryDetection(transcriptText, result: result)
        
        // 检查是否应该创建分段
        if shouldCreateHybridSegment() {
            createHybridSegment()
        }
    }
    
    // 多信号边界检测 - 结合声学和语义特征
    private func performMultiSignalBoundaryDetection(_ text: String, result: SFSpeechRecognitionResult) {
        // 1. 声学边界检测 (基于WebRTC VAD思想)
        detectAcousticBoundary(result)
        
        // 2. 语义边界检测 (基于BERT和语言模型研究)
        detectSemanticBoundary(text)
        
        // 3. 时间窗口检测 (基于E2E Segmenter)
        detectTemporalBoundary()
    }
    
    // 声学边界检测
    private func detectAcousticBoundary(_ result: SFSpeechRecognitionResult) {
        acousticBoundaryDetected = false
        
        // 检测语音停顿模式
        let segments = result.bestTranscription.segments
        if segments.count >= 2 {
            let lastSegment = segments[segments.count - 1]
            let secondLastSegment = segments[segments.count - 2]
            
            // 计算段落间隔
            let pauseDuration = lastSegment.timestamp - (secondLastSegment.timestamp + secondLastSegment.duration)
            
            // 超过阈值认为是声学边界
            if pauseDuration >= 0.8 { // 800ms停顿
                acousticBoundaryDetected = true
                print("🔊 Acoustic boundary detected: pause = \\(pauseDuration)s")
            }
        }
        
        // 检测语音结束（final result）
        if result.isFinal {
            acousticBoundaryDetected = true
            print("🔊 Acoustic boundary: final result")
        }
    }
    
    // 语义边界检测
    private func detectSemanticBoundary(_ text: String) {
        semanticBoundaryDetected = false
        
        // 1. 句子边界检测（强信号）
        let sentenceEnders = [".", "!", "?", "。", "！", "？"]
        let lastChar = String(text.suffix(1))
        if sentenceEnders.contains(lastChar) {
            semanticBoundaryDetected = true
            print("📝 Semantic boundary: sentence ending '\\(lastChar)'")
            return
        }
        
        // 2. 语法边界检测（中信号）
        let clauseEnders = [", and ", ", but ", ", however ", ", although ", ", because "]
        let clauseEndersZh = ["，而且", "，但是", "，然而", "，虽然", "，因为"]
        let allClauseEnders = clauseEnders + clauseEndersZh
        
        for clauseEnder in allClauseEnders {
            if text.lowercased().hasSuffix(clauseEnder.lowercased()) {
                semanticBoundaryDetected = true
                print("📝 Semantic boundary: clause ending '\\(clauseEnder)'")
                return
            }
        }
        
        // 3. 段落连接词检测（弱信号）
        let transitionWords = ["first", "second", "finally", "in conclusion", "meanwhile", "首先", "其次", "最后", "总之", "同时"]
        let currentWords = text.components(separatedBy: .whitespacesAndNewlines).suffix(3)
        
        for word in currentWords {
            if transitionWords.contains(word.lowercased()) {
                semanticBoundaryDetected = true
                print("📝 Semantic boundary: transition word '\\(word)'")
                return
            }
        }
    }
    
    // 时间窗口检测
    private func detectTemporalBoundary() {
        let timeSinceLastBoundary = Date().timeIntervalSince(lastBoundaryTime)
        
        // 超过最大段落长度强制分段
        if timeSinceLastBoundary >= maxSegmentLength {
            acousticBoundaryDetected = true
            print("⏰ Temporal boundary: max length reached (\\(timeSinceLastBoundary)s)")
        }
    }
    
    // 混合分段决策
    private func shouldCreateHybridSegment() -> Bool {
        let timeSinceLastBoundary = Date().timeIntervalSince(lastBoundaryTime)
        
        // 条件1：同时检测到声学和语义边界（高置信度）
        if acousticBoundaryDetected && semanticBoundaryDetected && timeSinceLastBoundary >= minSegmentLength {
            print("✅ High confidence segmentation: acoustic + semantic")
            return true
        }
        
        // 条件2：强语义边界 + 足够时间（中置信度）
        if semanticBoundaryDetected && timeSinceLastBoundary >= minSegmentLength * 1.2 {
            print("✅ Medium confidence segmentation: strong semantic")
            return true
        }
        
        // 条件3：声学边界 + 较长时间（低置信度）
        if acousticBoundaryDetected && timeSinceLastBoundary >= minSegmentLength * 2.0 {
            print("✅ Low confidence segmentation: acoustic + time")
            return true
        }
        
        // 条件4：强制分段（超时保护）
        if timeSinceLastBoundary >= maxSegmentLength {
            print("⚠️ Force segmentation: timeout protection")
            return true
        }
        
        return false
    }
    
    // 创建混合分段
    private func createHybridSegment() {
        DispatchQueue.main.async {
            guard self.isTranscribing else { return }
            
            // 使用滑动窗口提取内容
            let segmentText = self.extractContentWithStride()
            
            guard !segmentText.isEmpty else {
                print("📝 No content to segment")
                return
            }
            
            print("🎯 Creating hybrid segment: '\\(segmentText)'")
            
            // 创建实时分段
            self.createRealtimeSegment(with: segmentText)
            
            // 重置状态
            self.resetSegmentationState()
        }
    }
    
    // 使用步长提取内容（Wav2Vec2风格）
    private func extractContentWithStride() -> String {
        guard !audioSegmentBuffer.isEmpty else { return "" }
        
        // 获取当前处理窗口内的内容
        let currentTime = Date()
        let windowStart = currentTime.addingTimeInterval(-windowSize)
        
        // 提取窗口内的文本
        let windowEntries = audioSegmentBuffer.filter { entry in
            entry.timestamp >= windowStart && entry.timestamp <= currentTime
        }
        
        if let latestEntry = windowEntries.last {
            let newContent = extractIncrementalContent(from: latestEntry.text)
            return newContent
        }
        
        return ""
    }
    
    // 提取增量内容
    private func extractIncrementalContent(from fullText: String) -> String {
        let startPosition = lastProcessedLength
        
        if startPosition < fullText.count {
            let startIndex = fullText.index(fullText.startIndex, offsetBy: startPosition)
            let newContent = String(fullText[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 更新已处理长度
            lastProcessedLength = fullText.count
            
            return newContent
        }
        
        return ""
    }
    
    // 重置分段状态
    private func resetSegmentationState() {
        acousticBoundaryDetected = false
        semanticBoundaryDetected = false
        lastBoundaryTime = Date()
        currentWindowBuffer = ""
        strideBuffer = ""
    }
    
    // 创建实时分段
    private func createRealtimeSegment(with text: String) {
        guard !text.isEmpty else { return }
        
        let currentTime = Date()
        let duration = currentTime.timeIntervalSince(currentSegmentStartTime)
        
        // 生成翻译
        let translation = "" // 暂时不生成翻译，避免阻塞
        
        // 异步生成翻译
        Task {
            let asyncTranslation = await generateTranslationForText(text)
            await MainActor.run {
                // 更新最新segment的翻译
                if let lastIndex = realtimeSegments.indices.last {
                    realtimeSegments[lastIndex].translation = asyncTranslation
                }
            }
        }
        
        // 创建新分段
        let segment = RealtimeSegment(
            id: UUID(),
            text: text,
            timestamp: currentTime,
            confidence: confidence,
            language: "auto", // 自动检测语言
            quality: transcriptionQuality,
            duration: duration,
            translation: translation
        )
        
        // 添加到数组
        realtimeSegments.append(segment)
        
        print("✅ Created hybrid segment [\(String(format: "%.1f", duration))s]: '\(text)' -> '\(translation)'")
        
        // 更新分段开始时间为当前时间
        currentSegmentStartTime = currentTime
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension RealTimeTranscriptionManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if !available && self.isTranscribing {
                self.transcriptionError = "Speech recognition became unavailable"
                self.stopRealTimeTranscription()
            }
        }
    }
}

// MARK: - Supporting Types
struct RealtimeSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let confidence: Float
    let language: String
    let quality: TranscriptionQuality
    let duration: TimeInterval
    var translation: String // 添加翻译字段
    
    init(id: UUID = UUID(), text: String, timestamp: Date, confidence: Float, language: String, quality: TranscriptionQuality, duration: TimeInterval, translation: String = "") {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.confidence = confidence
        self.language = language
        self.quality = quality
        self.duration = duration
        self.translation = translation
    }
}

// TranscriptionQuality和AudioQualityMetrics已在RecordingSessionManager中定义

struct TranscriptionQualityMetrics {
    let level: TranscriptionQuality
    let confidence: Float
    let wordAccuracy: Float
    let sentenceCompleteness: Float
}

// MARK: - Language Detection Engine
class LanguageDetectionEngine {
    func detectLanguage(from buffer: AVAudioPCMBuffer) async -> String {
        // 实现音频语言检测逻辑
        // 这里使用模拟实现，实际可以集成ML模型或云服务
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                // 模拟语言检测结果
                let detectedLanguages = ["en", "zh", "es", "fr"]
                let randomLanguage = detectedLanguages.randomElement() ?? "en"
                continuation.resume(returning: randomLanguage)
            }
        }
    }
}

// MARK: - Transcription Quality Analyzer
class TranscriptionQualityAnalyzer {
    func analyzeAudioQuality(_ buffer: AVAudioPCMBuffer) -> AudioQualityMetrics {
        // 分析音频质量
        guard let channelData = buffer.floatChannelData?[0] else {
            return AudioQualityMetrics(signalToNoiseRatio: 0, averageAmplitude: 0, peakAmplitude: 0, spectralCentroid: 0, timestamp: Date())
        }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        var peak: Float = 0
        
        for i in 0..<frameLength {
            let sample = abs(channelData[i])
            sum += sample
            peak = max(peak, sample)
        }
        
        let average = sum / Float(frameLength)
        let snr = peak > 0 ? 20 * log10(peak / (average + 0.001)) : 0
        
        return AudioQualityMetrics(
            signalToNoiseRatio: snr,
            averageAmplitude: average,
            peakAmplitude: peak,
            spectralCentroid: 0, // 简化实现
            timestamp: Date()
        )
    }
    
    func analyzeTranscriptionQuality(_ result: SFSpeechRecognitionResult) -> TranscriptionQualityMetrics {
        let confidence = result.bestTranscription.segments.map { $0.confidence }.reduce(0, +) / Float(result.bestTranscription.segments.count)
        
        let level: TranscriptionQuality
        switch confidence {
        case 0.9...1.0: level = .excellent
        case 0.7..<0.9: level = .good
        case 0.5..<0.7: level = .fair
        case 0.0..<0.5: level = .poor
        default: level = .unknown
        }
        
        return TranscriptionQualityMetrics(
            level: level,
            confidence: confidence,
            wordAccuracy: confidence,
            sentenceCompleteness: calculateSentenceCompleteness(result.bestTranscription.formattedString)
        )
    }
    
    private func calculateSentenceCompleteness(_ text: String) -> Float {
        // 简单的句子完整性分析
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        let completeSentences = sentences.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        return sentences.isEmpty ? 0 : Float(completeSentences.count) / Float(sentences.count)
    }
} 