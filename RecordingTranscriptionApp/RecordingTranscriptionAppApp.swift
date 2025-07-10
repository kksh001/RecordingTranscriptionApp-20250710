//
//  RecordingTranscriptionAppApp.swift
//  RecordingTranscriptionApp
//
//  Created by kamakoma wu on 2025/5/11.
//

import SwiftUI
import SwiftData

@main
struct RecordingTranscriptionAppApp: App {
    @StateObject private var sessionManager = RecordingSessionManager()
    @StateObject private var realtimeTranscriptionManager = RealTimeTranscriptionManager()
    // @StateObject private var languagePackManager = LanguagePackManager.shared // 已移除语言包管理器
    @StateObject private var networkRegionManager = NetworkRegionManager()
    @StateObject private var developerConfigManager = DeveloperConfigManager.shared
    @StateObject private var translationCacheManager = TranslationCacheManager.shared
    @State private var showFirstLaunchGuide = false
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // 简化的主界面（移除了Toast容器和首次启动引导）
            MainTabView()
                .environmentObject(sessionManager)
                .environmentObject(realtimeTranscriptionManager)
                .environmentObject(networkRegionManager)
                .environmentObject(developerConfigManager)
                .environmentObject(translationCacheManager)
        }
        .modelContainer(sharedModelContainer)
    }
    
    // private func checkFirstLaunch() {
    //     // 首次启动引导已移除
    // }
}
