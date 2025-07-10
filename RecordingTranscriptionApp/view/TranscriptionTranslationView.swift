import SwiftUI
import UIKit

struct TranscriptSegment: Identifiable, Hashable {
    let id: UUID = UUID()
    let text: String
    let timestamp: Date?
    
    // 便利初始化方法
    init(text: String, timestamp: Date? = nil) {
        self.text = text
        self.timestamp = timestamp
    }
}



struct OffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SyncedScrollView<Content: View>: UIViewRepresentable {
    @Binding var offset: CGFloat
    @Binding var syncOffset: CGFloat
    @Binding var isSyncing: Bool
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let hosting = UIHostingController(rootView: content())
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = true
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if !isSyncing && abs(uiView.contentOffset.y - syncOffset) > 1 {
            isSyncing = true
            uiView.setContentOffset(CGPoint(x: 0, y: syncOffset), animated: false)
            DispatchQueue.main.async {
                isSyncing = false
            }
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: SyncedScrollView
        init(_ parent: SyncedScrollView) { self.parent = parent }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !parent.isSyncing {
                parent.offset = scrollView.contentOffset.y
            }
        }
    }
}

struct TranscriptionTranslationView: View {
    // v2.0 简化的初始化参数
    let transcriptText: String
    let translatedText: String
    
    // 新增：支持传入PlaybackSegment数据
    let playbackSegments: [PlaybackSegment]?
    
    // 便利初始化方法
    init(transcriptText: String, translatedText: String, playbackSegments: [PlaybackSegment]? = nil) {
        self.transcriptText = transcriptText
        self.translatedText = translatedText
        self.playbackSegments = playbackSegments
    }
    
    // 翻译优化状态枚举
    enum TranslationOptimizationState {
        case idle, optimizing, completed
    }
    
    // v2.0 内部语言状态管理
    @State private var detectedSourceLanguage: String = "en" // 测试用：模拟检测到的录音语言
    @State private var systemLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"
    @State private var manualTargetLanguage: String? = nil // 用户手动选择的翻译语言
    @State private var showManualTranslation: Bool = false // 是否显示手动翻译选项
    @State private var translationOptimizationState: TranslationOptimizationState = .idle
    
    // 动态生成的转录分段数据（从PlaybackSegment或假数据）
    @State private var transcriptSegments: [TranscriptSegment] = []
    
    enum SectionType { case transcription, translation }
    @State private var expandedSection: SectionType? = nil
    @State private var showLanguageSheet = false
    let availableLanguages = ["English", "Chinese", "Spanish", "French", "German", "Japanese"]
    @State private var autoScrollToBottom = true
    @State private var showScrollToBottomButton = false
    @State private var currentSyncedId: UUID? = nil
    @State private var isSyncingScroll = false
    // 动态生成的翻译分段数据
    @State private var translationSegments: [TranscriptSegment] = []
    @State private var transcriptionOffset: CGFloat = 0
    @State private var translationOffset: CGFloat = 0
    
    // v2.0 智能显示逻辑
    var showTranslation: Bool {
        // 自动翻译：录音语言 ≠ 系统语言
        if !detectedSourceLanguage.isEmpty && detectedSourceLanguage != systemLanguage {
            return true
        }
        // 手动翻译：用户主动选择
        if showManualTranslation && manualTargetLanguage != nil {
            return true
        }
        return false
    }
    
    var currentTargetLanguage: String {
        return manualTargetLanguage ?? systemLanguage
    }
    
