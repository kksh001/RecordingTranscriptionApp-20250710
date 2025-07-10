import SwiftUI
import AVFoundation

class MicrophonePermissionManager: ObservableObject {
    @Published var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    
    init() {
        checkPermissionStatus()
    }
    
    func checkPermissionStatus() {
        permissionStatus = AVAudioSession.sharedInstance().recordPermission
    }
    
    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.checkPermissionStatus()
            }
        }
    }
    
    var isPermissionGranted: Bool {
        return permissionStatus == .granted
    }
    
    var isPermissionDenied: Bool {
        return permissionStatus == .denied
    }
    
    var isPermissionUndetermined: Bool {
        return permissionStatus == .undetermined
    }
} 