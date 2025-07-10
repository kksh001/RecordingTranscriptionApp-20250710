//
//  RecordingSessionManager.swift
//  RecordingTranscriptionApp
//
//  Created by kamakomawu on 2024/6/16.
//

import SwiftUI
import Foundation

// MARK: - 转写质量枚举
enum TranscriptionQuality: String, CaseIterable, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case unknown = "Unknown"
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        case .unknown: return "gray"
        }
    }
}

// MARK: - 音频质量指标
struct AudioQualityMetrics: Codable {
    let signalToNoiseRatio: Float
    let averageAmplitude: Float
    let peakAmplitude: Float
    let spectralCentroid: Float
    let timestamp: Date
    
    init(signalToNoiseRatio: Float, averageAmplitude: Float, peakAmplitude: Float, spectralCentroid: Float, timestamp: Date = Date()) {
        self.signalToNoiseRatio = signalToNoiseRatio
        self.averageAmplitude = averageAmplitude
        self.peakAmplitude = peakAmplitude
        self.spectralCentroid = spectralCentroid
        self.timestamp = timestamp
    }
}

// MARK: - 新增数据结构用于技术债务控制

/// 编辑记录结构
struct EditRecord: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let fieldType: EditFieldType
    let oldValue: String
    let newValue: String
    let editReason: String?
}

/// 编辑字段类型
enum EditFieldType: String, Codable, CaseIterable {
    case transcription = "transcription"
    case translation = "translation"
}

/// 增强的播放段落结构
struct PlaybackSegment: Codable, Identifiable {
    let id = UUID()
    let startTime: TimeInterval
    let endTime: TimeInterval
    let transcription: String
    var translation: String
    
    // 新增编辑支持字段
    var isTranscriptionEdited: Bool = false
    var isTranslationEdited: Bool = false
    var originalTranscription: String?
    var originalTranslation: String?
    var editHistory: [EditRecord] = []
    var lastModified: Date = Date()
    
    // 实时转写质量字段
    var confidence: Float = 0.0
    var language: String = ""
    var transcriptionQuality: TranscriptionQuality = .unknown
    var isRealTimeGenerated: Bool = false
    var audioQualityMetrics: AudioQualityMetrics?
    
    // 计算属性
    var duration: TimeInterval {
        return endTime - startTime
    }
    
    // 格式化时间显示
    var timeRangeString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        let startStr = formatter.string(from: startTime) ?? "00:00"
        let endStr = formatter.string(from: endTime) ?? "00:00"
        return "\(startStr) - \(endStr)"
    }
    
    // 检查是否有编辑
    var hasEdits: Bool {
        return isTranscriptionEdited || isTranslationEdited
    }
    
    // 获取当前有效的转写文本
    var currentTranscription: String {
        return transcription
    }
    
    // 获取当前有效的翻译文本
    var currentTranslation: String {
        return translation
    }
}

// MARK: - 扩展PlaybackSegment的编辑功能
extension PlaybackSegment {
    /// 更新转写内容
    mutating func updateTranscription(_ newValue: String, reason: String? = nil) {
        guard newValue != transcription else { return }
        
        // 备份原始内容（首次编辑）
        if originalTranscription == nil {
            originalTranscription = transcription
        }
        
        // 添加编辑记录
        let editRecord = EditRecord(
            timestamp: Date(),
            fieldType: .transcription,
            oldValue: transcription,
            newValue: newValue,
            editReason: reason
        )
        editHistory.append(editRecord)
        
        // 更新状态
        isTranscriptionEdited = true
        lastModified = Date()
    }
    
    /// 更新翻译内容
    mutating func updateTranslation(_ newValue: String, reason: String? = nil) {
        guard newValue != translation else { return }
        
        // 备份原始内容（首次编辑）
        if originalTranslation == nil {
            originalTranslation = translation
        }
        
        // 添加编辑记录
        let editRecord = EditRecord(
            timestamp: Date(),
            fieldType: .translation,
            oldValue: translation,
            newValue: newValue,
            editReason: reason
        )
        editHistory.append(editRecord)
        
        // 更新状态
        isTranslationEdited = true
        lastModified = Date()
    }
    
