import SwiftUI

// MARK: - 网页版的小弹出菜单（popMenu）：从按钮下方弹出的白色圆角菜单

enum PopIcon {
    case asset(String)
    case template(String)
    case symbol(String)
}

struct PopItem: Identifiable {
    let id = UUID()
    var label: String
    var icon: PopIcon? = nil
    var on = false
    var red = false
    var sub: String? = nil
    var act: () -> Void
}

struct PopMenuState: Identifiable {
    let id = UUID()
    /// 按钮在屏幕上的位置（global 坐标）
    var anchor: CGRect
    var title: String? = nil
    var width: CGFloat = 180
    var items: [PopItem]
}

/// 盖在页面最上层；点空白处关闭。放在哪个视图里都可以，会自动换算坐标。
struct PopMenuLayer: View {
    @Binding var state: PopMenuState?
    @Environment(\.colorScheme) private var scheme
    @State private var shown = false
    @State private var menuH: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            if let st = state {
                let o = g.frame(in: .global).origin
                let W = g.size.width, H = g.size.height
                let a = st.anchor.offsetBy(dx: -o.x, dy: -o.y)
                let left = min(max(10, a.maxX - st.width), W - st.width - 10)
                let up = a.maxY + 6 + menuH > H - 16
                let top = up ? a.minY - menuH - 6 : a.maxY + 6
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture { close() }
                        .gesture(DragGesture(minimumDistance: 0).onEnded { _ in close() })
                    menu(st)
                        .frame(width: st.width)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { menuH = $0 }
                        .scaleEffect(shown ? 1 : 0.85, anchor: UnitPoint(x: (a.midX - left) / st.width, y: up ? 1 : 0))
                        .opacity(shown ? 1 : 0)
                        .offset(x: left, y: max(10, top))
                }
                .frame(width: W, height: H)
                .onAppear {
                    shown = false
                    withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.16)) { shown = true }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(state != nil)
    }

    private var dark: Bool { scheme == .dark }

    private func menu(_ st: PopMenuState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let t = st.title {
                Text(t).font(.system(size: 12)).foregroundStyle(Color(hex: "#A39888"))
                    .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 6)
            }
            ForEach(st.items) { it in
                Button {
                    close()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { it.act() }
                } label: {
                    HStack(spacing: 10) {
                        if let ic = it.icon {
                            iconView(ic, red: it.red).frame(width: 24, height: 24)
                        }
                        Text(it.label).font(.system(size: 15))
                            .foregroundStyle(it.red ? Color(hex: "#D2554A") : Theme.adaptive("#3E3532", "#F2EDE4"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let s = it.sub { Text(s).font(.system(size: 11)).foregroundStyle(Color(hex: "#A39888")).lineLimit(1) }
                        if it.on { Text("✓").font(.system(size: 15, weight: .heavy)).foregroundStyle(Color(hex: "#5E9E52")) }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(minHeight: 42)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(it.on ? Theme.adaptive("#F1F7EE", "#2E3A2A") : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PopRowStyle())
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#2F2E2B")))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(dark ? Color.white.opacity(0.06) : Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.08), lineWidth: 1))
        .compositingGroup()
        .shadow(color: dark ? .black.opacity(0.6) : Color(red: 60/255, green: 40/255, blue: 10/255).opacity(0.3), radius: 14, y: 10)
    }

    @ViewBuilder private func iconView(_ ic: PopIcon, red: Bool) -> some View {
        let tint = red ? Color(hex: "#D2554A") : Color(hex: "#8F857A")
        switch ic {
        case .asset(let n): Image(n).resizable().scaledToFit().frame(width: 22, height: 22)
        case .template(let n): Image(n).renderingMode(.template).resizable().scaledToFit().frame(width: 19, height: 19).foregroundStyle(tint)
        case .symbol(let n): Image(systemName: n).font(.system(size: 16, weight: .medium)).foregroundStyle(tint)
        }
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.14)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { state = nil }
    }
}

private struct PopRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(configuration.isPressed ? Theme.adaptive("#F4EFE6", "#3A3833") : .clear))
    }
}

/// 记下一个视图在屏幕上的位置（给弹出菜单定位用）
struct FrameReader: ViewModifier {
    @Binding var frame: CGRect
    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
    }
}

extension View {
    func readFrame(_ f: Binding<CGRect>) -> some View { modifier(FrameReader(frame: f)) }
}

// MARK: - 笔记卡片（打卡页、笔记列表共用；右上角 ⋮ 弹出菜单，向左滑可以删除）

