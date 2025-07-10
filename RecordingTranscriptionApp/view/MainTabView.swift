import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var selectedTab: Tab = .record
    
    enum Tab: String, CaseIterable {
        case sessions = "sessions"
        case record = "record"
        case test = "test"
        case settings = "settings"
        
        var title: String {
            switch self {
            case .sessions: return "Sessions"
            case .record: return "Record"
            case .test: return "测试"
            case .settings: return "Settings"
            }
        }
        
        var icon: String {
            switch self {
            case .sessions: return "waveform"
            case .record: return "mic.circle"
            case .test: return "gear.circle"
            case .settings: return "gearshape"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .sessions: return "waveform.circle.fill"
            case .record: return "mic.circle.fill"
            case .test: return "gear.circle.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Recording Sessions Tab
            RecordingListView()
                .tabItem {
                    Image(systemName: selectedTab == .sessions ? Tab.sessions.selectedIcon : Tab.sessions.icon)
                    Text(Tab.sessions.title)
                }
                .tag(Tab.sessions)
            
            // New Recording Tab
            NavigationView {
                NewRecordingView()
            }
            .tabItem {
                Image(systemName: selectedTab == .record ? Tab.record.selectedIcon : Tab.record.icon)
                Text(Tab.record.title)
            }
            .tag(Tab.record)
            
            // Test Tab
            NavigationView {
                DebugTestView()
            }
            .tabItem {
                Image(systemName: selectedTab == .test ? Tab.test.selectedIcon : Tab.test.icon)
                Text(Tab.test.title)
            }
            .tag(Tab.test)
            
            // Settings Tab
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: selectedTab == .settings ? Tab.settings.selectedIcon : Tab.settings.icon)
                Text(Tab.settings.title)
            }
            .tag(Tab.settings)
        }
        .accentColor(.blue)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        // Set up basic tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        // Normal state
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray
        ]
        
        // Selected state
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

#Preview("iPhone 16 Pro Max") {
    MainTabView()
        .environmentObject(RecordingSessionManager())
        .environmentObject(RealTimeTranscriptionManager())
        .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro Max"))
        .previewDisplayName("iPhone 16 Pro Max")
}

#Preview("iPhone 16 Pro") {
    MainTabView()
        .environmentObject(RecordingSessionManager())
        .environmentObject(RealTimeTranscriptionManager())
        .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro"))
        .previewDisplayName("iPhone 16 Pro")
}

#Preview("iPhone 15 Pro") {
    MainTabView()
        .environmentObject(RecordingSessionManager())
        .environmentObject(RealTimeTranscriptionManager())
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
        .previewDisplayName("iPhone 15 Pro")
} 