    /// 回滚到原始内容
    mutating func revertToOriginal(fieldType: EditFieldType) {
        switch fieldType {
        case .transcription:
            if let original = originalTranscription {
                let editRecord = EditRecord(
                    timestamp: Date(),
                    fieldType: .transcription,
                    oldValue: transcription,
                    newValue: original,
                    editReason: "Reverted to original"
                )
                editHistory.append(editRecord)
                isTranscriptionEdited = false
                lastModified = Date()
            }
        case .translation:
            if let original = originalTranslation {
                let editRecord = EditRecord(
                    timestamp: Date(),
                    fieldType: .translation,
                    oldValue: translation,
                    newValue: original,
                    editReason: "Reverted to original"
                )
                editHistory.append(editRecord)
                isTranslationEdited = false
                lastModified = Date()
            }
        }
    }
}

// MARK: - 录音会话管理器
class RecordingSessionManager: ObservableObject {
    @Published var sessions: [RecordingSession] = []
    
    private let userDefaultsKey = "SavedRecordingSessions"
    
    init() {
        loadSessions()
    }
    
    // MARK: - 添加新的录音会话
    func addSession(from audioManager: AudioRecordingManager) {
        let recordingInfo = audioManager.getCurrentRecordingInfo()
        
        print("📋 RecordingSessionManager.addSession called:")
        print("   Recording URL: \(recordingInfo.url?.absoluteString ?? "nil")")
        print("   Recording Name: \(recordingInfo.name)")
        print("   Recording Duration: \(recordingInfo.duration)")
        
        // 处理录音URL和文件路径
        let filePath: String
        let fileSize: String
        
        if let url = recordingInfo.url {
            // 检查文件是否真的存在
            let exists = FileManager.default.fileExists(atPath: url.path)
            print("📁 File exists at \(url.path): \(exists)")
            
            if exists {
                filePath = url.path
                fileSize = formatFileSize(url: url)
            } else {
                // 文件不存在，创建一个模拟的路径和大小
                print("⚠️ File doesn't exist, creating simulated entry")
                filePath = url.path
                fileSize = "\(Int(recordingInfo.duration * 32)) KB" // 模拟文件大小
            }
        } else {
            // 没有URL，创建一个测试路径
            print("⚠️ No recording URL, creating test entry")
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            filePath = documentsPath.appendingPathComponent("Recordings").appendingPathComponent("test_recording.m4a").path
            fileSize = "\(Int(recordingInfo.duration * 32)) KB"
        }
        
        let newSession = RecordingSession(
            name: recordingInfo.name.isEmpty ? "New Recording" : recordingInfo.name,
            duration: recordingInfo.duration,
            date: Date(),
            fileSize: fileSize,
            sessionStatus: .completed,
            sourceLanguage: "English", // 默认值，后续可以从设置中获取
            targetLanguage: "Chinese", // 默认值，后续可以从设置中获取
            hasTranslation: true,
            priority: .normal,
            sessionType: .memo,
            filePath: filePath,
            wordCount: estimateWordCount(duration: recordingInfo.duration),
            transcriptionQuality: .good
        )
        
        print("✅ New session created: \(newSession.name), Duration: \(newSession.duration)s")
        
        // 添加到列表开头（最新的在前面）
        sessions.insert(newSession, at: 0)
        
        print("📊 Sessions count: \(sessions.count)")
        
        // 保存到持久化存储
        saveSessions()
        
        print("💾 Sessions saved to UserDefaults")
    }
    
