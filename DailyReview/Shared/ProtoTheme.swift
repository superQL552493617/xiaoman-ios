import SwiftUI

/// 网页版 v256 的实际配色和尺寸（从网页的最终样式里量出来的）
enum PT {
    // 页面
    static let bg = Theme.adaptive("#FFFFFF", "#1B1B1A")
    /// 主页面（打卡、我的）深色模式下的底色，比弹窗再黑一点
    static let pageDark = Color(hex: "#111110")
    static let ink = Theme.adaptive("#232326", "#F2F2F7")          // 标题、主文字
    static let body = Theme.adaptive("#1C1C1E", "#F2F2F7")
    static let sub = Theme.adaptive("#6E6E73", "#A1A1A6")          // 次要说明
    static let faint = Theme.adaptive("#AEAEB2", "#6E6E73")        // 更淡的文字、箭头
    static let muted = Theme.adaptive("#9A9AA3", "#727279")        // 分组数量、日期
    static let iconGray = Theme.adaptive("#8E8E93", "#98989D")     // 标题旁的小图标
    // 小块背景
    static let chip = Theme.adaptive("#F5F5F7", "#262624")
    static let chipLine = Theme.adaptive("#E7E7EB", "#2F2E2B")
    static let stripItem = Theme.adaptive("#F2F2F7", "#262624")
    static let cvBg = Theme.adaptive("#D4D4D9", "#45443F")
    static let cvInk = Theme.adaptive("#FFFFFF", "#262624")
    static let hairline = Theme.adaptive("#EDEDF0", "#2C2C2A")
    // 卡片
    static let dotOff = Theme.adaptive("#FFFFFF", "#1E1E21")
    static let ringOff = Theme.adaptive("#E2E2E6", "#3A3A3E")
    static let tile = Theme.adaptive("#F2F2F5", "#262624")
    static let cheer = Theme.adaptive("#A39C92", "#7D776F")
    static let quickInk = Theme.adaptive("#424244", "#D1D1D6")
    // 底部栏
    static let tabOn = Theme.adaptive("#EDEDF0", "#FFFFFF24")
    // 笔记卡片
    static let jrBg = Theme.adaptive("#FBFAF6", "#262522")
    static let jrLine = Theme.adaptive("#E8E5DD", "#34322D")
    static let jrPill = Theme.adaptive("#EEECE5", "#34322D")
    static let jrTime = Theme.adaptive("#807C70", "#9A958A")
    static let jrMore = Theme.adaptive("#76806C", "#A7B09C")
    static let reviewDot = Color(hex: "#8DB98A")

    /// 打卡后的填充色、边框色
    static func fillOn(_ hex: String, dark: Bool) -> Color {
        let h = HexColor(hex).vivid
        return dark ? h.mix(HexColor("#121211"), 0.16).color : h.mixWhite(0.07).color
    }
    /// 卡片颜色（更鲜艳的版本）
    static func vivid(_ hex: String) -> Color { HexColor(hex).vivid.color }
    static func ringOn(_ hex: String, dark: Bool) -> Color {
        let h = HexColor(hex).vivid
        return dark ? h.mixWhite(0.20).color : h.mix(HexColor("#1A1A1A"), 0.45).color
    }

    /// 卡片名字的字体（和网页版的 5 种字体对应）
    static func cardFont(_ id: String?, size: CGFloat, weight: Font.Weight = .medium) -> Font {
        switch id {
        case "round", "chill": return .system(size: size, weight: weight, design: .rounded)
        case "song": return .custom("STSongti-SC-Regular", size: size).weight(weight)
        case "kai": return .custom("STKaiti", size: size).weight(weight)
        case "mono": return .system(size: size, weight: weight, design: .monospaced)
        default: return .system(size: size, weight: weight)
        }
    }

    /// 每行几个：loose 3 / dense 4 / compact 5
    static func columns(_ layout: String) -> Int { layout == "compact" ? 5 : layout == "dense" ? 4 : 3 }
    static func nameSize(_ layout: String) -> CGFloat { layout == "compact" ? 11 : layout == "dense" ? 12 : 13 }
    static func nameGap(_ layout: String) -> CGFloat { layout == "compact" ? 6 : layout == "dense" ? 7 : 10 }
    static func rowGap(_ layout: String) -> CGFloat { layout == "compact" ? 12 : layout == "dense" ? 16 : 22 }
    /// 网格按 56 排版；图标本身画小一点（50）
    static let dot: CGFloat = 56
    static let dotSize: CGFloat = 50
}
