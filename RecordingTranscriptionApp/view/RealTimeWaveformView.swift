import SwiftUI

struct RealTimeWaveformView: View {
    let audioLevels: [Float]
    let isRecording: Bool
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<audioLevels.count, id: \.self) { index in
                    WaveformBar(
                        level: audioLevels[index],
                        maxHeight: geometry.size.height,
                        isRecording: isRecording
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct WaveformBar: View {
    let level: Float
    let maxHeight: CGFloat
    let isRecording: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(
                width: 4,
                height: max(4, CGFloat(level) * maxHeight)
            )
            .animation(.easeInOut(duration: 0.1), value: level)
    }
    
    private var barColor: Color {
        if !isRecording {
            return .gray.opacity(0.3)
        }
        
        // 根据音频级别决定颜色
        if level > 0.8 {
            return .red.opacity(0.9)
        } else if level > 0.5 {
            return .orange.opacity(0.8)
        } else if level > 0.2 {
            return .green.opacity(0.7)
        } else {
            return .blue.opacity(0.5)
        }
    }
}

// 静态波形显示（用于暂停状态）
struct StaticWaveformView: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<20, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(
                            width: 4,
                            height: geometry.size.height * 0.3
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RealTimeWaveformView(
            audioLevels: Array(repeating: 0.5, count: 20),
            isRecording: true
        )
        .frame(height: 40)
        .padding()
        
        StaticWaveformView()
            .frame(height: 40)
            .padding()
    }
} 