    // MARK: - 添加带实时转写数据的录音会话
    func addSessionWithRealTimeTranscription(from audioManager: AudioRecordingManager, realtimeSegments: [PlaybackSegment]) {
        let recordingInfo = audioManager.getCurrentRecordingInfo()
        
        print("📋 RecordingSessionManager.addSessionWithRealTimeTranscription called:")
        print("   Recording URL: \(recordingInfo.url?.absoluteString ?? "nil")")
        print("   Recording Name: \(recordingInfo.name)")
        print("   Recording Duration: \(recordingInfo.duration)")
        print("   Realtime Segments: \(realtimeSegments.count)")
        
        // 处理录音URL和文件路径
        let filePath: String
        let fileSize: String
        
        if let url = recordingInfo.url {
            let exists = FileManager.default.fileExists(atPath: url.path)
            print("📁 File exists at \(url.path): \(exists)")
            
            if exists {
                filePath = url.path
                fileSize = formatFileSize(url: url)
            } else {
                print("⚠️ File doesn't exist, creating simulated entry")
                filePath = url.path
                fileSize = "\(Int(recordingInfo.duration * 32)) KB"
            }
        } else {
            print("⚠️ No recording URL, creating test entry")
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            filePath = documentsPath.appendingPathComponent("Recordings").appendingPathComponent("test_recording.m4a").path
            fileSize = "\(Int(recordingInfo.duration * 32)) KB"
        }
        
        // 从实时转写数据分析会话信息
        let detectedLanguage = analyzeDetectedLanguage(from: realtimeSegments)
        let averageQuality = calculateAverageTranscriptionQuality(from: realtimeSegments)
        let totalWordCount = calculateWordCount(from: realtimeSegments)
        
        var newSession = RecordingSession(
            name: recordingInfo.name.isEmpty ? "Real-time Recording" : recordingInfo.name,
            duration: recordingInfo.duration,
            date: Date(),
            fileSize: fileSize,
            sessionStatus: .completed,
            sourceLanguage: detectedLanguage.isEmpty ? "English" : detectedLanguage,
            targetLanguage: "Chinese", // 默认翻译目标
            hasTranslation: false, // 实时转写暂不包含翻译
            priority: .normal,
            sessionType: .memo,
            filePath: filePath,
            wordCount: totalWordCount,
            transcriptionQuality: RecordingSession.TranscriptionQuality.excellent
        )
        
        // 设置实时转写段落数据
        newSession.segments = realtimeSegments
        
        print("✅ New session with real-time transcription created:")
        print("   Name: \(newSession.name)")
        print("   Duration: \(newSession.duration)s")
        print("   Detected Language: \(detectedLanguage)")
        print("   Quality: \(averageQuality.rawValue)")
        print("   Word Count: \(totalWordCount)")
        print("   Segments: \(realtimeSegments.count)")
        
        // 添加到列表开头
        sessions.insert(newSession, at: 0)
        
        // 保存到持久化存储
        saveSessions()
        
        print("💾 Session with real-time transcription saved")
    }
    
    // MARK: - 实时转写数据分析辅助方法
    
    private func analyzeDetectedLanguage(from segments: [PlaybackSegment]) -> String {
        // 统计最常出现的语言
        let languageCounts = segments.reduce(into: [String: Int]()) { counts, segment in
            if !segment.language.isEmpty {
                counts[segment.language, default: 0] += 1
            }
        }
        
        return languageCounts.max(by: { $0.value < $1.value })?.key ?? "en"
    }
    
    private func calculateAverageTranscriptionQuality(from segments: [PlaybackSegment]) -> TranscriptionQuality {
        guard !segments.isEmpty else { return .unknown }
        
        let qualityScores = segments.compactMap { segment -> Int? in
            switch segment.transcriptionQuality {
            case .excellent: return 4
            case .good: return 3
            case .fair: return 2
            case .poor: return 1
            case .unknown: return nil
            }
        }
        
        guard !qualityScores.isEmpty else { return .unknown }
        
        let averageScore = Double(qualityScores.reduce(0, +)) / Double(qualityScores.count)
        
        switch averageScore {
        case 3.5...4.0: return .excellent
        case 2.5..<3.5: return .good
        case 1.5..<2.5: return .fair
        case 0.0..<1.5: return .poor
        default: return .unknown
        }
    }
    
