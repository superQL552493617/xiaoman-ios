import SwiftUI

// MARK: - 轻提示

@MainActor
final class Toaster: ObservableObject {
    @Published var text: String?
    @Published var gray = false
    private var task: Task<Void, Never>?

    func show(_ t: String, gray: Bool = false) {
        self.gray = gray
        withAnimation(.spring(response: 0.3)) { text = t }
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_300_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self?.text = nil }
        }
    }
}

struct ToastView: View {
    let text: String
    let gray: Bool
    var body: some View {
        Text(text)
            .font(.app(size: 14, weight: .medium))
            .foregroundStyle(gray ? Theme.text : .white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(
                Capsule().fill(gray ? Theme.adaptive("#E8E5DF", "#3A3834") : Color(hex: "#1E1E20").opacity(0.9))
            )
            .compositingGroup()
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .padding(.horizontal, 40)
    }
}

// MARK: - 底部导航

enum AppTab: String, CaseIterable, Identifiable {
    case today, bars, ai, memory, journal, me
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: return "打卡"
        case .bars: return "习惯"
        case .ai: return "统计"
        case .memory: return "回忆"
        case .journal: return "笔记"
        case .me: return "我的"
        }
    }
    /// 选中时文字的颜色（网页版每个页签不同）
    var onHex: String {
        switch self {
        case .today: return "#F5B92E"
        case .bars: return "#6FA8DC"
        case .ai: return "#7DBF8A"
        case .memory: return "#E57BA0"
        case .journal: return "#8C8FD9"
        case .me: return "#F29D38"
        }
    }
    /// 底部栏显示哪几个（打卡、我的固定，中间三格可以换）
    static func keys(_ p: Prefs) -> [AppTab] {
        [.today] + p.tabSlots.compactMap { AppTab(rawValue: $0) } + [.me]
    }
}

struct FloatingTabBar: View {
    @Binding var tab: AppTab
    var showLabels: Bool
    var size: String = "m"
    var keys: [AppTab] = [.today, .bars, .ai, .me]
    /// 「笔记」不是页面：点了直接写今天的笔记
    var onJournal: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    @State private var bounce: [AppTab: Int] = [:]

    struct Squash { var y: CGFloat = 0; var sx: CGFloat = 1; var sy: CGFloat = 1 }

    /// 网页版：小 56/27，中 66/36，大 76/42
    private var barH: CGFloat { size == "s" ? 56 : size == "l" ? 76 : 66 }
    private var iconS: CGFloat { size == "s" ? 27 : size == "l" ? 42 : 36 }

