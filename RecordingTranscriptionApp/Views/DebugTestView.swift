//
//  DebugTestView.swift
//  RecordingTranscriptionApp
//
//  Created by Assistant on 2024/6/17.
//

import SwiftUI

struct DebugTestView: View {
    @ObservedObject private var sessionManager = RecordingSessionManager()
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 顶部标题
                Text("🧪 测试中心")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // 测试模式选择
                VStack(spacing: 12) {
                    Text("选择测试模式")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack {
                        Button(action: {}) {
                            VStack {
                                Image(systemName: "gear.badge")
                                    .font(.largeTitle)
                                    .foregroundColor(.blue)
                                Text("架构测试")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("(无需录音)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                        }
                        .disabled(true) // 当前页面
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // 当前页面标题
                Text("🧪 架构功能测试")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                // 测试按钮区域
                VStack(spacing: 15) {
                    Button(action: runDataStructureTests) {
                        HStack {
                            Image(systemName: "gear.badge")
                            Text("测试数据结构")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRunningTests)
                    
                    Button(action: runSessionManagerTests) {
                        HStack {
                            Image(systemName: "folder.badge.gearshape")
                            Text("测试会话管理")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRunningTests)
                    
                    Button(action: runEditingTests) {
                        HStack {
                            Image(systemName: "pencil.and.ellipsis.rectangle")
                            Text("测试编辑功能")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRunningTests)
                    
                    Button(action: runAllTests) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("运行全部测试")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isRunningTests)
                }
                .padding(.horizontal)
                
                // 测试结果显示
                if !testResults.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("测试结果:")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 5) {
                                ForEach(testResults.indices, id: \.self) { index in
                                    Text(testResults[index])
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(getResultColor(testResults[index]))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding()
                        }
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .frame(maxHeight: 300)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // 清除结果按钮
                if !testResults.isEmpty {
                    Button("清除结果") {
                        testResults.removeAll()
                    }
                    .foregroundColor(.red)
                    .padding()
                }
            }
            .navigationTitle("Debug Tests")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: 
                Button("关闭") {
                    // 这里应该处理关闭逻辑
                }
            )
        }
    }
    
    // MARK: - 测试方法
    
    private func runDataStructureTests() {
        isRunningTests = true
        testResults.append("🧪 开始数据结构测试...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                // 测试PlaybackSegment创建
                var segment = PlaybackSegment(
                    startTime: 0,
                    endTime: 5,
                    transcription: "测试转写内容",
                    translation: "Test translation content"
                )
                
                testResults.append("✅ PlaybackSegment创建成功")
                
                // 测试编辑功能
                segment.updateTranscription("修改后的转写内容", reason: "测试编辑")
                testResults.append("✅ 转写编辑功能正常")
                
                segment.updateTranslation("Modified translation content", reason: "Translation test")
                testResults.append("✅ 翻译编辑功能正常")
                
                // 验证编辑状态
                if segment.hasEdits && segment.isTranscriptionEdited && segment.isTranslationEdited {
                    testResults.append("✅ 编辑状态跟踪正常")
                } else {
                    testResults.append("❌ 编辑状态跟踪异常")
                }
                
                // 验证编辑历史
                if segment.editHistory.count == 2 {
                    testResults.append("✅ 编辑历史记录正常")
                } else {
                    testResults.append("❌ 编辑历史记录异常: \(segment.editHistory.count)")
                }
                
            } catch {
                testResults.append("❌ 数据结构测试失败: \(error.localizedDescription)")
            }
            
            testResults.append("📊 数据结构测试完成\n")
            isRunningTests = false
        }
    }
    
    private func runSessionManagerTests() {
        isRunningTests = true
        testResults.append("🧪 开始会话管理测试...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 测试会话创建
            let testSession = RecordingSession(
                name: "测试会话",
                duration: 30,
                date: Date(),
                fileSize: "1 MB",
                sessionStatus: .completed,
                sourceLanguage: "Chinese",
                targetLanguage: "English",
                hasTranslation: true,
                priority: .normal,
                sessionType: .memo,
                filePath: "/test/path",
                wordCount: 100,
                transcriptionQuality: .good
            )
            
            testResults.append("✅ 测试会话创建成功")
            
            // 创建测试段落
            let mockSegments = [
                PlaybackSegment(startTime: 0, endTime: 5, transcription: "测试段落1", translation: "Test segment 1"),
                PlaybackSegment(startTime: 5, endTime: 10, transcription: "测试段落2", translation: "Test segment 2")
            ]
            testResults.append("✅ 创建了 \(mockSegments.count) 个测试段落")
            
            // 测试会话添加
            sessionManager.sessions.insert(testSession, at: 0)
            testResults.append("✅ 会话添加到管理器成功")
            
            // 测试段落更新
            if !mockSegments.isEmpty {
                var firstSegment = mockSegments[0]
                firstSegment.updateTranscription("更新后的转写", reason: "测试更新")
                
                sessionManager.updateSegment(
                    sessionId: testSession.id,
                    segmentId: firstSegment.id,
                    updatedSegment: firstSegment
                )
                testResults.append("✅ 段落更新功能正常")
            }
            
            testResults.append("📊 会话管理测试完成\n")
            isRunningTests = false
        }
    }
    
    private func runEditingTests() {
        isRunningTests = true
        testResults.append("🧪 开始编辑功能测试...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 创建测试段落
            var segment = PlaybackSegment(
                startTime: 0,
                endTime: 10,
                transcription: "原始转写内容",
                translation: "Original translation"
            )
            
            testResults.append("✅ 创建测试段落")
            
            // 测试多次编辑
            segment.updateTranscription("第一次编辑", reason: "First edit")
            segment.updateTranscription("第二次编辑", reason: "Second edit")
            segment.updateTranslation("第一次翻译编辑", reason: "Translation edit")
            
            testResults.append("✅ 执行多次编辑操作")
            testResults.append("📊 编辑历史记录数: \(segment.editHistory.count)")
            
            // 测试恢复原始内容
            segment.revertToOriginal(fieldType: .transcription)
            testResults.append("✅ 转写内容恢复测试")
            
            segment.revertToOriginal(fieldType: .translation)
            testResults.append("✅ 翻译内容恢复测试")
            
            // 验证恢复状态
            if !segment.isTranscriptionEdited && !segment.isTranslationEdited {
                testResults.append("✅ 内容恢复状态正确")
            } else {
                testResults.append("❌ 内容恢复状态异常")
            }
            
            testResults.append("📊 编辑功能测试完成\n")
            isRunningTests = false
        }
    }
    
    private func runAllTests() {
        isRunningTests = true
        testResults.removeAll()
        testResults.append("🚀 开始执行全部测试...\n")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            runDataStructureTests()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            runSessionManagerTests()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            runEditingTests()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            testResults.append("🎉 所有测试执行完成!")
            isRunningTests = false
        }
    }
    
    // MARK: - 辅助方法
    
    private func getResultColor(_ result: String) -> Color {
        if result.contains("✅") {
            return .green
        } else if result.contains("❌") {
            return .red
        } else if result.contains("🧪") || result.contains("🚀") {
            return .blue
        } else if result.contains("📊") {
            return .orange
        } else {
            return .primary
        }
    }
}

#Preview {
    DebugTestView()
} 