    private func calculateWordCount(from segments: [PlaybackSegment]) -> Int {
        return segments.reduce(0) { total, segment in
            total + segment.transcription.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        }
    }
    
    // MARK: - 删除录音会话
    func deleteSession(_ session: RecordingSession) {
        print("🗑️ Deleting session: \(session.name)")
        print("   Session ID: \(session.id)")
        print("   Sessions count before deletion: \(sessions.count)")
        
        sessions.removeAll { $0.id == session.id }
        
        print("   Sessions count after deletion: \(sessions.count)")
        
        saveSessions()
        
        // 删除对应的音频文件
        let fileURL = URL(fileURLWithPath: session.filePath)
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("   ✅ Audio file deleted: \(fileURL.path)")
            } else {
                print("   ⚠️ Audio file not found: \(fileURL.path)")
            }
        } catch {
            print("   ❌ Failed to delete audio file: \(error)")
        }
        
        print("✅ Session deletion completed")
    }
    
    // MARK: - 新增段落编辑功能管理
    
    /// 更新指定会话的段落
    func updateSession(_ session: RecordingSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSessions()
        }
    }
    
    /// 更新指定会话中的特定段落
    func updateSegment(sessionId: UUID, segmentId: UUID, updatedSegment: PlaybackSegment) {
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
           let segmentIndex = sessions[sessionIndex].segments.firstIndex(where: { $0.id == segmentId }) {
            sessions[sessionIndex].segments[segmentIndex] = updatedSegment
            sessions[sessionIndex].lastEditedAt = Date()
            sessions[sessionIndex].hasUnsavedChanges = true
            saveSessions()
        }
    }
    
    /// 批量更新段落
    func updateSegments(sessionId: UUID, segments: [PlaybackSegment]) {
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[sessionIndex].segments = segments
            sessions[sessionIndex].lastEditedAt = Date()
            sessions[sessionIndex].hasUnsavedChanges = true
            saveSessions()
        }
    }
    
    /// 标记会话已保存
    func markSessionSaved(sessionId: UUID) {
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[sessionIndex].hasUnsavedChanges = false
            saveSessions()
        }
    }
    
    /// 获取有未保存更改的会话
    func getSessionsWithUnsavedChanges() -> [RecordingSession] {
        return sessions.filter { $0.hasUnsavedChanges }
    }
    
    // MARK: - 增强的持久化保存
    private func saveSessions() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sessions)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            
            // 保存数据版本号用于迁移
            UserDefaults.standard.set(dataVersion, forKey: dataVersionKey)
            
            print("✅ Saved \(sessions.count) sessions with enhanced data structure")
        } catch {
            print("❌ Failed to save sessions: \(error)")
            // 创建备份文件以防数据丢失
            createBackup()
        }
    }
    
    // MARK: - 增强的数据加载与迁移
    private func loadSessions() {
        // 检查数据版本并执行迁移
        let currentVersion = UserDefaults.standard.integer(forKey: dataVersionKey)
        
        if currentVersion < dataVersion {
            print("🔄 Data migration needed from version \(currentVersion) to \(dataVersion)")
            performDataMigration(from: currentVersion)
        }
        
        // 加载保存的会话数据
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                sessions = try decoder.decode([RecordingSession].self, from: data)
                print("✅ Loaded \(sessions.count) sessions from UserDefaults")
                
                // 验证数据完整性
                validateDataIntegrity()
                
            } catch {
                print("❌ Failed to load sessions: \(error)")
                print("🔄 Attempting to load from backup...")
                loadFromBackup()
            }
        } else {
            print("📝 No saved sessions found, loading sample data")
            loadSampleData()
        }
    }
    
    /// 数据迁移逻辑
    private func performDataMigration(from oldVersion: Int) {
        print("🔄 Performing data migration from version \(oldVersion)...")
        
        // 创建备份
        createBackup()
        
        switch oldVersion {
        case 0, 1:
            // 从版本1迁移：添加segments字段和编辑功能
            migrateTo_v2()
        default:
            break
        }
        
        print("✅ Data migration completed")
    }
    
    /// 迁移到版本2：添加段落支持
    private func migrateTo_v2() {
        for i in 0..<sessions.count {
            // 为每个会话创建示例段落数据
            if sessions[i].segments.isEmpty {
                sessions[i].segments = createMockSegments(for: sessions[i])
            }
        }
    }
    
    /// 创建示例段落数据
    private func createMockSegments(for session: RecordingSession) -> [PlaybackSegment] {
        let segmentCount = max(1, Int(session.duration / 30)) // 每30秒一个段落
        let segmentDuration = session.duration / Double(segmentCount)
        var segments: [PlaybackSegment] = []
        
        for i in 0..<segmentCount {
            let startTime = Double(i) * segmentDuration
            let endTime = min(startTime + segmentDuration, session.duration)
            
            let segment = PlaybackSegment(
                startTime: startTime,
                endTime: endTime,
                transcription: generateMockTranscription(index: i, language: session.sourceLanguage),
                translation: generateMockTranslation(index: i, language: session.targetLanguage ?? "English")
            )
            segments.append(segment)
        }
        
        return segments
    }
    
    /// 数据完整性验证
    private func validateDataIntegrity() {
        var hasErrors = false
        
        for (index, session) in sessions.enumerated() {
            // 验证段落数据
            for segment in session.segments {
                if segment.startTime >= segment.endTime {
                    print("⚠️ Invalid segment time range in session \(session.name)")
                    hasErrors = true
                }
            }
            
            // 修复缺失的段落数据
            if session.segments.isEmpty && session.duration > 0 {
                print("🔧 Fixing missing segments for session: \(session.name)")
                sessions[index].segments = createMockSegments(for: session)
                hasErrors = true
            }
        }
        
        if hasErrors {
            print("🔧 Data integrity issues found and fixed, saving...")
            saveSessions()
        }
    }
    
    /// 创建数据备份
    private func createBackup() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            let backupKey = "\(userDefaultsKey)_backup_\(Int(Date().timeIntervalSince1970))"
            UserDefaults.standard.set(data, forKey: backupKey)
            print("💾 Created data backup: \(backupKey)")
        }
    }
    
    /// 从备份恢复数据
    private func loadFromBackup() {
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let backupKeys = allKeys.filter { $0.hasPrefix("\(userDefaultsKey)_backup_") }
            .sorted(by: >)
        
        for backupKey in backupKeys {
            if let data = UserDefaults.standard.data(forKey: backupKey) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    sessions = try decoder.decode([RecordingSession].self, from: data)
                    print("✅ Restored from backup: \(backupKey)")
                    return
                } catch {
                    print("❌ Failed to restore from backup \(backupKey): \(error)")
                }
            }
        }
        
        print("📝 No valid backup found, loading sample data")
        loadSampleData()
    }
    
    /// 加载示例数据
    private func loadSampleData() {
        sessions = sampleSessions
        // 为示例数据添加段落
        for i in 0..<sessions.count {
            sessions[i].segments = createMockSegments(for: sessions[i])
        }
        saveSessions()
    }
    
    // MARK: - 数据常量
    private let dataVersion = 2
    private let dataVersionKey = "RecordingSessionsDataVersion"
    
    // MARK: - 辅助方法
    private func formatFileSize(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useMB, .useKB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            print("Failed to get file size: \(error)")
        }
        return "Unknown"
    }
    
    private func estimateWordCount(duration: TimeInterval) -> Int {
        // 估算：平均每分钟150个单词
        return Int(duration / 60.0 * 150)
    }
    
    // MARK: - 示例文本生成方法
    
    private func generateMockTranscription(index: Int, language: String) -> String {
        let transcriptions: [String: [String]] = [
            "English": [
                "Welcome to our meeting today. Let's start by reviewing the agenda.",
                "The quarterly results show significant improvement in our key metrics.",
                "I believe we should focus on user experience in the next iteration.",
                "Can we schedule a follow-up meeting to discuss implementation details?",
                "Thank you all for your participation. The meeting is now concluded."
            ],
            "Chinese": [
                "Welcome everyone to today's meeting. Let's start by reviewing the agenda.",
                "The quarterly report shows significant improvement in our key metrics.",
                "I think the next iteration should focus on user experience.",
                "Can we schedule a follow-up meeting to discuss implementation details?",
                "Thank you all for your participation. The meeting is now concluded."
            ]
        ]
        
        let texts = transcriptions[language] ?? transcriptions["English"]!
        return texts[index % texts.count]
    }
    
    private func generateMockTranslation(index: Int, language: String) -> String {
        let translations: [String: [String]] = [
            "English": [
                "Welcome everyone to today's meeting. Let's start by reviewing the agenda.",
                "The quarterly report shows significant improvement in our key metrics.",
                "I think the next iteration should focus on user experience.",
                "Can we schedule a follow-up meeting to discuss implementation details?",
                "Thank you all for your participation. The meeting is now concluded."
            ],
            "Chinese": [
                "Welcome to our meeting today. Let's start by reviewing the agenda.",
                "The quarterly results show significant improvement in our key metrics.",
                "I believe we should focus on user experience in the next iteration.",
                "Can we schedule a follow-up meeting to discuss implementation details?",
                "Thank you all for your participation. The meeting is now concluded."
            ]
        ]
        
        let texts = translations[language] ?? translations["English"]!
        return texts[index % texts.count]
    }
}