    var body: some View {
        GeometryReader { g in
            HStack(spacing: 4) {
                ForEach(keys) { t in item(t) }
            }
            .padding(7)
            .frame(width: min(330, g.size.width - 64), height: barH)
            .background {
                if scheme == .dark {
                    Capsule().fill(Color.black.opacity(0.25)).background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                        .shadow(color: .black.opacity(0.7), radius: 12, y: 8)
                } else {
                    Capsule().fill(Color.white)
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.035), lineWidth: 1))
                        .shadow(color: Color(red: 20/255, green: 20/255, blue: 30/255).opacity(0.18), radius: 15, y: 10)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: barH)
    }

    private func item(_ t: AppTab) -> some View {
        let on = tab == t
        return Button {
            if t == .journal { Feedback.tap(); bounce[t, default: 0] += 1; onJournal(); return }
            guard tab != t else { return }
            Feedback.tap()
            tab = t
            bounce[t, default: 0] += 1
        } label: {
            VStack(spacing: 2) {
                Image("tb_\(t.rawValue)_\(on ? "on" : "off")").resizable().scaledToFit()
                    .frame(width: iconS, height: iconS)
                    .keyframeAnimator(initialValue: Squash(), trigger: bounce[t, default: 0]) { v, q in
                        v.scaleEffect(x: q.sx, y: q.sy, anchor: UnitPoint(x: 0.5, y: 0.9)).offset(y: q.y)
                    } keyframes: { _ in
                        KeyframeTrack(\.y) {
                            CubicKeyframe(-6, duration: 0.11); CubicKeyframe(0, duration: 0.085)
                            CubicKeyframe(-2, duration: 0.065); CubicKeyframe(0, duration: 0.055)
                        }
                        KeyframeTrack(\.sx) {
                            CubicKeyframe(1.08, duration: 0.11); CubicKeyframe(1.1, duration: 0.085)
                            CubicKeyframe(0.98, duration: 0.065); CubicKeyframe(1, duration: 0.055)
                        }
                        KeyframeTrack(\.sy) {
                            CubicKeyframe(1.16, duration: 0.11); CubicKeyframe(0.9, duration: 0.085)
                            CubicKeyframe(1.03, duration: 0.065); CubicKeyframe(1, duration: 0.055)
                        }
                    }
                if showLabels {
                    Text(t.title).font(.app(size: 10.5, weight: .semibold))
                        .foregroundStyle(on ? Color(hex: t.onHex) : (scheme == .dark ? Color(hex: "#636366") : Color(hex: "#C2C2C7")))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { if on { Capsule().fill(PT.tabOn) } }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - 常用小组件

/// 浅灰色胶囊按钮
struct PillButtonStyle: ButtonStyle {
    var fill: Color = Theme.tile
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14).frame(height: 34)
            .background(Capsule().fill(fill))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// 主按钮（深色大按钮）
struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(size: 16, weight: .bold))
            .frame(maxWidth: .infinity).frame(height: 50)
            .foregroundStyle(enabled ? Theme.adaptive("#FFFFFF", "#2A2724") : Theme.text3)
            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(enabled ? Theme.text : Theme.tile))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// 浅黄色按钮（保存 / 确认）
struct YellowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(size: 15, weight: .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16).frame(height: 36)
            .background(Capsule().fill(Color(hex: "#FFE7A3")))
            .overlay(Capsule().stroke(Theme.ink.opacity(0.7), lineWidth: 1.2))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// 弹出菜单顶部：左按钮 · 标题 · 右按钮
struct SheetHeader<L: View, R: View>: View {
    let title: String
    @ViewBuilder var leading: () -> L
    @ViewBuilder var trailing: () -> R
    var body: some View {
        ZStack {
            Text(title).font(.app(size: 17, weight: .bold)).foregroundStyle(Theme.text)
            HStack {
                leading()
                Spacer()
                trailing()
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }
}

struct CloseButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.app(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                .frame(width: 36, height: 36).background(Circle().fill(Theme.tile))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("关闭")
    }
}

/// 卡片式分组背景
struct CardBox<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#0C0C0C")))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.sep.opacity(0.6), lineWidth: 1))
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}

/// 设置列表里的一行
struct RowLabel: View {
    var icon: String
    var tint: Color = Theme.text
    var title: String
    var sub: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.app(size: 16, weight: .medium)).foregroundStyle(tint)
                .frame(width: 32, height: 32).background(RoundedRectangle(cornerRadius: 10).fill(Theme.tile))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.app(size: 15.5)).foregroundStyle(Theme.text)
                if let sub { Text(sub).font(.app(size: 12)).foregroundStyle(Theme.text3) }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SectionTitle: View {
    let text: String
    var sub: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text).font(.app(size: 18, weight: .bold)).foregroundStyle(Theme.text)
            if let sub { Text(sub).font(.app(size: 12)).foregroundStyle(Theme.text3) }
            Spacer()
        }
    }
}

extension View {
    /// 页面通用背景
    func pageBackground() -> some View {
        self.background(Theme.pageBg.ignoresSafeArea())
    }
}

/// 简单的流式布局（分组标签等）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, w: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            w = max(w, x)
        }
        return CGSize(width: min(w, maxW), height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