struct JournalCardView: View {
    let day: String
    let entry: JournalEntry
    var lines = 1
    var onOpen: () -> Void
    var onMore: (CGRect) -> Void
    var onDelete: () -> Void

    @State private var moreFrame: CGRect = .zero
    @State private var dx: CGFloat = 0
    @State private var axis: Int = 0   // 0 未定 / 1 横向 / 2 竖向

    private let reveal: CGFloat = 84

    var body: some View {
        let untitled = entry.title.trimmingCharacters(in: .whitespaces).isEmpty
        let body = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = lines == 1 ? (body.components(separatedBy: .newlines).first ?? "") : body
        ZStack(alignment: .trailing) {
            // 左滑后露出的红色删除
            Button {
                Feedback.warn()
                withAnimation(.easeOut(duration: 0.2)) { dx = -600 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onDelete() }
            } label: {
                VStack(spacing: 4) {
                    Image("dg_trash").renderingMode(.template).resizable().frame(width: 20, height: 20)
                    Text("删除").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(width: max(reveal - 8, -dx - 8))
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#E5534B")))
            }
            .buttonStyle(.plain)
            .opacity(dx < -4 ? 1 : 0)
            .accessibilityLabel("删除笔记")

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(entry.displayTitle).font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(untitled ? PT.sub : PT.ink).lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(PT.jrPill))
                    Spacer(minLength: 8)
                    Button { Feedback.tap(); onMore(moreFrame) } label: {
                        Image(systemName: "ellipsis").rotationEffect(.degrees(90))
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(PT.jrMore)
                            .frame(width: 30, height: 30).background(Circle().fill(PT.jrPill))
                            .frame(width: 40, height: 34).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .readFrame($moreFrame)
                    .accessibilityLabel("更多")
                }
                .frame(height: 34)
                Text(Self.fullDT(entry.c)).font(.system(size: 12)).foregroundStyle(PT.jrTime).padding(.top, 6).padding(.bottom, 2)
                Text(shown.isEmpty ? " " : shown).font(.system(size: 14.5)).foregroundStyle(PT.ink)
                    .lineLimit(lines).multilineTextAlignment(.leading)
            }
            .padding(.leading, 14).padding(.trailing, 8).padding(.top, 10).padding(.bottom, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PT.jrBg))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(PT.jrLine, lineWidth: 1))
            .compositingGroup()
            .shadow(color: Color(red: 60/255, green: 50/255, blue: 20/255).opacity(0.07), radius: 3, y: 2)
            .contentShape(Rectangle())
            .onTapGesture {
                if dx != 0 { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dx = 0 }; return }
                onOpen()
            }
            .offset(x: dx)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { v in
                    if axis == 0 {
                        axis = abs(v.translation.width) > abs(v.translation.height) * 1.3 ? 1 : 2
                        if axis == 1 { dxStart = dx }
                    }
                    guard axis == 1 else { return }
                    let t = v.translation.width + (dxStart ?? 0)
                    dx = min(0, t < -reveal ? -reveal + (t + reveal) * 0.6 : t)
                }
                .onEnded { v in
                    defer { axis = 0; dxStart = nil }
                    guard axis == 1 else { return }
                    let t = v.predictedEndTranslation.width + (dxStart ?? 0)
                    if t < -260 {
                        Feedback.warn()
                        withAnimation(.easeOut(duration: 0.2)) { dx = -600 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onDelete() }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dx = t < -reveal / 2 ? -reveal : 0 }
                    }
                }
        )
    }

    @State private var dxStart: CGFloat?

    static func fullDT(_ ms: Double) -> String {
        let d = Date(timeIntervalSince1970: ms / 1000)
        let k = DK.key(d)
        return "\(DK.year(d))年\(DK.month(d))月\(DK.day(d))日 周\(DK.wdName[DK.weekday(k)]) \(DK.hm(ms))"
    }
}

extension Store {
    /// 笔记的 ⋮ 菜单：编辑、删除（直接删除）
    @MainActor
    func journalMenu(day: String, entry: JournalEntry, anchor: CGRect, toaster: Toaster, edit: @escaping () -> Void) -> PopMenuState {
        PopMenuState(anchor: anchor, width: 168, items: [
            PopItem(label: "编辑笔记", icon: .template("ep_pen"), act: edit),
            PopItem(label: "删除笔记", icon: .template("dg_trash"), red: true, act: { [weak self] in
                self?.deleteJournal(entry.id, on: day)
                Feedback.tap()
                toaster.show("已删除", gray: true)
            })
        ])
    }
}