// MARK: - 使RecordingSession符合Codable协议
extension RecordingSession: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, duration, date, fileSize, sessionStatus
        case sourceLanguage, targetLanguage, hasTranslation
        case priority, sessionType, filePath, wordCount, transcriptionQuality
        case segments, lastEditedAt, hasUnsavedChanges  // 新增字段
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 由于id是let常量且为UUID()，我们需要特殊处理
        let idString = try container.decode(String.self, forKey: .id)
        // 这里我们重新生成一个UUID，因为原始的UUID无法恢复
        
        name = try container.decode(String.self, forKey: .name)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        date = try container.decode(Date.self, forKey: .date)
        fileSize = try container.decode(String.self, forKey: .fileSize)
        sessionStatus = try container.decode(SessionStatus.self, forKey: .sessionStatus)
        sourceLanguage = try container.decode(String.self, forKey: .sourceLanguage)
        targetLanguage = try container.decodeIfPresent(String.self, forKey: .targetLanguage)
        hasTranslation = try container.decode(Bool.self, forKey: .hasTranslation)
        priority = try container.decode(Priority.self, forKey: .priority)
        sessionType = try container.decode(RecordingType.self, forKey: .sessionType)
        filePath = try container.decode(String.self, forKey: .filePath)
        wordCount = try container.decode(Int.self, forKey: .wordCount)
        transcriptionQuality = try container.decode(TranscriptionQuality.self, forKey: .transcriptionQuality)
        
        // 新增字段（向后兼容）
        segments = try container.decodeIfPresent([PlaybackSegment].self, forKey: .segments) ?? []
        lastEditedAt = try container.decodeIfPresent(Date.self, forKey: .lastEditedAt) ?? Date()
        hasUnsavedChanges = try container.decodeIfPresent(Bool.self, forKey: .hasUnsavedChanges) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(duration, forKey: .duration)
        try container.encode(date, forKey: .date)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(sessionStatus, forKey: .sessionStatus)
        try container.encode(sourceLanguage, forKey: .sourceLanguage)
        try container.encodeIfPresent(targetLanguage, forKey: .targetLanguage)
        try container.encode(hasTranslation, forKey: .hasTranslation)
        try container.encode(priority, forKey: .priority)
        try container.encode(sessionType, forKey: .sessionType)
        try container.encode(filePath, forKey: .filePath)
        try container.encode(wordCount, forKey: .wordCount)
        try container.encode(transcriptionQuality, forKey: .transcriptionQuality)
        
        // 新增字段
        try container.encode(segments, forKey: .segments)
        try container.encode(lastEditedAt, forKey: .lastEditedAt)
        try container.encode(hasUnsavedChanges, forKey: .hasUnsavedChanges)
    }
}

