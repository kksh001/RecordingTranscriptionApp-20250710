//
//  ContentView.swift
//  RecordingTranscriptionApp
//
//  Created by kamakoma wu on 2025/5/11.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showDebugView = false
    
    var body: some View {
        TabView {
            // Main recording app
            RecordingListView()
                .tabItem {
                    Image(systemName: "mic.circle")
                    Text("Recording")
                }
            
            // Debug test page
            DebugTestView()
                .tabItem {
                    Image(systemName: "gear.circle")
                    Text("Debug")
                }
        }
    }

}

#Preview("iPhone 16 Pro Max") {
    ContentView()
        .environmentObject(RecordingSessionManager())
        .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro Max"))
        .previewDisplayName("iPhone 16 Pro Max")
}

#Preview("iPhone 16 Pro") {
    ContentView()
        .environmentObject(RecordingSessionManager())
        .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro"))
        .previewDisplayName("iPhone 16 Pro")
}

#Preview("iPhone 15 Pro") {
    ContentView()
        .environmentObject(RecordingSessionManager())
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
        .previewDisplayName("iPhone 15 Pro")
}
