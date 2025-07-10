import SwiftUI
import Foundation

// Recording Session Data Model (Real-time transcription session)
struct RecordingSession: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
    let date: Date
    let fileSize: String
    let sessionStatus: SessionStatus
    let sourceLanguage: String
    let targetLanguage: String?
    let hasTranslation: Bool
    let priority: Priority
    let sessionType: RecordingType
    let filePath: String
    let wordCount: Int
    let transcriptionQuality: TranscriptionQuality
    var segments: [PlaybackSegment] = []  // 🔥 添加缺失的段落数据
    var lastEditedAt: Date = Date()       // 🔥 添加最后编辑时间
    var hasUnsavedChanges: Bool = false   // 🔥 添加未保存更改标记
    
    // 为了保持Codable支持，添加detectedLanguage别名
    var detectedLanguage: String { sourceLanguage }
    
    enum SessionStatus: String, CaseIterable {
        case live = "Live"
        case paused = "Paused" 
        case completed = "Completed"
        case error = "Error"
        
        var color: Color {
            switch self {
            case .live: return .red
            case .paused: return .orange
            case .completed: return .green
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .live: return "record.circle.fill"
            case .paused: return "pause.circle.fill"
            case .completed: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    enum TranscriptionQuality: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            }
        }
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable conformance
    static func == (lhs: RecordingSession, rhs: RecordingSession) -> Bool {
        lhs.id == rhs.id
    }
}

// Filter Options
enum FilterOption: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case live = "Live Sessions"
    case completed = "Completed"
}

// Sort Options
enum SortOption: String, CaseIterable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case nameAZ = "Name A-Z"
    case nameZA = "Name Z-A"
    case duration = "Duration"
}

struct RecordingListView: View {
    @State private var sessions: [RecordingSession] = sampleSessions
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all
    @State private var selectedSort: SortOption = .newest
    @State private var showingFilterSheet = false
    @State private var selectedSession: RecordingSession?
    @State private var sessionToDelete: RecordingSession?
    @State private var showingDeleteAlert = false
    
    var filteredAndSortedSessions: [RecordingSession] {
        let filtered = sessions.filter { session in
            // Search filter
            let matchesSearch = searchText.isEmpty || 
                session.name.localizedCaseInsensitiveContains(searchText)
            
            // Type filter
            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .today:
                matchesFilter = Calendar.current.isDateInToday(session.date)
            case .thisWeek:
                matchesFilter = Calendar.current.isDate(session.date, equalTo: Date(), toGranularity: .weekOfYear)
            case .thisMonth:
                matchesFilter = Calendar.current.isDate(session.date, equalTo: Date(), toGranularity: .month)
            case .live:
                matchesFilter = session.sessionStatus == .live || session.sessionStatus == .paused
            case .completed:
                matchesFilter = session.sessionStatus == .completed
            }
            
            return matchesSearch && matchesFilter
        }
        
        // Sort
        return filtered.sorted { first, second in
            switch selectedSort {
            case .newest:
                return first.date > second.date
            case .oldest:
                return first.date < second.date
            case .nameAZ:
                return first.name < second.name
            case .nameZA:
                return first.name > second.name
            case .duration:
                return first.duration > second.duration
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText)
                
                // Filter and Sort Bar
                FilterSortBar(
                    selectedFilter: $selectedFilter,
                    selectedSort: $selectedSort,
                    showingFilterSheet: $showingFilterSheet
                )
                
                // Recording Sessions List
                if filteredAndSortedSessions.isEmpty {
                    EmptyStateView(hasSessions: !sessions.isEmpty, searchText: searchText)
                } else {
                    List {
                        ForEach(filteredAndSortedSessions) { session in
                            RecordingSessionRowView(session: session)
                                .onTapGesture {
                                    selectedSession = session
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        sessionToDelete = session
                                        showingDeleteAlert = true
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .tint(.red)
                                    
                                    Button {
                                        // Rename functionality
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .tint(.orange)
                                    
                                    Button {
                                        // Share functionality
                                    } label: {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Recording Sessions")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $selectedSession) { session in
            NavigationView {
                RecordingPlaybackView(
                    recordingName: session.name,
                    audioURL: URL(fileURLWithPath: session.filePath),
                    sessionId: session.id
                )
            }
        }
        .confirmationDialog("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this recording session? This action cannot be undone.")
        }
    }
    
    private func deleteSession(_ session: RecordingSession) {
        withAnimation {
            sessions.removeAll { $0.id == session.id }
        }
        sessionToDelete = nil
    }
}

// Search Bar Component
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search sessions...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .foregroundColor(.blue)
                .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// Filter Sort Bar Component
struct FilterSortBar: View {
    @Binding var selectedFilter: FilterOption
    @Binding var selectedSort: SortOption
    @Binding var showingFilterSheet: Bool
    
    var body: some View {
        HStack {
            // Filter button
            Menu {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        selectedFilter = option
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(selectedFilter.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Sort button
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        selectedSort = option
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(selectedSort.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// Recording Session Row Component
struct RecordingSessionRowView: View {
    let session: RecordingSession
    @State private var showingMetadataEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // First row: Session name and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack {
                        Text(session.sessionType.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                        
                                                    if session.priority == Priority.important {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                                                 } else if session.priority == Priority.starred {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Image(systemName: session.sessionStatus.icon)
                            .foregroundColor(session.sessionStatus.color)
                        Text(session.sessionStatus.rawValue)
                            .font(.caption)
                            .foregroundColor(session.sessionStatus.color)
                    }
                    
                    if session.hasTranslation {
                        HStack {
                            Image(systemName: "globe")
                                .font(.caption)
                            Text("Translated")
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                    }
                    
                    // 编辑按钮
                    Button(action: {
                        showingMetadataEdit = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            
            // Second row: Time, duration, file size
            HStack {
                Label(formatDate(session.date), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Label(formatDuration(session.duration), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Label(session.fileSize, systemImage: "doc")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Third row: Language info and transcription quality
            HStack {
                HStack {
                    Image(systemName: "mic")
                        .font(.caption)
                    Text(session.sourceLanguage)
                        .font(.caption)
                }
                .foregroundColor(.blue)
                
                if let targetLang = session.targetLanguage {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "globe")
                            .font(.caption)
                        Text(targetLang)
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
                
                Spacer()
                
                // Transcription quality indicator
                HStack {
                    Circle()
                        .fill(session.transcriptionQuality.color)
                        .frame(width: 8, height: 8)
                    Text(session.transcriptionQuality.rawValue)
                        .font(.caption)
                        .foregroundColor(session.transcriptionQuality.color)
                }
            }
            
            // Fourth row: Word count (for completed sessions)
            if session.sessionStatus == .completed {
                HStack {
                    Image(systemName: "text.alignleft")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(session.wordCount) words")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingMetadataEdit) {
            RecordingDetailView(meta: RecordingMetaData(
                date: session.date,
                source: "iOS App",
                duration: Int(session.duration)
            ))
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return "Today " + formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.timeStyle = .short
            return "Yesterday " + formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Empty State View
struct EmptyStateView: View {
    let hasSessions: Bool
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasSessions ? "magnifyingglass" : "mic.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(hasSessions ? "No matching sessions" : "No recording sessions")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(hasSessions ? "Try adjusting your search or filter options" : "Tap the + button to start your first recording session")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            if !hasSessions {
                NavigationLink(destination: NewRecordingView()) {
                    HStack {
                        Image(systemName: "mic.circle.fill")
                        Text("Start Recording")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.top)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// Sample Data - Real-time transcription sessions
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

struct RecordingListView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingListView()
    }
} 