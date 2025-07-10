import SwiftUI

/// 屏幕尺寸检测工具
struct ScreenSize {
    
    /// 获取当前屏幕尺寸
    static var current: CGSize {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            return CGSize(width: 393, height: 852) // iPhone 14 Pro default
        }
        return window.screen.bounds.size
    }
    
    /// 屏幕宽度
    static var width: CGFloat {
        return current.width
    }
    
    /// 屏幕高度
    static var height: CGFloat {
        return current.height
    }
    
    /// 是否为紧凑布局（小屏幕）
    static var isCompact: Bool {
        return width <= 390 // iPhone 12 mini and smaller
    }
    
    /// 是否为常规布局（中等屏幕）
    static var isRegular: Bool {
        return width > 390 && width <= 430 // iPhone 12/13/14/15 Pro Max range
    }
    
    /// 是否为大屏布局
    static var isLarge: Bool {
        return width > 430 // iPad and larger
    }
    
    /// 自适应间距
    static var adaptiveSpacing: CGFloat {
        if isCompact {
            return 8
        } else if isRegular {
            return 12
        } else {
            return 16
        }
    }
    
    /// 自适应边距
    static var adaptivePadding: CGFloat {
        if isCompact {
            return 12
        } else if isRegular {
            return 16
        } else {
            return 20
        }
    }
}