    // 语言显示名称映射
    func languageDisplayName(_ code: String) -> String {
        switch code {
        case "en": return "English"
        case "zh", "zh-Hans", "zh-CN": return "Chinese"
        case "es": return "Español"
        case "fr": return "Français"
        case "de": return "Deutsch"
        case "ja": return "日本語"
        default: return code
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let section = expandedSection {
                if section == .transcription {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Transcription")
                                .font(.system(size: 18, weight: .bold))
                            if !detectedSourceLanguage.isEmpty {
                                Text("(\(languageDisplayName(detectedSourceLanguage)))")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Back to Split View") {
                                withAnimation(.easeInOut(duration: 0.3)) { 
                                    expandedSection = nil 
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.systemGray6))
                        
                        TranscriptionSection(
                            segments: transcriptSegments,
                            autoScrollToBottom: $autoScrollToBottom,
                            showScrollToBottomButton: $showScrollToBottomButton,
                            currentSyncedId: $currentSyncedId,
                            isSyncingScroll: $isSyncingScroll
                        )
                    }
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Translation")
                                .font(.system(size: 18, weight: .bold))
                            Text("(\(languageDisplayName(currentTargetLanguage)))")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Back to Split View") {
                                withAnimation(.easeInOut(duration: 0.3)) { 
                                    expandedSection = nil 
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.systemGray6))
                        
                        TranslationSection(
                            segments: translationSegments,
                            onChangeLanguage: { 
                                showLanguageSheet = true
                                showManualTranslation = true
                            },
                            currentSyncedId: $currentSyncedId,
                            isSyncingScroll: $isSyncingScroll
                        )
                    }
                }
            } else if showTranslation {
                VStack(spacing: 0) {
                    // 转写区域
                    HStack {
                        Text("Transcription")
                            .font(.system(size: 16, weight: .semibold))
                        if !detectedSourceLanguage.isEmpty {
                            Text("(\(languageDisplayName(detectedSourceLanguage)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Long press to expand")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    
                    // 转录区域 - 卡片化显示
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(transcriptSegments) { segment in
                                VStack(alignment: .leading, spacing: 6) {
                                    // 时间戳
                                    HStack {
                                        Text(formatTimestamp(segment.timestamp ?? Date()))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                        Spacer()
                                    }
                                    
                                    // 转录内容
                                    Text(segment.text)
                                        .font(.body)
                                        .lineSpacing(4)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(10)
                                        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .onLongPressGesture {
                        withAnimation(.easeInOut(duration: 0.3)) { 
                            expandedSection = .transcription 
                        }
                    }
                    
                    // 翻译区域
                    HStack {
                        Text("Translation")
                            .font(.system(size: 16, weight: .semibold))
                        Text("(\(languageDisplayName(currentTargetLanguage)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Long press to expand")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    
                    // 翻译区域 - 卡片化显示
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(translationSegments) { segment in
                                VStack(alignment: .leading, spacing: 6) {
                                    // 时间戳
                                    HStack {
                                        Text(formatTimestamp(segment.timestamp ?? Date()))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.green)
                                            .cornerRadius(8)
                                        Spacer()
                                        Image(systemName: "globe")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    
                                    // 翻译内容
                                    Text(segment.text)
                                        .font(.body)
                                        .lineSpacing(4)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(10)
                                        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .onLongPressGesture {
                        withAnimation(.easeInOut(duration: 0.3)) { 
                            expandedSection = .translation 
                        }
                    }
                }
            } else {
                // 仅转写模式
                VStack(spacing: 0) {
                    HStack {
                        Text("Transcription")
                            .font(.system(size: 18, weight: .bold))
                        if !detectedSourceLanguage.isEmpty {
                            Text("(\(languageDisplayName(detectedSourceLanguage)))")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Edit Language") {
                            showLanguageSheet = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    
                    TranscriptionSection(
                        segments: transcriptSegments,
                        autoScrollToBottom: $autoScrollToBottom,
                        showScrollToBottomButton: $showScrollToBottomButton,
                        currentSyncedId: $currentSyncedId,
                        isSyncingScroll: $isSyncingScroll
                    )
                    
                    // Manual translation options
                    VStack(spacing: 16) {
                        if detectedSourceLanguage == systemLanguage || detectedSourceLanguage.isEmpty {
                            Button("🔄 Translate to other language") {
                                showLanguageSheet = true
                                showManualTranslation = true
                            }
                            .foregroundColor(.blue)
                            .padding(.vertical, 12)
                        }
                        
                        if showManualTranslation {
                            HStack {
                                Text("Manual translation:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Cancel Translation") {
                                    showManualTranslation = false
                                    manualTargetLanguage = nil
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .animation(.easeInOut, value: expandedSection)
        .background(Color.white)
        .onAppear {
            loadSegmentData()
            // 模拟翻译优化过程
            if showTranslation {
                translationOptimizationState = .optimizing
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    translationOptimizationState = .completed
                }
            }
        }
        .confirmationDialog("Select Language", isPresented: $showLanguageSheet, titleVisibility: .visible) {
            if showManualTranslation {
                // Manual translation language selection
                ForEach(availableLanguages.filter { languageCode(for: $0) != detectedSourceLanguage }, id: \.self) { lang in
                    Button(lang) {
                        manualTargetLanguage = languageCode(for: lang)
                        // 模拟翻译 - 后续会集成真实API
                        translationSegments = (1...20).map { index in
                            TranscriptSegment(
                                text: "[\(lang)] Translation segment \(index). " + String(repeating: "Sample translation. ", count: 5),
                                timestamp: Date().addingTimeInterval(TimeInterval(index * 30))
                            )
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    showManualTranslation = false
                }
            } else {
                // Source language correction
                ForEach(availableLanguages, id: \.self) { lang in
                    Button(lang) {
                        detectedSourceLanguage = languageCode(for: lang)
                        // 模拟重新转写 - 后续会集成真实API
                        transcriptSegments = (1...20).map { index in
                            TranscriptSegment(
                                text: "[\(lang)] Transcript segment \(index). " + String(repeating: "Sample text. ", count: 5),
                                timestamp: Date().addingTimeInterval(TimeInterval(index * 30))
                            )
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    // 辅助函数：获取语言代码
    private func languageCode(for displayName: String) -> String {
        switch displayName {
        case "English": return "en"
        case "Chinese": return "zh"
        case "Spanish": return "es"
        case "French": return "fr"
        case "German": return "de"
        case "Japanese": return "ja"
        default: return "en"
        }
    }
    
    // 时间戳格式化函数
    private func formatTimestamp(_ date: Date) -> String {
        return date.formatted(date: .omitted, time: .standard)  // 显示格式如 "2:30:45 PM"
    }
    
    // MARK: - 数据加载方法
    private func loadSegmentData() {
        if let segments = playbackSegments, !segments.isEmpty {
            // 使用真实的PlaybackSegment数据
            transcriptSegments = segments.map { segment in
                TranscriptSegment(
                    text: segment.currentTranscription,
                    timestamp: Date(timeIntervalSince1970: segment.startTime)
                )
            }
            
            translationSegments = segments.map { segment in
                TranscriptSegment(
                    text: segment.currentTranslation.isEmpty ? "No translation available" : segment.currentTranslation,
                    timestamp: Date(timeIntervalSince1970: segment.startTime)
                )
            }
        } else {
            // 回退到假数据
            transcriptSegments = createFakeTranscriptSegments()
            translationSegments = createFakeTranslationSegments()
        }
    }
    
    private func createFakeTranscriptSegments() -> [TranscriptSegment] {
        return (1...20).map { index in
            TranscriptSegment(
                text: "This is transcript segment number \(index). " + String(repeating: "Sample text content for testing purposes. ", count: 3),
                timestamp: Date().addingTimeInterval(TimeInterval(-3600 + index * 180)) // 从1小时前开始，每3分钟一段
            )
        }
    }
    
    private func createFakeTranslationSegments() -> [TranscriptSegment] {
        return (1...20).map { index in
            TranscriptSegment(
                text: "This is translation segment number \(index). " + String(repeating: "Sample translation content. ", count: 3),
                timestamp: Date().addingTimeInterval(TimeInterval(-3600 + index * 180)) // 对应的时间戳
            )
        }
    }
}

struct TranscriptionSection: View {
    let segments: [TranscriptSegment]
    @Binding var autoScrollToBottom: Bool
    @Binding var showScrollToBottomButton: Bool
    @Binding var currentSyncedId: UUID?
    @Binding var isSyncingScroll: Bool
    @State private var scrollToId: UUID? = nil

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(segments) { segment in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(formatTimestamp(segment.timestamp ?? Date()))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(6)
                                    Spacer()
                                }
                                
                                Text(segment.text)
                                    .font(.body)
                                    .lineSpacing(6)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                            .id(segment.id)
                            .padding(.horizontal, 16)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            if !isSyncingScroll {
                                                currentSyncedId = segment.id
                                            }
                                        }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 16)
                }
                .gesture(
                    DragGesture().onChanged { _ in
                        autoScrollToBottom = false
                        showScrollToBottomButton = true
                    }
                )
                .onChange(of: segments.count) { oldCount, newCount in
                    if autoScrollToBottom, let last = segments.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: scrollToId) { oldId, newId in
                    if let id = newId {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                        scrollToId = nil
                    }
                }
                .onChange(of: currentSyncedId) { oldId, newId in
                    guard let id = newId, !isSyncingScroll else { return }
                    isSyncingScroll = true
                    withAnimation {
                        proxy.scrollTo(id, anchor: .top)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isSyncingScroll = false
                    }
                }
            }
            if showScrollToBottomButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            if let last = segments.last {
                                scrollToId = last.id
                                autoScrollToBottom = true
                                showScrollToBottomButton = false
                            }
                        }) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "arrow.down")
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .medium))
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                        .zIndex(1)
                    }
                }
                .allowsHitTesting(true)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        return date.formatted(date: .omitted, time: .standard)
    }
}

struct TranslationSection: View {
    let segments: [TranscriptSegment]
    let onChangeLanguage: () -> Void
    @Binding var currentSyncedId: UUID?
    @Binding var isSyncingScroll: Bool
    @State private var scrollToId: UUID? = nil
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(segments) { segment in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(formatTimestamp(segment.timestamp ?? Date()))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(6)
                                    Spacer()
                                    Image(systemName: "globe")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                
                                Text(segment.text)
                                    .font(.body)
                                    .lineSpacing(6)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                            .id(segment.id)
                            .padding(.horizontal, 16)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            if !isSyncingScroll {
                                                currentSyncedId = segment.id
                                            }
                                        }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: currentSyncedId) { oldId, newId in
                    guard let id = newId, !isSyncingScroll else { return }
                    isSyncingScroll = true
                    withAnimation {
                        proxy.scrollTo(id, anchor: .top)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isSyncingScroll = false
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        return date.formatted(date: .omitted, time: .standard)
    }
}

struct TranscriptionTranslationView_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptionTranslationView(
            transcriptText: "Sample transcript text",
            translatedText: "Sample translated text"
        )
    }
}

// MARK: - 翻译优化指示器组件
struct TranslationOptimizingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.title2)
                .foregroundColor(.blue)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
            
            Text("Optimizing Translation...")
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
} 
