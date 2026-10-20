import SwiftUI
import UIKit

// MARK: - 颜色工具

extension Color {
    /// "#RRGGBB" → Color
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        var r, g, b: Double, a = 1.0
        if s.count == 3 {
            r = Double((v >> 8) & 0xF) / 15; g = Double((v >> 4) & 0xF) / 15; b = Double(v & 0xF) / 15
        } else if s.count == 8 {
            r = Double((v >> 24) & 0xFF) / 255; g = Double((v >> 16) & 0xFF) / 255; b = Double((v >> 8) & 0xFF) / 255; a = Double(v & 0xFF) / 255
        } else {
            r = Double((v >> 16) & 0xFF) / 255; g = Double((v >> 8) & 0xFF) / 255; b = Double(v & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// 十六进制颜色的简单计算（混白、亮度），用来生成卡片的浅色和文字颜色
struct HexColor {
    let r: Double, g: Double, b: Double

    init(_ hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        r = Double((v >> 16) & 0xFF) / 255
        g = Double((v >> 8) & 0xFF) / 255
        b = Double(v & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }

    /// t = 0 原色，t = 1 白色
    func mixWhite(_ t: Double) -> HexColor {
        HexColor(r: r + (1 - r) * t, g: g + (1 - g) * t, b: b + (1 - b) * t)
    }

    func mix(_ o: HexColor, _ t: Double) -> HexColor {
        HexColor(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }

    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    /// 提高饱和度（HSL 里的 S 乘以 k，亮度不变）
    func saturated(_ k: Double) -> HexColor {
        let mx = max(r, g, b), mn = min(r, g, b), l = (mx + mn) / 2
        guard mx - mn > 0.0001 else { return self }
        let d = mx - mn
        var s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: Double
        if mx == r { h = (g - b) / d + (g < b ? 6 : 0) } else if mx == g { h = (b - r) / d + 2 } else { h = (r - g) / d + 4 }
        h /= 6
        s = min(1, s * k)
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q
        func f(_ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }; if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 0.5 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        return HexColor(r: f(h + 1.0 / 3), g: f(h), b: f(h - 1.0 / 3))
    }

    /// 界面上显示卡片颜色时统一用这个：比存下来的颜色更鲜艳一些
    var vivid: HexColor { saturated(1.2) }

    var hex: String {
        String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

/// 一张卡片用到的三种颜色：浅色 a、主色 b、图标上的文字颜色 fg
struct CardColors {
    let a: Color
    let b: Color
    let fg: Color
    let base: HexColor

    init(hex: String) {
        let h = HexColor(hex)
        base = h
        a = h.mixWhite(0.38).color
        b = h.color
        fg = h.luminance > 0.42 ? Color(hex: "#1C1C1E") : .white
    }

    /// 和白色按比例混合（0 = 原色）
    func tint(_ t: Double) -> Color { base.mixWhite(t).color }
    /// 和深色背景混合（深色模式用）
    func dark(_ t: Double) -> Color { base.mix(HexColor("#1B1B1A"), t).color }
}

// MARK: - App 的固定配色

enum Theme {
    static let ink = Color(hex: "#3E3532")
    static let ink2 = Color(hex: "#7D7266")
    static let ink3 = Color(hex: "#A39888")
    static let cream = Color(hex: "#F7F4EE")
    static let line = Color(hex: "#ECE6DB")
    static let green = Color(hex: "#5CB874")
    static let yellow = Color(hex: "#FFE7A3")
    static let vipGold = LinearGradient(colors: [Color(hex: "#F7D774"), Color(hex: "#E9A93C")], startPoint: .topLeading, endPoint: .bottomTrailing)

    /// 自适应：浅色 / 深色
    static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }

    static let pageBg = adaptive("#FFFFFF", "#1B1B1A")
    static let pageBgDim = adaptive("#FFFFFF", "#1E1E1D")
    static let tile = adaptive("#F4F1EA", "#262624")
    static let tile2 = adaptive("#F7F4EE", "#2F2D2A")
    static let card = adaptive("#FFFFFF", "#0C0C0C")
    static let text = adaptive("#3E3532", "#F2EDE4")
    static let text2 = adaptive("#7D7266", "#A39A8E")
    static let text3 = adaptive("#A39888", "#7D756B")
    static let sep = adaptive("#ECE6DB", "#3A3732")
    static let pill = adaptive("#F2F2F5", "#2A2A28")

    /// 卡片颜色板（和原型一致）
    static let palette: [String] = [
        "#FF3B30", "#FF2D55", "#FF6B00", "#FF9F0A", "#FFD60A", "#A3E635", "#32D74B", "#00C7BE", "#00B0FF", "#0A84FF", "#5E5CE6", "#AF52DE",
        "#F5C542", "#F0B955", "#F29D38", "#D9653B", "#EC6F6B", "#E0525A", "#B23F57", "#F2CBA0",
        "#F3A6B8", "#E57BA0", "#C86FB0", "#A77BD6", "#8A63D2", "#6E5BB8", "#C9B8EA", "#F0D5E0",
        "#9CD3E0", "#62B6E0", "#3D8FE0", "#2F67C9", "#2B4C8C", "#50A8B0", "#7FB7BE", "#BFD7EA",
        "#86A99E", "#A9B6A0", "#7DBF8A", "#4CAF6A", "#2E8B57", "#B7D96B", "#E6E36A", "#D8D9A0",
        "#D6C7B0", "#B89B7A", "#8C6E54", "#A3A7B0", "#6B7080", "#3F4556", "#1F2230"
    ]

    /// 首页选中日期的底色
    static let dateColors: [(id: String, name: String, hex: String)] = [
        ("green", "浅绿", "#CDEBD3"), ("mint", "薄荷", "#C4EAE4"), ("sky", "天蓝", "#CFE3F7"),
        ("lilac", "浅紫", "#E1D9F5"), ("pink", "樱粉", "#F8D7DF"), ("apricot", "杏黄", "#FBE5B6"), ("classic", "经典黑", "#1C1C1E")
    ]

    static let barPastel = ["#BFE3C9", "#FDE2A7", "#F9CDD3", "#CFE0F4", "#E2D8F3", "#FBD9BF", "#CDEBE6", "#F3E3B6", "#D8E9C5", "#F6D3E4", "#D6E3F0", "#EADFCF"]

    static let cheer = [
        "慢慢来，比较快。今天多做的一点点，都会悄悄变成你的底气。",
        "不必每天都满分，愿意回来继续，本身就很了不起。",
        "习惯像存钱，每一次打卡都是一枚硬币，时间会替你算利息。",
        "给自己一点耐心，你正在变成自己喜欢的样子。",
        "偶尔停下来没关系，重要的是你还记得出发的理由。",
        "把大目标拆成今天能做的小事，剩下的交给时间。"
    ]
}

// MARK: - 心情

struct Mood: Identifiable, Hashable {
    let id: String
    let name: String
    var asset: String { "mood_" + id }

    static let all: [Mood] = [
        Mood(id: "great", name: "超开心"), Mood(id: "good", name: "不错"), Mood(id: "meh", name: "平平"),
        Mood(id: "tired", name: "有点累"), Mood(id: "down", name: "低落")
    ]
    static func find(_ id: String?) -> Mood? { all.first { $0.id == id } }
}

// MARK: - 字体

enum AppFont {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    /// 笔记字体：sys 系统 / round 圆体 / kai 楷体（衬线）
    static func note(_ id: String?, size: CGFloat) -> Font {
        switch id {
        case "round", "chill": return .system(size: size, design: .rounded)
        case "kai", "song", "serif": return .system(size: size, design: .serif)
        default: return .system(size: size)
        }
    }
}