// MARK: - 让枚举符合Codable
extension RecordingSession.SessionStatus: Codable {}
extension RecordingSession.TranscriptionQuality: Codable {}
extension Priority: Codable {}
extension RecordingType: Codable {}

// MARK: - 示例数据（保持不变）
private let sampleSessions: [RecordingSession] = [
    RecordingSession(
        name: "Team Meeting",
        duration: 1800, // 30 minutes
        date: Date(),
        fileSize: "25.4 MB",
        sessionStatus: RecordingSession.SessionStatus.completed,
        sourceLanguage: "English",
        targetLanguage: "Chinese",
        hasTranslation: true,
        priority: Priority.important,
        sessionType: RecordingType.meeting,
        filePath: "/path/to/session1.m4a",
        wordCount: 4500,
        transcriptionQuality: RecordingSession.TranscriptionQuality.excellent
    ),
    RecordingSession(
        name: "Client Interview",
        duration: 2400, // 40 minutes
        date: Date().addingTimeInterval(-86400), // Yesterday
        fileSize: "32.1 MB",
        sessionStatus: RecordingSession.SessionStatus.live,
        sourceLanguage: "English",
        targetLanguage: Optional<String>.none,
        hasTranslation: false,
        priority: Priority.starred,
        sessionType: RecordingType.interview,
        filePath: "/path/to/session2.m4a",
        wordCount: 0,
        transcriptionQuality: RecordingSession.TranscriptionQuality.good
    ),
    RecordingSession(
        name: "Voice Memo",
        duration: 300, // 5 minutes
        date: Date().addingTimeInterval(-172800), // 2 days ago
        fileSize: "4.2 MB",
        sessionStatus: RecordingSession.SessionStatus.completed,
        sourceLanguage: "Chinese",
        targetLanguage: "English",
        hasTranslation: true,
        priority: Priority.normal,
        sessionType: RecordingType.memo,
        filePath: "/path/to/session3.m4a",
        wordCount: 750,
        transcriptionQuality: RecordingSession.TranscriptionQuality.good
    ),
    RecordingSession(
        name: "Conference Call",
        duration: 3600, // 60 minutes
        date: Date().addingTimeInterval(-259200), // 3 days ago
        fileSize: "48.7 MB",
        sessionStatus: RecordingSession.SessionStatus.error,
        sourceLanguage: "English",
        targetLanguage: "Chinese",
        hasTranslation: false,
        priority: Priority.normal,
        sessionType: RecordingType.call,
        filePath: "/path/to/session4.m4a",
        wordCount: 0,
        transcriptionQuality: RecordingSession.TranscriptionQuality.poor
    ),
    RecordingSession(
        name: "Lecture Recording",
        duration: 5400, // 90 minutes
        date: Date().addingTimeInterval(-604800), // One week ago
        fileSize: "72.3 MB",
        sessionStatus: RecordingSession.SessionStatus.paused,
        sourceLanguage: "English",
        targetLanguage: Optional<String>.none,
        hasTranslation: false,
        priority: Priority.normal,
        sessionType: RecordingType.lecture,
        filePath: "/path/to/session5.m4a",
        wordCount: 8200,
        transcriptionQuality: RecordingSession.TranscriptionQuality.fair
    )
] 