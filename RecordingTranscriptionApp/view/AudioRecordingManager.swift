import AVFoundation
import SwiftUI

class AudioRecordingManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentRecordingDuration: TimeInterval = 0
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 20) // 20个音频柱状
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    
    // 当前录制的文件信息
    @Published var currentRecordingURL: URL?
    @Published var currentRecordingName: String = ""
    
    // MARK: - Recording Settings
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        AVEncoderBitRateKey: 128000
    ]
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Recording Functions
    func startRecording() {
        guard !isRecording else { return }
        
        do {
            // 生成录制文件URL
            let recordingURL = generateRecordingURL()
            currentRecordingURL = recordingURL
            
            // 创建录制器
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: recordingSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // 开始录制
            let success = audioRecorder?.record() ?? false
            
            if success {
                DispatchQueue.main.async {
                    self.isRecording = true
                    self.isPaused = false
                    self.recordingStartTime = Date()
                    self.currentRecordingDuration = 0
                    self.pausedDuration = 0
                    self.startTimers()
                    self.errorMessage = nil
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to start recording"
                }
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Recording setup failed: \(error.localizedDescription)"
            }
        }
    }
    
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        audioRecorder?.pause()
        stopTimers()
        
        DispatchQueue.main.async {
            self.isPaused = true
        }
    }
    
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        let success = audioRecorder?.record() ?? false
        
        if success {
            DispatchQueue.main.async {
                self.isPaused = false
                self.startTimers()
            }
        } else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to resume recording"
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        stopTimers()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.isPaused = false
            self.audioLevels = Array(repeating: 0.0, count: 20)
        }
    }
    
    // MARK: - Timer Management
    private func startTimers() {
        // 录制时长计时器
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateRecordingDuration()
        }
        
        // 音频级别计时器
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.updateAudioLevels()
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        
        DispatchQueue.main.async {
            if !self.isPaused {
                self.currentRecordingDuration = Date().timeIntervalSince(startTime) - self.pausedDuration
            }
        }
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // 转换分贝值到0-1范围
        let normalizedLevel = pow(10.0, (averagePower + 60) / 60.0)
        
        DispatchQueue.main.async {
            // 更新音频级别数组，产生波形效果
            for i in 0..<self.audioLevels.count {
                let randomVariation = Float.random(in: 0.7...1.3)
                self.audioLevels[i] = max(0.1, min(1.0, normalizedLevel * randomVariation))
            }
        }
    }
    
    // MARK: - File Management
    private func generateRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        // 创建Recordings目录
        try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        
        // 生成唯一文件名
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let fileName = "Recording_\(timestamp).m4a"
        
        DispatchQueue.main.async {
            self.currentRecordingName = "Recording \(timestamp.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: ":"))"
        }
        
        return recordingsPath.appendingPathComponent(fileName)
    }
    
    // MARK: - Utility Functions
    func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    func getCurrentRecordingInfo() -> (url: URL?, name: String, duration: TimeInterval) {
        return (currentRecordingURL, currentRecordingName, currentRecordingDuration)
    }
    
    // MARK: - Error Handling
    func clearError() {
        DispatchQueue.main.async {
            self.errorMessage = nil
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async {
            if flag {
                print("Recording finished successfully")
                print("Recording saved to: \(recorder.url)")
            } else {
                self.errorMessage = "Recording failed to finish properly"
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async {
            self.errorMessage = "Recording encode error: \(error?.localizedDescription ?? "Unknown error")"
            self.stopRecording()
        }
    }
} 