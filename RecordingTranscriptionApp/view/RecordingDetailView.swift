import SwiftUI
import CoreLocation

class RecordingMetaData: ObservableObject {
    @Published var recordingName: String = ""
    @Published var subtitle: String = ""
    @Published var participants: String = ""
    @Published var location: String = ""
    @Published var tags: String = ""
    @Published var priority: Priority = .normal
    @Published var recordingType: RecordingType = .meeting
    @Published var note: String = ""
    let recordingDate: Date
    let recordingSource: String
    @Published var duration: Int = 0
    @Published var sourceLanguage: String = "Chinese"
    @Published var targetLanguage: String = "English"
    init(date: Date, source: String, duration: Int) {
        self.recordingDate = date
        self.recordingSource = source
        self.duration = duration
    }
}

enum Priority: String, CaseIterable, Identifiable { case normal, important, starred; var id: String { rawValue } }
enum RecordingType: String, CaseIterable, Identifiable { case meeting, interview, memo, call, lecture; var id: String { rawValue } }

struct RecordingDetailView: View {
    @ObservedObject var meta: RecordingMetaData
    @State private var isEditingName: Bool = false
    @State private var tempRecordingName: String = ""
    @State private var showNameSavedAlert: Bool = false
    @StateObject private var locationManager = LocationManager()
    let languages = ["Chinese", "English", "Spanish"]
    @AppStorage("defaultTargetLanguage") private var defaultTargetLanguage: String = "English"
    @State private var showSetDefaultAlert: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 录音名称
                VStack(spacing: 8) {
                    Text("Recording Name")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                    if isEditingName {
                        HStack {
                            Spacer()
                            TextField("Enter recording name", text: $tempRecordingName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: 220)
                            Button(action: {
                                meta.recordingName = tempRecordingName
                                isEditingName = false
                                showNameSavedAlert = true
                            }) {
                                Text("Confirm")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text(meta.recordingName.isEmpty ? "(No name)" : meta.recordingName)
                                .foregroundColor(.blue)
                                .font(.title3)
                                .bold()
                            Button(action: {
                                tempRecordingName = meta.recordingName
                                isEditingName = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                    Text("Edit")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            Spacer()
                        }
                    }
                }
                .alert(isPresented: $showNameSavedAlert) {
                    Alert(title: Text("Name Updated"), message: Text("Recording name has been updated."), dismissButton: .default(Text("OK")))
                }
                // 日期时间
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                    Text(dateTimeString(from: meta.recordingDate))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                // 副标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subtitle").font(.subheadline)
                    TextField("Enter subtitle", text: $meta.subtitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                // 参与人
                VStack(alignment: .leading, spacing: 8) {
                    Text("Participants").font(.subheadline)
                    TextField("Enter participants (comma separated)", text: $meta.participants)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                // Location（自动识别特殊地点）
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location").font(.subheadline)
                    HStack {
                        TextField("Auto-detect or enter location", text: $meta.location)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: {
                            locationManager.requestLocation()
                        }) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .onReceive(locationManager.$address) { newAddress in
                        if !newAddress.isEmpty && newAddress != "Unknown Location" && newAddress != meta.location {
                            meta.location = newAddress
                        }
                    }
                    Text("Tap the location icon to auto-detect special places (hotel, building, company, etc). If not found, will use regular address.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                // 标签
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags").font(.subheadline)
                    TextField("Enter tags (comma separated)", text: $meta.tags)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                // 重要级别
                VStack(alignment: .leading, spacing: 8) {
                    Text("Priority").font(.subheadline)
                    Picker("Priority", selection: $meta.priority) {
                        ForEach(Priority.allCases) { p in
                            Text(p.rawValue.capitalized).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                // 录音类型
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type").font(.subheadline)
                    Picker("Type", selection: $meta.recordingType) {
                        ForEach(RecordingType.allCases) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                // 备注
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note (optional)").font(.subheadline)
                    TextEditor(text: $meta.note)
                        .frame(height: 60)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
                // 自动生成字段
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                    Text("Duration: \(timeString(from: meta.duration))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                HStack {
                    Image(systemName: "tray")
                        .foregroundColor(.gray)
                    Text("Source: \(meta.recordingSource)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                // 语言选择区
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcription Language (Auto-detectable)").font(.subheadline)
                    Picker("Transcription Language", selection: $meta.sourceLanguage) {
                        ForEach(languages, id: \.self) { lang in
                            Text(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                    Text("* The system can auto-detect and switch transcription language during recording.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Translation Language").font(.subheadline)
                        if meta.targetLanguage == defaultTargetLanguage {
                            Text("(Default)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Button(action: {
                                defaultTargetLanguage = meta.targetLanguage
                                showSetDefaultAlert = true
                            }) {
                                Text("Set as Default")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    Picker("Translation Language", selection: $meta.targetLanguage) {
                        ForEach(languages, id: \.self) { lang in
                            Text(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                    Text("* Translation will always use your selected language. Default is \(defaultTargetLanguage).")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                // 转写/翻译模式提示
                if meta.sourceLanguage == meta.targetLanguage {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Only transcription will be performed. No translation.")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.green)
                        Text("Transcription and translation will be performed.")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Recording Details")
        .alert(isPresented: $showSetDefaultAlert) {
            Alert(title: Text("Default Language Updated"), message: Text("Default translation language has been set to \(defaultTargetLanguage)."), dismissButton: .default(Text("OK")))
        }
    }

    private func timeString(from seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    private func dateTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// CoreLocation辅助类
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var address: String = ""
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    override init() {
        super.init()
        manager.delegate = self
    }
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                if let areas = placemark.areasOfInterest, !areas.isEmpty {
                    self.address = areas.first!
                } else if let name = placemark.name {
                    self.address = name
                } else if let thoroughfare = placemark.thoroughfare, let subLocality = placemark.subLocality, let locality = placemark.locality {
                    self.address = "\(locality)\(subLocality)\(thoroughfare)"
                } else if let locality = placemark.locality {
                    self.address = locality
                } else {
                    self.address = "Unknown Location"
                }
            } else {
                self.address = "Unknown Location"
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.address = "Location Error"
    }
}

struct RecordingDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let meta = RecordingMetaData(date: Date(), source: "Local Recording", duration: 123)
        RecordingDetailView(meta: meta)
    }
} 