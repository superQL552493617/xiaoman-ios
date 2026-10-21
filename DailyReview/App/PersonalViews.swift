import SwiftUI
import PhotosUI
import UserNotifications

// MARK: - 网页版「页面背景」主题（浅色模式才显示）

enum PageTheme {
    /// id, 名字, 底色
    static let all: [(id: String, name: String, base: String, dot: String)] = [
        ("white", "纯白", "#FFFFFF", "#F1F1F3"), ("cream", "米白", "#FAF7F0", "#EFE6D2"), ("mist", "雾灰", "#F3F4F6", "#E1E3E8"),
        ("sky", "晴空", "#F2F7FD", "#BBD5F2"), ("sage", "青草", "#F3F8F3", "#C3DCC6"), ("peach", "暖杏", "#FDF6F0", "#F3CFB2"),
        ("dots", "点阵", "#FBFBFA", "#D6D6D2"), ("grid", "方格", "#FCFCFA", "#E2E1DA"), ("dream", "梦幻", "#E6EEF1", "#9FD0E2"),
        ("fog", "雾光", "#FBF8F2", "#EADBC8"), ("beach", "浅滩", "#F8F7F2", "#DCDDD2"), ("plaid", "格子夏日", "#FAFCFE", "#4FA8C7"),
        ("forest", "柔林", "#F7F7F2", "#D2DCCB")
    ]
    static func base(_ id: String) -> String { all.first { $0.id == id }?.base ?? "#FFFFFF" }
    static func name(_ p: Prefs) -> String {
        if p.pageBg == "custom" { return "自定义背景" }
        return all.first { $0.id == p.pageBg }?.name ?? "纯白"
    }
}

/// 页面背景：底色 + 渐变 / 点阵 / 方格 / 光晕 / 自定义图片
struct PageBG: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var scheme
    var id: String? = nil
    var preview = false

    var body: some View {
        let pid = id ?? store.s.prefs.pageBg
        if scheme == .dark && !preview {
            PT.pageDark
        } else if pid == "custom", let ui = ImageData.image(store.s.prefs.bgImg) {
            GeometryReader { g in
                Image(uiImage: ui).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped()
            }
        } else {
            ZStack(alignment: .top) {
                Color(hex: PageTheme.base(pid))
                pattern(pid)
            }
        }
    }

    private func blob(_ c: String, _ rx: CGFloat, _ ry: CGFloat, _ x: CGFloat, _ y: CGFloat, _ g: CGSize) -> some View {
        Ellipse()
            .fill(EllipticalGradient(gradient: Gradient(stops: [.init(color: Color(hex: c), location: 0), .init(color: Color(hex: c).opacity(0), location: 0.7)]),
                                     center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
            .frame(width: g.width * rx * 2, height: g.height * ry * 2)
            .position(x: g.width * x, y: g.height * y)
    }

    @ViewBuilder private func pattern(_ id: String) -> some View {
        switch id {
        case "sky": topFade("#E6F0FC", "#F7FAFE")
        case "sage": topFade("#E5F1E6", "#F7FBF7")
        case "peach": topFade("#FBE9DA", "#FEF9F5")
        case "dots":
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height { var x: CGFloat = 0
                    while x < size.width { ctx.fill(Path(ellipseIn: CGRect(x: x - 1.15, y: y - 1.15, width: 2.3, height: 2.3)), with: .color(Color(hex: "#DADAD6"))); x += 18 }
                    y += 18 }
            }
        case "grid":
            Canvas { ctx, size in
                var p = Path()
                var y: CGFloat = 0; while y < size.height { p.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)); y += 22 }
                var x: CGFloat = 0; while x < size.width { p.addRect(CGRect(x: x, y: 0, width: 1, height: size.height)); x += 22 }
                ctx.fill(p, with: .color(Color(hex: "#EEEDE8")))
            }
        case "plaid":
            Canvas { ctx, size in
                let c = Color(red: 110/255, green: 155/255, blue: 200/255).opacity(0.16)
                var y: CGFloat = 0; while y < size.height { ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 9)), with: .color(c)); y += 24 }
                var x: CGFloat = 0; while x < size.width { ctx.fill(Path(CGRect(x: x, y: 0, width: 9, height: size.height)), with: .color(c)); x += 24 }
            }
        case "dream":
            GeometryReader { g in
                ZStack {
                    LinearGradient(stops: [.init(color: Color(hex: "#E9DED2"), location: 0), .init(color: Color(hex: "#DCE9EE"), location: 0.55), .init(color: Color(hex: "#EEF3F5"), location: 1)], startPoint: .top, endPoint: .bottom)
                    blob("#7DBEDD", 1.1, 0.6, 0, 0.72, g.size)
                    blob("#F7BBA4", 0.9, 0.45, 0.75, 1, g.size)
                }
            }
        case "fog": GeometryReader { g in blob("#F4DCC6", 0.75, 0.4, 1, 1, g.size) }
        case "beach": GeometryReader { g in ZStack { blob("#D3E0D7", 0.85, 0.32, 0.95, 1, g.size); blob("#E6E2D6", 0.5, 0.2, 0, 1, g.size) } }
        case "forest": GeometryReader { g in ZStack { blob("#D9E2D1", 0.55, 0.26, 0.12, 1, g.size); blob("#CFDAC6", 0.5, 0.22, 0.88, 1, g.size) } }
        default: EmptyView()
        }
    }

    /// 顶部一段渐变。用 GeometryReader 按可用高度算，不给缩略图一个固定高度（否则缩略图会被撑变形）
    private func topFade(_ a: String, _ b: String) -> some View {
        GeometryReader { g in
            LinearGradient(colors: [Color(hex: a), Color(hex: b)], startPoint: .top, endPoint: .bottom)
                .frame(width: g.size.width, height: preview ? g.size.height : min(420, g.size.height))
        }
    }
}

// MARK: - 共用小部件：网页版的开关、列表行、带图标的小方块

/// 网页版的开关：62×28，绿色
struct ProtoSwitch: View {
    var on: Bool
    var action: () -> Void
    var body: some View {
        Button { action() } label: {
            ZStack(alignment: on ? .trailing : .leading) {
                Capsule().fill(on ? Color(hex: "#34C759") : Theme.adaptive("#7878802E", "#FFFFFF29"))
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white)
                    .frame(width: 37, height: 24)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                    .padding(2)
            }
            .frame(width: 62, height: 28)
            .animation(.easeOut(duration: 0.22), value: on)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(on ? "开" : "关")
    }
}

enum Pastel {
    static let tiles = ["#FFE7A3", "#CFE6FA", "#FBD3D3", "#D3EFD9", "#E3DAF7", "#FFDCC2"]
    static func at(_ i: Int) -> String { tiles[i % tiles.count] }
}

/// 列表里的彩色小方块图标（34×34、深色描边）
struct TileIcon: View {
    var icon: String
    var bg: String
    var danger = false
    var size: CGFloat = 22
    var body: some View {
        Image(icon).renderingMode(.template).resizable().scaledToFit().frame(width: size, height: size)
            .foregroundStyle(danger ? Color(hex: "#C9463D") : Color(hex: "#4A3F45"))
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(hex: danger ? "#FBD3D3" : bg)))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(danger ? Color(hex: "#C9463D") : Color(hex: "#4A3F45"), lineWidth: 1.4))
    }
}

/// 白底圆角行（网页版 .sheet .li）
struct SheetRow<Content: View>: View {
    var dim = false
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 12) { content }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .frame(minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(WT.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(WT.line, lineWidth: 1))
            .opacity(dim ? 0.45 : 1)
            .contentShape(Rectangle())
    }
}

struct Chevron: View {
    var body: some View { Text("›").font(.system(size: 20)).foregroundStyle(Color(hex: "#9A9AA3")) }
}

/// 弹出页顶部：‹ 返回 · 标题 · 右侧按钮（白色半透明，内容从下面滑过）
struct PageTop<R: View>: View {
    var title: String
    var back: () -> Void
    @ViewBuilder var right: R
    var body: some View {
        ZStack {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body)
            HStack {
                Button(action: back) {
                    Text("‹").font(.system(size: 30)).foregroundStyle(PT.body).padding(.bottom, 3).frame(width: 40, height: 40).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                Spacer()
                right.frame(minWidth: 40)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Theme.adaptive("#FFFFFFE6", "#1E1E1DE6"))
        .background(.ultraThinMaterial)
    }
}

extension PageTop where R == EmptyView {
    init(title: String, back: @escaping () -> Void) { self.title = title; self.back = back; self.right = EmptyView() }
}

/// 一个可以滚动的弹出页（顶部固定）
struct NavPage<Content: View, R: View>: View {
    var title: String
    var right: R
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    init(_ title: String, @ViewBuilder right: () -> R, @ViewBuilder content: () -> Content) {
        self.title = title; self.right = right(); self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { PageTop(title: title, back: { dismiss() }) { right } }
        .background(Theme.adaptive("#FFFFFF", "#1E1E1D").ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension NavPage where R == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) { self.init(title, right: { EmptyView() }, content: content) }
}

/// 网页版的小标题、说明
struct PPHead: View {
    var title: String
    var sub: String? = nil
    var big = false
    var top: CGFloat = 22
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: big ? 21 : 17, weight: .bold)).foregroundStyle(PT.ink)
                .padding(.top, big ? 8 : top).padding(.bottom, big ? 4 : 10)
            if let sub { Text(sub).font(.system(size: 13.5)).foregroundStyle(PT.faint).padding(.bottom, 14) }
        }
        .padding(.horizontal, 4)
    }
}

/// 一个预览用的小打卡图标（个性化里用）
struct PvIcon: View {
    static let icons: [(String, String)] = [("喝水", "1F964"), ("阅读", "1F4DA"), ("运动", "C-DUMBBELL"), ("早起", "23F0"), ("吃早餐", "1F373"),
                                            ("早睡", "C-BED"), ("吃水果", "1F34E"), ("健身", "1F4AA"), ("冥想", "1F9D8"), ("骑行", "1F6B2")]
    static let pvHex = ["#7DB7E8", "#F29D38", "#A58BD6", "#F5C542", "#F3A6B8", "#8C8FD9", "#E66A5E", "#7DBF8A", "#C49BD6", "#50A8B0"]
    static let icHex = ["#F29D38", "#7DB7E8", "#E9A0B4", "#8CC59A", "#B39DDB", "#F5C542", "#E8836B", "#6EC1C4", "#E66A7A"]
    var i: Int
    var shape: String
    var line: String
    var hex: String? = nil
    var on = true
    var size: CGFloat = 56
    var showName = true
    var pulse = 0

    var body: some View {
        let it = Self.icons[i % Self.icons.count]
        VStack(spacing: 6) {
            ProtoDot(card: Card(id: "pv\(i)", name: it.0, icon: it.1, hex: hex ?? Self.pvHex[i % Self.pvHex.count]), on: on, shape: shape, line: line, size: size, pulse: pulse)
            if showName { Text(it.0).font(.system(size: 11.5)).foregroundStyle(PT.sub).lineLimit(1) }
        }
    }
}

// MARK: - 设置（右上角 ✓ 关闭）

struct SettingsSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @Environment(\.dismiss) private var dismiss
    @State private var path: [String] = []
    @State private var ask: AskKind?
    @State private var showTime = false

    enum AskKind: String, Identifiable { case cache, reset, reset2, quit; var id: String { rawValue } }

    private var P: Prefs { store.s.prefs }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        Text("设置").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body).padding(.bottom, 6)
                        HStack {
                            Spacer()
                            Button { dismiss() } label: {
                                Text("✓").font(.system(size: 15, weight: .bold)).foregroundStyle(WT.yellowInk)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(WT.yellow))
                                    .overlay(Circle().strokeBorder(WT.yellowInk, lineWidth: 1))
                                    .compositingGroup()
                                    .shadow(color: Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.4), radius: 8, y: 6)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("完成")
                        }
                    }
                    .frame(height: 36).padding(.bottom, 14)

                    group {
                        navRow(0, "st_lock", "密码锁定", P.lockOn ? "已开启" : "") { path.append("lock") }
                    }
                    group {
                        navRow(0, "st_home", "首页显示内容", nil) { path.append("home") }
                    }
                    group {
                        SheetRow {
                            TileIcon(icon: "st_bell", bg: Pastel.at(1))
                            label("每日提醒")
                            ProtoSwitch(on: P.daily.on) { toggleDaily() }
                        }
                        SheetRow(dim: !P.daily.on) {
                            TileIcon(icon: "stg_clock", bg: Pastel.at(2))
                            label("提醒时间")
                            Button { if P.daily.on { showTime = true } } label: {
                                Text(String(format: "%02d:%02d", P.daily.h, P.daily.m)).font(.system(size: 16, weight: .semibold)).monospacedDigit()
                                    .foregroundStyle(PT.ink).padding(.horizontal, 12).frame(height: 34)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.adaptive("#E9E9EC", "#3A3936")))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    group {
                        SheetRow {
                            TileIcon(icon: "stg_calendar", bg: Pastel.at(3))
                            label("每周从哪天算起")
                            seg([(1, "周一"), (0, "周日")], P.weekStart == 0 ? 0 : 1) { v in store.updatePrefs { $0.weekStart = v } }
                        }
                    }
                    group {
                        SheetRow {
                            TileIcon(icon: "st_sound", bg: Pastel.at(4))
                            label("按键声音")
                            ProtoSwitch(on: P.sound) {
                                store.updatePrefs { $0.sound.toggle() }
                                if store.s.prefs.sound { SFX.play(SFX.inSound) }
                            }
                        }
                        SheetRow {
                            TileIcon(icon: "st_hand", bg: Pastel.at(5))
                            label("按键震动")
                            ProtoSwitch(on: P.haptic) { store.updatePrefs { $0.haptic.toggle() }; Feedback.hapticOn = store.s.prefs.haptic; Feedback.tap() }
                        }
                    }
                    group {
                        SheetRow {
                            TileIcon(icon: "st_moon", bg: Pastel.at(0))
                            label("跟随系统暗黑模式")
                            ProtoSwitch(on: P.mode == "system") { store.updatePrefs { $0.mode = $0.mode == "system" ? "light" : "system" } }
                        }
                        SheetRow {
                            TileIcon(icon: "st_badge", bg: Pastel.at(1))
                            label("关闭通知角标")
                            ProtoSwitch(on: P.noBadge) {
                                store.updatePrefs { $0.noBadge.toggle() }
                                if store.s.prefs.noBadge { UNUserNotificationCenter.current().setBadgeCount(0) }
                                Feedback.tap()
                            }
                        }
                        SheetRow {
                            TileIcon(icon: "st_globe", bg: Pastel.at(2))
                            label("语言切换")
                            Menu {
                                Button("简体中文 ✓") {}
                                Button("繁體中文") { toaster.show("目前只有简体中文，其他语言正在准备") }
                                Button("English") { toaster.show("目前只有简体中文，其他语言正在准备") }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("简体中文").font(.system(size: 15)).foregroundStyle(PT.sub)
                                    Text("⌃\n⌄").font(.system(size: 8)).lineSpacing(-4).foregroundStyle(PT.faint)
                                }
                            }
                        }
                    }
                    group {
                        navRow(3, "st_image", "清空本地缓存图片", nil) { ask = .cache }
                        navRow(4, "st_reset", "重置清零习惯记录", nil) { ask = .reset }
                    }
                    group {
                        SheetRow {
                            TileIcon(icon: "st_user", bg: "", danger: true)
                            Text("注销账户").font(.system(size: 16, weight: .medium)).foregroundStyle(Color(hex: "#E5534B"))
                            Spacer()
                            Chevron()
                        }
                        .onTapGesture { ask = .quit }
                    }
                    group {
                        SheetRow {
                            TileIcon(icon: "pp_tabbar", bg: Pastel.at(3), size: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("切换到网页版界面").font(.system(size: 16, weight: .medium)).foregroundStyle(PT.body)
                                Text("测试用；在网页版里摇一摇可以切回来").font(.system(size: 12)).foregroundStyle(PT.faint)
                            }
                            Spacer()
                            Chevron()
                        }
                        .onTapGesture {
                            store.saveNow()
                            UserDefaults.standard.set("web", forKey: UIMode.key)
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(Theme.adaptive("#FFFFFF", "#1E1E1D").ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { p in
                Group {
                    if p == "home" { HomeContentPage() } else { LockPage() }
                }
                .environmentObject(store).environmentObject(toaster)
            }
        }
        .sheet(isPresented: $showTime) {
            TimeWheelSheet(h: P.daily.h, m: P.daily.m) { h, m in
                store.updatePrefs { $0.daily.h = h; $0.daily.m = m }
                Notifier.shared.rescheduleAll(store)
            }
            .presentationDetents([.height(360)])
            .presentationCornerRadius(30)
        }
        .alert(alertTitle, isPresented: Binding(get: { ask != nil }, set: { if !$0 { ask = nil } }), presenting: ask) { k in
            switch k {
            case .cache:
                Button("清空") { URLCache.shared.removeAllCachedResponses(); toaster.show("已清空缓存") }
            case .reset:
                Button("清零", role: .destructive) { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { ask = .reset2 } }
            case .reset2:
                Button("确认清零", role: .destructive) {
                    store.s.records = [:]
                    store.save()
                    dismiss()
                    toaster.show("打卡记录已清零")
                }
            case .quit:
                Button("知道了") {}
            }
            if k != .quit { Button("取消", role: .cancel) {} }
        } message: { k in
            switch k {
            case .cache: Text("只清理缓存，不会删除你的头像和卡片图片。")
            case .reset: Text("所有日期的打卡记录都会清空，卡片和笔记保留。这一步不能撤销。")
            case .reset2: Text("真的要清空全部打卡记录吗？")
            case .quit: Text("小满目前不需要注册账号，数据只保存在这台手机（和你自己的 iCloud 备份）里，没有云端账号可以注销。想删除全部数据，可以直接删除 App。")
            }
        }
    }

    private var alertTitle: String {
        switch ask {
        case .cache: return "清空本地缓存图片？"
        case .reset: return "重置清零习惯记录？"
        case .reset2: return "再确认一次"
        case .quit: return "注销账户"
        case nil: return ""
        }
    }

    private func toggleDaily() {
        store.updatePrefs { $0.daily.on.toggle() }
        Feedback.tap()
        let d = store.s.prefs.daily
        if d.on {
            Task { _ = await Notifier.shared.requestPermission(); Notifier.shared.rescheduleAll(store) }
            toaster.show(String(format: "每天 %02d:%02d 提醒你记录一下今天", d.h, d.m))
        } else {
            Notifier.shared.rescheduleAll(store)
            toaster.show("已关闭每日提醒")
        }
    }

    private func group<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        VStack(spacing: 8) { v() }.padding(.bottom, 12)
    }

    private func label(_ t: String) -> some View {
        HStack { Text(t).font(.system(size: 16, weight: .medium)).foregroundStyle(PT.body); Spacer(minLength: 0) }
    }

    private func navRow(_ i: Int, _ icon: String, _ t: String, _ v: String?, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SheetRow {
                TileIcon(icon: icon, bg: Pastel.at(i))
                label(t)
                if let v, !v.isEmpty { Text(v).font(.system(size: 14)).foregroundStyle(PT.faint) }
                Chevron()
            }
        }
        .buttonStyle(.plain)
    }

    private func seg(_ items: [(Int, String)], _ cur: Int, _ set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { it in
                let on = it.0 == cur
                Button { Feedback.tap(); set(it.0) } label: {
                    Text(it.1).font(.system(size: 14, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? PT.ink : PT.sub)
                        .padding(.horizontal, 9).frame(height: 30)
                        .background { if on { Capsule().fill(Theme.adaptive("#FFFFFF", "#636366")).shadow(color: .black.opacity(0.08), radius: 3, y: 2) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.adaptive("#EDEDF0", "#3A3936")))
    }
}

/// 选时间：时、分两个滚轮（和添加提醒里的一样）
struct TimeWheelSheet: View {
    @State var h: Int
    @State var m: Int
    var onDone: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("提醒时间").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body)
                HStack {
                    Button("取消") { dismiss() }.foregroundStyle(WT.gray)
                    Spacer()
                    Button("完成") { onDone(h, m); dismiss() }.fontWeight(.semibold).foregroundStyle(Color(hex: "#007AFF"))
                }
                .buttonStyle(.plain)
            }
            .frame(height: 44).padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 10)
            TimeWheel(h: $h, m: $m)
                .frame(height: 210)
                .padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.adaptive("#F7F4EE", "#262624")))
                .padding(.horizontal, 18)
            Spacer(minLength: 0)
        }
        .background(Theme.adaptive("#FFFFFF", "#1E1E1D").ignoresSafeArea())
    }
}

/// 首页显示内容
struct HomeContentPage: View {
    @EnvironmentObject var store: Store
    private let rows: [(String, String, String, String)] = [
        ("strip", "hm_strip", "默认展开日期栏", "打开 App 时显示一周日期"),
        ("quick", "hm_quick", "顶部快捷栏", "笔记、回忆、心情；在「个性化」里选择显示哪些"),
        ("jr", "hm_jr", "当天笔记卡片", "写过笔记的日子，在打卡上方显示"),
        ("prog", "hm_prog", "完成进度", "「日常打卡」旁的 已完成 / 总数"),
        ("cheer", "hm_cheer", "全部完成的鼓励语", "当天打卡都完成后显示一句话")
    ]
    var body: some View {
        NavPage("首页显示内容") {
            VStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    SheetRow {
                        TileIcon(icon: r.1, bg: Pastel.at(i))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.2).font(.system(size: 16, weight: .medium)).foregroundStyle(PT.body)
                            Text(r.3).font(.system(size: 12.5)).foregroundStyle(PT.faint).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        ProtoSwitch(on: value(r.0)) { toggle(r.0) }
                    }
                }
            }
            Text("关掉的功能只是在首页隐藏，数据不会删除，随时可以再打开。").font(.system(size: 12.5)).foregroundStyle(PT.sub)
                .padding(.horizontal, 6).padding(.top, 8)
        }
    }
    private func value(_ k: String) -> Bool {
        let h = store.s.prefs.home
        switch k { case "strip": return h.strip; case "quick": return h.quick; case "jr": return h.jr; case "prog": return h.prog; default: return h.cheer }
    }
    private func toggle(_ k: String) {
        Feedback.tap()
        store.updatePrefs { p in
            switch k { case "strip": p.home.strip.toggle(); case "quick": p.home.quick.toggle(); case "jr": p.home.jr.toggle(); case "prog": p.home.prog.toggle(); default: p.home.cheer.toggle() }
        }
    }
}

/// 密码锁定（用面容 ID / 手机密码解锁）
struct LockPage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    var body: some View {
        NavPage("密码锁定") {
            SheetRow {
                TileIcon(icon: "st_lock", bg: Pastel.at(0))
                VStack(alignment: .leading, spacing: 2) {
                    Text("APP 锁").font(.system(size: 16, weight: .medium)).foregroundStyle(PT.body)
                    Text("打开 APP 时需要用\(AppLock.biometryName)或手机密码解锁").font(.system(size: 12.5)).foregroundStyle(PT.faint)
                }
                Spacer(minLength: 0)
                ProtoSwitch(on: store.s.prefs.lockOn) {
                    let on = !store.s.prefs.lockOn
                    AppLock.verify(reason: on ? "开启 APP 锁" : "关闭 APP 锁") { ok in
                        guard ok else { return }
                        store.updatePrefs { $0.lockOn = on }
                        toaster.show(on ? "APP 锁已开启" : "APP 锁已关闭")
                    }
                }
            }
            Text(store.s.prefs.lockOn ? "APP 锁已开启。离开 APP 超过 30 秒后回来，也需要重新验证。" : "开启后，每次打开 APP 都要先用\(AppLock.biometryName)或手机密码解锁。")
                .font(.system(size: 12.5)).foregroundStyle(PT.sub).padding(.horizontal, 6).padding(.top, 8)
        }
    }
}

// MARK: - 个性化

struct PersonalSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss
    @State private var path: [String] = []

    private let menu: [(String, String, String)] = [
        ("theme", "pm_theme", "主题"), ("font", "pm_font", "APP 字体"), ("palette", "pm_palette", "配色板"), ("shape", "pm_shape", "打卡图标"),
        ("layout", "pm_layout", "排列密度"), ("quick", "pm_quick", "顶部快捷栏"), ("tabbar", "pm_tabbar", "底部导航样式"), ("sound", "pm_sound", "完成音效")
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 8) {
                    Text("按自己的喜好慢慢装扮").font(.system(size: 13)).foregroundStyle(PT.faint).frame(maxWidth: .infinity).padding(.bottom, 6)
                    ForEach(Array(menu.enumerated()), id: \.offset) { i, m in
                        Button { Feedback.tap(); path.append(m.0) } label: {
                            SheetRow {
                                TileIcon(icon: m.1, bg: Pastel.at(i))
                                Text(m.2).font(.system(size: 16, weight: .medium)).foregroundStyle(PT.body)
                                Spacer(minLength: 6)
                                Text(value(m.0)).font(.system(size: 14)).foregroundStyle(PT.faint).lineLimit(1)
                                Chevron()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { PageTop(title: "个性化", back: { dismiss() }) }
            .background(Theme.adaptive("#FFFFFF", "#1E1E1D").ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if let k = UserDefaults.standard.string(forKey: "shotPm"), path.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { path = [k] }
                }
            }
            .navigationDestination(for: String.self) { k in
                Group {
                    switch k {
                    case "theme": ThemePage()
                    case "font": FontPage()
                    case "palette": PalettePage()
                    case "shape": ShapePage()
                    case "layout": LayoutPage()
                    case "quick": QuickPage()
                    case "tabbar": TabBarPage()
                    default: SoundPage()
                    }
                }
                .environmentObject(store).environmentObject(toaster).environmentObject(router)
            }
        }
    }

    private func value(_ k: String) -> String {
        let P = store.s.prefs
        switch k {
        case "theme": return PageTheme.name(P)
        case "font": return P.appFont == "round" ? "圆体" : "系统字体"
        case "palette": return Palettes.all(P).first { $0.id == P.palette }?.name ?? "未使用"
        case "shape": return (ShapePage.shapes.first { $0.0 == CardShapes.normalize(P.shape) }?.1 ?? "圆形") + " · " + (ShapePage.lines.first { $0.0 == P.line }?.1 ?? "实线")
        case "layout": return P.layout == "compact" ? "满满" : P.layout == "dense" ? "适中" : "宽敞"
        case "quick":
            let n = QuickRow.ids.filter { P.quickOn($0) }.count
            return !P.home.quick ? "已隐藏" : n == QuickRow.ids.count ? "全部显示" : "显示 \(n) 项"
        case "tabbar": return (P.tabSize == "s" ? "小" : P.tabSize == "l" ? "大" : "中") + (P.tabLabel ? " · 显示文字" : "")
        default: return P.sound ? SFX.name(P.sndIn ?? SFX.inDefault) : "已关闭"
        }
    }
}

// MARK: 主题

struct ThemePage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @State private var pick: PhotosPickerItem?
    private var P: Prefs { store.s.prefs }

    var body: some View {
        NavPage("主题") {
            Text("手机处于深色模式时，主题背景暂不显示。").font(.system(size: 13)).foregroundStyle(PT.faint).padding(.horizontal, 4).padding(.bottom, 12)
            segMode
            PPHead(title: "日期栏配色", sub: "首页顶部选中日期的底色，文字固定为黑色。")
            datePreview
            HStack(spacing: 4) {
                ForEach(Theme.dateColors, id: \.id) { c in
                    let on = P.dateColor == c.id
                    Button { Feedback.tap(); store.updatePrefs { $0.dateColor = c.id } } label: {
                        VStack(spacing: 6) {
                            Group {
                                if c.id == "classic" {
                                    Circle().fill(LinearGradient(stops: [.init(color: Color(hex: "#1C1C1E"), location: 0.5), .init(color: Color(hex: "#F2F2F7"), location: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                } else { Circle().fill(Color(hex: c.hex)) }
                            }
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
                            .overlay { if on { Circle().stroke(PT.ink, lineWidth: 2).padding(-3) } }
                            Text(c.name).font(.system(size: 11.5, weight: on ? .semibold : .regular)).foregroundStyle(on ? PT.ink : PT.sub)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            PPHead(title: "自定义背景")
            PhotosPicker(selection: $pick, matching: .images) {
                HStack(spacing: 14) {
                    Group {
                        if let ui = ImageData.image(P.bgImg) { Image(uiImage: ui).resizable().scaledToFill() }
                        else { Image("pp_photo").renderingMode(.template).resizable().frame(width: 26, height: 26).foregroundStyle(PT.sub) }
                    }
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#1B1B1A")))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("从相册选择").font(.system(size: 16, weight: .semibold)).foregroundStyle(PT.ink)
                        Text(P.pageBg == "custom" ? "正在使用 · 再选一张可替换" : "选择图片后立即应用").font(.system(size: 13)).foregroundStyle(PT.faint)
                    }
                    Spacer()
                    if P.bgImg != nil {
                        Button("移除") {
                            store.updatePrefs { $0.bgImg = nil; if $0.pageBg == "custom" { $0.pageBg = "white" } }
                        }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "#E5534B"))
                    } else { Chevron() }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(PT.chip))
            }
            .buttonStyle(.plain)
            PPHead(title: "主题")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(PageTheme.all, id: \.id) { t in
                    let on = P.pageBg == t.id
                    Button { Feedback.tap(); store.updatePrefs { $0.pageBg = t.id } } label: {
                        VStack(spacing: 6) {
                            PageBG(id: t.id, preview: true)
                                .aspectRatio(0.86, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.black.opacity(0.04), lineWidth: 1))
                            Text(t.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(PT.ink)
                            HStack(spacing: 5) {
                                Circle().fill(Color(hex: t.base)).frame(width: 13, height: 13).overlay(Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
                                Circle().fill(Color(hex: t.dot)).frame(width: 13, height: 13).overlay(Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 10)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#1B1B1A")))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(on ? PT.ink : PT.chipLine, lineWidth: on ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: pick) { _, it in
            guard let it else { return }
            Task {
                if let d = try? await it.loadTransferable(type: Data.self), let ui = UIImage(data: d), let b = ImageData.base64(ui, maxSide: 1100, quality: 0.8) {
                    store.updatePrefs { $0.bgImg = "data:image/jpeg;base64," + b; $0.pageBg = "custom" }
                    toaster.show("已换成你的背景")
                }
                pick = nil
            }
        }
    }

    private var segMode: some View {
        HStack(spacing: 0) {
            ForEach([("system", "跟随系统"), ("light", "浅色"), ("dark", "深色")], id: \.0) { m in
                let on = P.mode == m.0
                Button { Feedback.tap(); store.updatePrefs { $0.mode = m.0 } } label: {
                    Text(m.1).font(.system(size: 14, weight: on ? .semibold : .medium)).foregroundStyle(on ? PT.ink : PT.sub)
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background { if on { Capsule().fill(Theme.adaptive("#FFFFFF", "#636366")).shadow(color: .black.opacity(0.08), radius: 4, y: 2) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.adaptive("#EDEDF0", "#2F2E2B")))
    }

    private var datePreview: some View {
        let c = Theme.dateColors.first { $0.id == P.dateColor } ?? Theme.dateColors[0]
        let classic = c.id == "classic"
        return HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                let on = i == 2
                VStack(spacing: 2) {
                    Text("周" + ["一", "二", "三", "四", "五"][i]).font(.system(size: 10)).foregroundStyle(on ? (classic ? Color.white.opacity(0.75) : Color(hex: "#1C1C1E").opacity(0.6)) : PT.faint)
                    Text("\(11 + i)").font(.system(size: 17, weight: .semibold)).foregroundStyle(on ? (classic ? Color.white : Color(hex: "#1C1C1E")) : PT.ink)
                }
                .frame(width: 46, height: 56)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Color(hex: c.hex) : PT.chip))
            }
        }
        .frame(maxWidth: .infinity).padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#1B1B1A")))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(PT.chipLine, lineWidth: 1))
        .padding(.bottom, 12)
    }
}

// MARK: APP 字体

struct FontPage: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let P = store.s.prefs
        NavPage("APP 字体") {
            VStack(alignment: .leading, spacing: 0) {
                Text("字体预览").font(.system(size: 12.5)).foregroundStyle(PT.faint)
                Text(P.appFont == "round" ? "圆体" : "系统字体").font(.system(size: 15)).foregroundStyle(PT.sub).padding(.top, 2)
                Text("今日打卡").font(.system(size: 30, weight: .heavy)).foregroundStyle(PT.ink).padding(.top, 14).padding(.bottom, 4)
                Text("Aa Bb Cc · 0123456789").font(.system(size: 19)).foregroundStyle(PT.faint)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in PvIcon(i: i, shape: store.s.prefs.shape, line: store.s.prefs.line, size: 48).frame(maxWidth: .infinity) }
                }
                .padding(.top, 16)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(PT.chip))
            .padding(.bottom, 14)
            VStack(alignment: .leading, spacing: 0) {
                Text("APP 字体").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.ink).padding(.horizontal, 2).padding(.top, 2).padding(.bottom, 2)
                ForEach([("sys", "系统字体", Font.Design.default), ("round", "圆体", Font.Design.rounded)], id: \.0) { f in
                    let on = P.appFont == f.0
                    Button { Feedback.tap(); store.updatePrefs { $0.appFont = f.0 } } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(f.1).font(.system(size: 16, weight: .bold, design: f.2)).foregroundStyle(PT.ink)
                            Text("字体预览 · 今天也要好好生活").font(.system(size: 15, design: f.2)).foregroundStyle(PT.sub)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#1B1B1A")))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? PT.ink : PT.chipLine, lineWidth: on ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(PT.chip))
            Text("选择后所有页面的文字一起改变。笔记里单独选的字体不受影响。").font(.system(size: 13)).foregroundStyle(PT.faint).lineSpacing(4)
                .padding(.horizontal, 4).padding(.top, 12)
        }
    }
}

// MARK: 配色板

enum Palettes {
    struct Pal: Identifiable, Hashable { let id: String; let name: String; let colors: [String]; var own = false }
    static let preset: [Pal] = [
        Pal(id: "own", name: "活力原色", colors: [], own: true),
        Pal(id: "oat", name: "麦穗暖阳", colors: ["#F3EADB", "#E6D5BC", "#D4BC9A", "#BFA383", "#9C8670"]),
        Pal(id: "mint", name: "冰川薄荷", colors: ["#D7F2E9", "#B5E6D6", "#8FD3C8", "#6CC0C7", "#A8D8EA"]),
        Pal(id: "sakura", name: "桃花微醺", colors: ["#FBE3E4", "#F6C9CE", "#EFB0B9", "#D9A3B5", "#B9A2C7"]),
        Pal(id: "forest", name: "松林雾语", colors: ["#DDE5D4", "#B8C9A8", "#8FA98A", "#6E8B74", "#4F6B5C"]),
        Pal(id: "morandi", name: "灰调静谧", colors: ["#A3B1B3", "#C8B8A6", "#B5A7B8", "#9DA89A", "#D4C4B0"]),
        Pal(id: "cream", name: "焦糖布丁", colors: ["#FCE7C8", "#F7D4B5", "#F2B5A0", "#E8C5D6", "#CBB8E0"]),
        Pal(id: "sky", name: "蓝调时光", colors: ["#E3F0FB", "#C2DDF3", "#9CC6EA", "#76ABDD", "#5A8FC9"]),
        Pal(id: "grass", name: "青苔小径", colors: ["#E9DFC2", "#BFCDAA", "#94BBA0", "#76ABA3", "#557C5E"]),
        Pal(id: "sea", name: "晴海远帆", colors: ["#3A7FA6", "#4DAEB5", "#F0E6A8", "#F2CFA8", "#E07A6C"]),
        Pal(id: "berry", name: "玫瑰拿铁", colors: ["#C9D8CC", "#F3D2C2", "#F0B8C4", "#DE9DA6", "#98818A"]),
        Pal(id: "sunset", name: "晚霞橘子", colors: ["#FFD6A5", "#FFB477", "#FF8F5A", "#F2694E", "#C94B4B"]),
        Pal(id: "film", name: "秋日胶片", colors: ["#E9C46A", "#F4A261", "#E76F51", "#2A9D8F", "#264653"]),
        Pal(id: "candy", name: "彩虹糖果", colors: ["#FF8FA3", "#FFC75F", "#9BDE7E", "#6EC6FF", "#B39DFF"]),
        Pal(id: "tropic", name: "热带果园", colors: ["#F94144", "#F8961E", "#F9C74F", "#90BE6D", "#43AA8B"]),
        Pal(id: "dusk", name: "港湾灯火", colors: ["#2F4858", "#33658A", "#86BBD8", "#F6AE2D", "#F26419"]),
        Pal(id: "gem", name: "星河宝石", colors: ["#5E60CE", "#6930C3", "#48BFE3", "#56CFE1", "#64DFDF"]),
        Pal(id: "plum", name: "葡萄酒红", colors: ["#7B2D5B", "#A23B72", "#D06C9F", "#F1A7C4", "#5C3D8F"]),
        Pal(id: "ocean", name: "深海潜行", colors: ["#0B3C5D", "#1D5C8C", "#328CC1", "#5FB3D9", "#D9B310"]),
        Pal(id: "neon", name: "夏夜霓虹", colors: ["#FF006E", "#FB5607", "#FFBE0B", "#3A86FF", "#8338EC"])
    ]
    static func mine(_ p: Prefs) -> [Pal] { (p.myPal ?? []).map { Pal(id: $0.id, name: $0.n, colors: $0.c) } }
    static func all(_ p: Prefs) -> [Pal] { preset + mine(p) }

    /// 「活力原色」：每张卡片自己的颜色
    static func ownColors(_ s: AppState) -> [String] {
        let own = s.cards.prefix(5).map { s.prefs.ownHex?[$0.id] ?? $0.hex }
        return Array((own + ["#3D8FE0", "#F5C542", "#F29D38", "#50A8B0", "#7DBF8A"]).prefix(5))
    }
    static func colors(_ p: Pal, _ s: AppState) -> [String] { p.own ? ownColors(s) : p.colors }

    /// 和网页版 applyPalette 一样：每个分组从第一个颜色开始轮流用
    static func apply(_ p: Pal, _ s: inout AppState) {
        if p.own {
            let m = s.prefs.ownHex ?? [:]
            for i in s.cards.indices { if let h = m[s.cards[i].id] { s.cards[i].hex = h } }
            s.prefs.palette = "own"
            return
        }
        if s.prefs.palette == nil || s.prefs.palette == "own" {
            var m: [String: String] = [:]
            for c in s.cards { m[c.id] = c.hex }
            s.prefs.ownHex = m
        }
        let known = Set(s.groups.map(\.id))
        let groups: [[Int]] = s.groups.map { g in s.cards.indices.filter { s.cards[$0].group == g.id } }
            + [s.cards.indices.filter { s.cards[$0].group == nil || !known.contains(s.cards[$0].group!) }]
        for list in groups {
            for (i, ci) in list.enumerated() { s.cards[ci].hex = p.colors[i % p.colors.count] }
        }
        s.prefs.palette = p.id
    }
}

struct PalettePage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @State private var pick = ""
    @State private var confirm = false
    @State private var palTab = "preset"
    @State private var editing = false
    @State private var delId: String?

    var body: some View {
        let P = store.s.prefs
        let all = Palettes.all(P)
        let mine = Palettes.mine(P)
        let cur = all.first { $0.id == pick } ?? all[0]
        let cols = Palettes.colors(cur, store.s)
        return NavPage("配色板", right: {
            Button { Feedback.tap(); editing = true } label: {
                Image(systemName: "plus").font(.system(size: 21, weight: .regular)).foregroundStyle(PT.ink).frame(width: 44, height: 44)
            }
            .accessibilityLabel("新建配色板")
        }) {
            HStack(alignment: .firstTextBaseline) {
                Text("配色预览").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.ink)
                Spacer()
                Text(cur.name).font(.system(size: 14)).foregroundStyle(PT.faint).padding(.trailing, 4)
            }
            .padding(.horizontal, 4).padding(.top, 22).padding(.bottom, 10)
            VStack(spacing: 0) {
                ForEach(Array([("读书", "1F4DA"), ("运动", "C-DUMBBELL"), ("记单词", "1F4DD")].enumerated()), id: \.offset) { i, it in
                    if i > 0 { Rectangle().fill(PT.chipLine).frame(height: 1) }
                    HStack(spacing: 14) {
                        Image(IconCatalog.assetName(it.1)).resizable().scaledToFit().frame(width: 30, height: 30)
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color(hex: cols[i % cols.count])))
                        Text(it.0).font(.system(size: 16, weight: .medium)).foregroundStyle(PT.ink)
                        Spacer()
                        Circle().strokeBorder(PT.chipLine, lineWidth: 1.5).frame(width: 24, height: 24)
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#1B1B1A")))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(PT.chipLine, lineWidth: 1))
            HStack(spacing: 0) {
                ForEach([("preset", "预设配色板"), ("mine", "我的配色板")], id: \.0) { t in
                    let on = palTab == t.0
                    Button { Feedback.tap(); palTab = t.0 } label: {
                        Text(t.1).font(.system(size: 16.5, weight: .semibold)).foregroundStyle(on ? PT.ink : PT.faint)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .overlay(alignment: .bottom) { Rectangle().fill(on ? PT.ink : PT.chipLine).frame(height: on ? 3 : 2) }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 18).padding(.bottom, 6)
            if palTab == "preset" {
                VStack(spacing: 10) {
                    ForEach(Palettes.preset) { p in palRow(p, P) }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            } else if mine.isEmpty {
                VStack(spacing: 6) {
                    Image("pm_palette").renderingMode(.template).resizable().scaledToFit().frame(width: 40, height: 40).foregroundStyle(PT.faint)
                    Text("还没有自定义配色板").font(.system(size: 16, weight: .bold)).foregroundStyle(PT.ink).padding(.top, 8)
                    Text("挑 3～6 个喜欢的颜色，做一组专属配色").font(.system(size: 13)).foregroundStyle(PT.faint)
                    Button { Feedback.tap(); editing = true } label: {
                        Text("＋ 新建").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(hex: "#007AFF"))
                            .padding(.horizontal, 26).frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 34).padding(.bottom, 100)
            } else {
                VStack(spacing: 10) {
                    ForEach(mine) { p in
                        palRow(p, P)
                            .simultaneousGesture(LongPressGesture(minimumDuration: 0.55).onEnded { _ in Feedback.warn(); delId = p.id })
                    }
                }
                .padding(.top, 8)
                Text("长按自己的配色板可以删除。").font(.system(size: 13)).foregroundStyle(PT.faint).padding(.horizontal, 4).padding(.top, 10)
                    .padding(.bottom, 100)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                Button { confirm = true } label: {
                    Text("换上这套颜色").font(.system(size: 16, weight: .semibold)).foregroundStyle(PT.ink)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.adaptive("#EDEDF0", "#2F2E2B")))
                }
                .buttonStyle(PressScale(scale: 0.98))
                Text("所有习惯会一起换成这套颜色").font(.system(size: 12.5)).foregroundStyle(PT.faint)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
            .background(Theme.adaptive("#FFFFFF", "#1E1E1D").ignoresSafeArea())
            .overlay(alignment: .top) { Rectangle().fill(PT.chipLine).frame(height: 1) }
        }
        .onAppear {
            if pick.isEmpty { pick = all.contains { $0.id == P.palette } ? P.palette! : all[0].id }
            if mine.contains(where: { $0.id == pick }) { palTab = "mine" }
            // 截图测试用：-shotPal mine / edit
            if let v = UserDefaults.standard.string(forKey: "shotPal") {
                palTab = "mine"
                if v == "edit" { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { editing = true } }
            }
        }
        .sheet(isPresented: $editing) {
            PaletteEditor { np in
                store.updatePrefs { $0.myPal = ($0.myPal ?? []) + [np] }
                palTab = "mine"; pick = np.id
                toaster.show("配色板已保存")
            }
            .environmentObject(toaster)
            .presentationCornerRadius(30).presentationDragIndicator(.visible)
        }
        .confirmationDialog("删除这个配色板？", isPresented: Binding(get: { delId != nil }, set: { if !$0 { delId = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let id = delId {
                    store.updatePrefs { p in
                        p.myPal = (p.myPal ?? []).filter { $0.id != id }
                        if p.palette == id { p.palette = nil }
                    }
                    if pick == id { pick = Palettes.preset[0].id }
                }
                delId = nil
            }
        } message: { Text("已经应用到习惯上的颜色不会改变。") }
        .alert(cur.own ? "还原成你自己的颜色？" : "应用「\(cur.name)」？", isPresented: $confirm) {
            Button("应用") {
                Palettes.apply(cur, &store.s)
                store.save()
                Feedback.success()
                toaster.show(cur.own ? "已还原你的颜色" : "配色已应用")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(cur.own ? "每张卡片会回到你单独设置过的颜色。" : "每个分类里的卡片会按顺序用上这 5 个颜色。之后移动卡片，颜色会跟着卡片走。")
        }
    }

    private func palRow(_ p: Palettes.Pal, _ P: Prefs) -> some View {
        let on = pick == p.id
        let cols = Palettes.colors(p, store.s)
        return Button { Feedback.tap(); withAnimation(.easeOut(duration: 0.15)) { pick = p.id } } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(p.name).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(PT.ink)
                    if P.palette == p.id {
                        Text("使用中").font(.system(size: 11.5)).foregroundStyle(PT.faint)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.adaptive("#FFFFFF", "#1B1B1A")))
                    }
                    Spacer()
                    if on {
                        Image("pp_check").renderingMode(.template).resizable().frame(width: 16, height: 16)
                            .foregroundStyle(Theme.adaptive("#FFFFFF", "#1B1B1A"))
                            .frame(width: 26, height: 26).background(Circle().fill(PT.ink))
                    }
                }
                HStack(spacing: 7) {
                    ForEach(Array(cols.enumerated()), id: \.offset) { _, c in
                        RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(hex: c)).frame(height: 34)
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.black.opacity(0.05), lineWidth: 1))
                    }
                }
                if p.own { Text("你自己给每张卡片设的颜色，选它可以还原").font(.system(size: 12)).foregroundStyle(PT.faint) }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PT.chip))
            .overlay { if on { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(PT.ink, lineWidth: 2) } }
        }
        .buttonStyle(.plain)
    }
}

/// 新建配色板（网页版 openPaletteEditor）
struct PaletteEditor: View {
    var onSave: (MyPalette) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var toaster: Toaster
    @State private var name = "我的配色板"
    @State private var sel: [String] = []
    @State private var custom = Color(hex: "#FF0000")

    static let preset = ["#86AFA4", "#F5C542", "#D9643A", "#4FA9B8", "#EF7068", "#99D4DC", "#F2CB9F", "#AAB59C",
                         "#EEE36E", "#F2BC5A", "#AC3F58", "#D3756B", "#E6DF94", "#74BED9", "#C3D9DE", "#B7DACD",
                         "#E1E4D1", "#D8DCC6", "#85DBBE", "#E5DCDB", "#E8D955", "#CCCDAA", "#6DC6B2", "#D9EAB8",
                         "#A1E8CB", "#9BC9DC", "#DAE3EC", "#F4D8D7", "#89BFAC", "#757070", "#A58D90", "#BE6B6B",
                         "#5786AD", "#E07A4F", "#80A39B", "#D2EAC6", "#5BA6AE", "#F1D16F", "#7BAE8B", "#D6BDB2"]

    private let box = Theme.adaptive("#FFFFFF", "#1E1E1D")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    circleBtn { Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(PT.ink) } action: { dismiss() }
                    Spacer()
                    Text("新建配色板").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body)
                    Spacer()
                    Button { save() } label: {
                        Text("保存").font(.system(size: 16, weight: .semibold)).foregroundStyle(sel.count >= 3 ? Color(hex: "#E0A800") : PT.faint)
                            .padding(.horizontal, 20).frame(height: 48)
                            .background(Capsule().fill(Theme.adaptive("#FFFFFF", "#2F2E2B")).shadow(color: .black.opacity(0.2), radius: 9, y: 6))
                    }
                    .buttonStyle(PressScale(scale: 0.95))
                    .disabled(sel.count < 3)
                }
                .padding(.bottom, 6)
                lbl("配色板名称")
                TextField("我的配色板", text: $name)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(PT.body)
                    .padding(.horizontal, 16).frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(box))
                    .onChange(of: name) { _, v in if v.count > 10 { name = String(v.prefix(10)) } }
                lbl("配色板预览")
                Group {
                    if sel.count >= 3 {
                        HStack(spacing: 0) { ForEach(sel, id: \.self) { c in Rectangle().fill(Color(hex: c)) } }
                    } else {
                        Text("请至少选择 3 个颜色").font(.system(size: 14.5)).foregroundStyle(PT.faint)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.adaptive("#E5E5EA", "#2F2E2B"))
                    }
                }
                .frame(height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                lbl("已选颜色", right: "\(sel.count)/6")
                Group {
                    if sel.isEmpty {
                        Text("点击下方颜色添加到配色板").font(.system(size: 14)).foregroundStyle(PT.faint).frame(maxWidth: .infinity)
                    } else {
                        HStack(spacing: 14) {
                            ForEach(Array(sel.enumerated()), id: \.element) { i, c in
                                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color(hex: c)).frame(width: 48, height: 48)
                                    .overlay(alignment: .topTrailing) {
                                        Button { Feedback.tap(); sel.remove(at: i) } label: {
                                            Text("×").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(hex: c)).brightness(-0.3)
                                                .frame(width: 22, height: 22).background(Circle().fill(.white).shadow(color: .black.opacity(0.18), radius: 2, y: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 8, y: -8)
                                        .accessibilityLabel("移除")
                                    }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(minHeight: 56).padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(box))
                lbl("自定义颜色")
                HStack(spacing: 22) {
                    ColorPicker("", selection: $custom, supportsOpacity: false).labelsHidden().frame(width: 32, height: 32)
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(custom).frame(width: 54, height: 54)
                    Button {
                        let h = custom.hexString.uppercased()
                        if sel.contains(h) { toaster.show("这个颜色已经选过了"); return }
                        add(h)
                    } label: {
                        HStack(spacing: 8) {
                            Text("＋").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 20, height: 20).background(Circle().fill(Color(hex: "#F5C542")))
                            Text("添加颜色").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "#D9A400"))
                        }
                        .padding(.horizontal, 16).frame(height: 40)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "#F5C542").opacity(0.18)))
                    }
                    .buttonStyle(PressScale())
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(box))
                lbl("预设颜色")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
                    ForEach(Self.preset, id: \.self) { c in
                        let on = sel.contains(c)
                        Button { Feedback.tap(); add(c) } label: {
                            RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(hex: c))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay { if on { RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(PT.ink, lineWidth: 2.5).padding(-2.5) } }
                                .overlay { if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: "#333333")) } }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(c)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(box))
            }
            .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.adaptive("#F2F2F7", "#161615").ignoresSafeArea())
    }

    private func add(_ c: String) {
        let c = c.uppercased()
        if let i = sel.firstIndex(of: c) { sel.remove(at: i); return }
        if sel.count >= 6 { toaster.show("最多选 6 个颜色"); return }
        sel.append(c)
    }

    private func save() {
        guard sel.count >= 3 else { return }
        let n = name.trimmingCharacters(in: .whitespaces)
        onSave(MyPalette(id: "my-" + UUID().uuidString.prefix(8).lowercased(), n: n.isEmpty ? "我的配色板" : n, c: sel))
        Feedback.success()
        dismiss()
    }

    private func lbl(_ t: String, right: String? = nil) -> some View {
        HStack {
            Text(t)
            Spacer()
            if let right { Text(right) }
        }
        .font(.system(size: 13.5)).foregroundStyle(PT.faint)
        .padding(.horizontal, 4).padding(.top, 18).padding(.bottom, 8)
    }

    private func circleBtn<L: View>(@ViewBuilder _ l: () -> L, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            l().frame(width: 48, height: 48)
                .background(Circle().fill(Theme.adaptive("#FFFFFF", "#2F2E2B")).shadow(color: .black.opacity(0.2), radius: 9, y: 6))
        }
        .buttonStyle(PressScale(scale: 0.92))
    }
}

// MARK: 打卡图标（形状 + 线条）

struct ShapePage: View {
    @EnvironmentObject var store: Store
    static let shapes: [(String, String)] = [("circle", "圆形"), ("square", "圆角矩形"), ("pebble", "圆润石"), ("olive", "橄榄"), ("flower", "花朵"),
                                             ("scallop", "花边"), ("onigiri", "饭团"), ("hexa", "六边形"), ("heart", "爱心")]
    static let lines: [(String, String)] = [("solid", "实线"), ("dash", "虚线"), ("dot", "点线"), ("none", "无边框")]
    @State private var replay: [String: Bool] = [:]

    var body: some View {
        let cs = CardShapes.normalize(store.s.prefs.shape), cl = store.s.prefs.line
        NavPage("打卡图标") {
            PPHead(title: "图标样式", sub: "打卡后的样子。点一下可以预览打卡时的扩散效果。", top: 8)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(Array(Self.shapes.enumerated()), id: \.offset) { i, s in
                    let on = cs == s.0
                    Button {
                        Feedback.tap()
                        store.updatePrefs { $0.shape = s.0 }
                        replay[s.0] = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { replay[s.0] = true }
                    } label: {
                        VStack(spacing: 8) {
                            PvIcon(i: i, shape: s.0, line: cl, hex: PvIcon.icHex[i], on: replay[s.0] ?? true, size: 60, showName: false)
                            Text(s.1).font(.system(size: 13, weight: .semibold)).foregroundStyle(PT.ink)
                        }
                        .frame(maxWidth: .infinity).padding(.horizontal, 6).padding(.top, 16).padding(.bottom, 12)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(PT.chip))
                        .overlay { if on { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(PT.ink, lineWidth: 2) } }
                    }
                    .buttonStyle(.plain)
                }
            }
            PPHead(title: "线条样式", sub: "图标边框的画法，左边是未打卡，右边是已打卡。")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(Self.lines, id: \.0) { l in
                    let on = cl == l.0
                    Button { Feedback.tap(); store.updatePrefs { $0.line = l.0 } } label: {
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                PvIcon(i: 0, shape: cs, line: l.0, hex: PvIcon.icHex[0], on: false, size: 48, showName: false)
                                PvIcon(i: 0, shape: cs, line: l.0, hex: PvIcon.icHex[0], on: true, size: 48, showName: false)
                            }
                            Text(l.1).font(.system(size: 13, weight: .semibold)).foregroundStyle(PT.ink)
                        }
                        .frame(maxWidth: .infinity).padding(.horizontal, 6).padding(.top, 14).padding(.bottom, 12)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(PT.chip))
                        .overlay { if on { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(PT.ink, lineWidth: 2) } }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: 排列密度

struct LayoutPage: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let lay = store.s.prefs.layout
        let shape = CardShapes.normalize(store.s.prefs.shape), line = store.s.prefs.line
        NavPage("排列密度") {
            PPHead(title: "选择排列密度", sub: "找到适合你的首页节奏", big: true)
            ForEach([("loose", "宽敞", 3, 6), ("dense", "适中", 4, 8), ("compact", "满满", 5, 10)], id: \.0) { k in
                let on = lay == k.0
                Button { Feedback.tap(); store.updatePrefs { $0.layout = k.0 } } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(k.1).font(.system(size: 18, weight: .bold)).foregroundStyle(PT.ink)
                            Text("\(k.2) 列").font(.system(size: 14)).foregroundStyle(PT.faint).padding(.top, 2)
                            Spacer()
                            ZStack {
                                if on {
                                    Circle().fill(PT.ink)
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.adaptive("#FFFFFF", "#000000"))
                                } else { Circle().strokeBorder(PT.chipLine, lineWidth: 2) }
                            }
                            .frame(width: 26, height: 26)
                        }
                        .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: k.2), spacing: 12) {
                            ForEach(0..<k.3, id: \.self) { i in PvIcon(i: i, shape: shape, line: line, size: 56) }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(PT.chip))
                    .overlay { if on { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(PT.ink, lineWidth: 2) } }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
            HStack(spacing: 8) {
                Image("pp_check").renderingMode(.template).resizable().frame(width: 18, height: 18).foregroundStyle(Color(hex: "#34C759"))
                Text("选好就用上了，不用另外保存").font(.system(size: 14)).foregroundStyle(PT.sub)
            }
            .padding(.horizontal, 4).padding(.top, 6)
        }
    }
}

// MARK: 顶部快捷栏

struct QuickPage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    private let items: [(String, String, String, String)] = [
        ("jr", "q_note", "笔记", "写一篇当天的笔记"), ("time", "q_memory", "回忆", "按日历翻看过去的打卡和笔记"),
        ("mood", "q_mood", "心情", "记下今天的心情")
    ]
    var body: some View {
        let P = store.s.prefs
        NavPage("顶部快捷栏") {
            card {
                cardHead("pp_quickh", "预览效果")
                Group {
                    if P.home.quick {
                        QuickRow(day: DK.today).allowsHitTesting(false).padding(.bottom, 10)
                    } else {
                        Text("顶部快捷栏已隐藏").font(.system(size: 13)).foregroundStyle(PT.faint).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 4).padding(.top, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.adaptive("#F6F4EF", "#1E1E1C")))
            }
            card {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("显示顶部快捷栏").font(.system(size: 16, weight: .semibold)).foregroundStyle(PT.ink)
                        Text("在打卡主页日期栏下方显示").font(.system(size: 12.5)).foregroundStyle(PT.faint)
                    }
                    Spacer()
                    ProtoSwitch(on: P.home.quick) { Feedback.tap(); store.updatePrefs { $0.home.quick.toggle() } }
                }
                .padding(.horizontal, 14).frame(minHeight: 62)
            }
            card {
                cardHead("pp_widget", "显示哪些快捷入口")
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                        if i > 0 { Rectangle().fill(PT.chipLine).frame(height: 1).padding(.leading, 60) }
                        HStack(spacing: 10) {
                            Image(it.1).resizable().scaledToFit().frame(width: 22, height: 22)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.adaptive("#F4F1EA", "#2F2D2A")))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(it.2).font(.system(size: 16, weight: .semibold)).foregroundStyle(PT.ink)
                                Text(it.3).font(.system(size: 12.5)).foregroundStyle(PT.faint)
                            }
                            Spacer()
                            ProtoSwitch(on: P.quickOn(it.0)) { toggle(it.0) }
                        }
                        .padding(.horizontal, 14).frame(minHeight: 62)
                    }
                }
                .opacity(P.home.quick ? 1 : 0.45)
            }
            tip("隐藏后只是不在打卡主页显示，笔记、回忆和心情的内容都不会删除。至少保留一个入口；都不想要时，直接关闭顶部快捷栏。")
        }
    }

    private func toggle(_ k: String) {
        let P = store.s.prefs
        guard P.home.quick else { toaster.show("先打开「显示顶部快捷栏」"); return }
        if P.quickOn(k) && QuickRow.ids.filter({ P.quickOn($0) }).count <= 1 { toaster.show("至少保留一个入口"); return }
        Feedback.tap()
        store.updatePrefs { $0.quickItems[k] = !P.quickOn(k) }
    }
}

/// 网页版 .tb-card / .tb-h / .tb-tip
func card<V: View>(@ViewBuilder _ v: () -> V) -> some View {
    VStack(alignment: .leading, spacing: 0) { v() }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(PT.chip))
        .padding(.bottom, 14)
}

func cardHead(_ icon: String, _ t: String) -> some View {
    HStack(spacing: 10) {
        Image(icon).renderingMode(.template).resizable().frame(width: 20, height: 20).foregroundStyle(PT.faint)
        Text(t).font(.system(size: 16, weight: .bold)).foregroundStyle(PT.ink)
    }
    .padding(.horizontal, 4).padding(.top, 2).padding(.bottom, 0)
}

func tip(_ t: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Image("pp_bulb").renderingMode(.template).resizable().frame(width: 18, height: 18).foregroundStyle(Color(hex: "#F5B92E")).padding(.top, 1)
        Text(t).font(.system(size: 13)).foregroundStyle(PT.sub).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 14).padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(PT.chip))
}

// MARK: 底部导航样式

struct TabBarPage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    private let pickable = ["bars", "ai", "memory", "journal", "none"]

    var body: some View {
        let P = store.s.prefs
        let keys = AppTab.keys(P)
        let sz = P.tabSize
        NavPage("底部导航样式") {
            card {
                cardHead("pp_tabbar", "预览效果").padding(.bottom, 12)
                let iconS: CGFloat = sz == "s" ? 27 : sz == "l" ? 42 : 36
                let h: CGFloat = sz == "s" ? 42 : sz == "l" ? 62 : 52
                HStack(spacing: 0) {
                    ForEach(keys) { k in
                        VStack(spacing: 1) {
                            Image("tb_\(k.rawValue)_on").resizable().scaledToFit().frame(width: iconS, height: iconS)
                            if P.tabLabel { Text(k.title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.adaptive("#5B4F45", "#E8E0D2")) }
                        }
                        .frame(maxWidth: .infinity).frame(height: h + (P.tabLabel ? 12 : 0))
                    }
                }
                .padding(7)
                .background(Capsule().fill(Theme.adaptive("#FFFFFF", "#22211E")))
                .overlay(Capsule().strokeBorder(Theme.adaptive("#EAE3D6", "#3A3732"), lineWidth: 1.5))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, sz == "s" ? 22 : sz == "l" ? 0 : 8)
            }
            card {
                cardHead("pp_lay", "底部栏大小").padding(.bottom, 12)
                HStack(spacing: 0) {
                    ForEach([("s", "小"), ("m", "中"), ("l", "大")], id: \.0) { s in
                        let on = sz == s.0
                        Button { Feedback.tap(); store.updatePrefs { $0.tabSize = s.0 } } label: {
                            Text(s.1).font(.system(size: 14, weight: on ? .semibold : .medium)).foregroundStyle(on ? PT.ink : PT.sub)
                                .frame(maxWidth: .infinity).frame(height: 34)
                                .background { if on { Capsule().fill(Theme.adaptive("#FFFFFF", "#636366")).shadow(color: .black.opacity(0.08), radius: 4, y: 2) } }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Capsule().fill(Theme.adaptive("#EDEDF0", "#2F2E2B")))
            }
            card {
                cardHead("pp_widget", "位置设置")
                VStack(spacing: 0) {
                    slotRow(1, "today", fixed: true, sub: "首页入口", i: nil)
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle().fill(PT.chipLine).frame(height: 1).padding(.leading, 60)
                        slotRow(i + 2, P.tabSlots[i], fixed: false, sub: nil, i: i)
                    }
                    Rectangle().fill(PT.chipLine).frame(height: 1).padding(.leading, 60)
                    slotRow(5, "me", fixed: true, sub: "个人中心", i: nil)
                }
            }
            card {
                cardHead("pp_image", "显示设置")
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("显示文字标签").font(.system(size: 16, weight: .semibold)).foregroundStyle(PT.ink)
                        Text("在图标下方显示功能名称，图标大小不变").font(.system(size: 12.5)).foregroundStyle(PT.faint)
                    }
                    Spacer()
                    ProtoSwitch(on: P.tabLabel) { Feedback.tap(); store.updatePrefs { $0.tabLabel.toggle() } }
                }
                .padding(.horizontal, 14).frame(minHeight: 62)
            }
            tip("位置 1 和位置 5 已固定。设为「不显示」的位置会从底部栏去掉；不在底部栏的功能，可以在「我的」页面里找到。")
        }
    }

    private func name(_ k: String) -> String { k == "none" ? "不显示" : AppTab(rawValue: k)?.title ?? k }

    private func slotRow(_ n: Int, _ k: String, fixed: Bool, sub: String?, i: Int?) -> some View {
        HStack(spacing: 12) {
            Text("\(n)").font(.system(size: 15, weight: .bold))
                .foregroundStyle(fixed ? PT.faint : Theme.adaptive("#FFFFFF", "#1B1B1A"))
                .frame(width: 34, height: 34)
                .background(Circle().fill(fixed ? Theme.adaptive("#FFFFFF", "#1B1B1A") : Theme.adaptive("#1C1C1E", "#F2F2F7")))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("位置 \(n)").font(.system(size: 16, weight: .semibold)).foregroundStyle(PT.ink)
                    if fixed {
                        Text("固定").font(.system(size: 11, weight: .medium)).foregroundStyle(PT.faint)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.adaptive("#FFFFFF", "#1B1B1A")))
                    }
                }
                if let sub { Text(sub).font(.system(size: 12.5)).foregroundStyle(PT.faint) }
            }
            Spacer()
            if fixed {
                pickLabel(k, fixed: true)
            } else if let i {
                Menu {
                    ForEach(pickable, id: \.self) { o in
                        Button { setSlot(i, o) } label: {
                            if o == k { Label(name(o), systemImage: "checkmark") } else { Text(name(o)) }
                        }
                    }
                } label: { pickLabel(k, fixed: false) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(minHeight: 62)
    }

    private func pickLabel(_ k: String, fixed: Bool) -> some View {
        HStack(spacing: 7) {
            if k != "none" { Image("tb_\(k)_off").resizable().scaledToFit().frame(width: 20, height: 20) }
            Text(name(k)).font(.system(size: 15, weight: k == "none" ? .medium : .semibold)).foregroundStyle(fixed || k == "none" ? PT.faint : PT.ink)
            if !fixed { Text("⌃\n⌄").font(.system(size: 8)).lineSpacing(-4).foregroundStyle(PT.faint).padding(.leading, 2) }
        }
        .padding(.horizontal, 12).frame(height: 38)
        .background { if fixed { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#1B1B1A")) } }
        .overlay { if !fixed { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(PT.chipLine, lineWidth: 1.2) } }
    }

    /// 选中的功能如果已经在别的位置，两个位置互换
    private func setSlot(_ i: Int, _ v: String) {
        var sl = store.s.prefs.tabSlots
        if v != "none", let j = sl.firstIndex(of: v), j != i { sl[j] = sl[i] }
        sl[i] = v
        Feedback.tap()
        store.updatePrefs { $0.tabs = sl }
    }
}

// MARK: 完成音效

struct SoundPage: View {
    @EnvironmentObject var store: Store
    @State private var kind = "in"
    var body: some View {
        let P = store.s.prefs
        let cur = kind == "in" ? (P.sndIn ?? SFX.inDefault) : (P.sndOut ?? SFX.outDefault)
        let def = kind == "in" ? SFX.inDefault : SFX.outDefault
        NavPage("完成音效") {
            PPHead(title: "完成那一下，配个响声", sub: "轻点就能试听，选中即用", big: true)
            SheetRow {
                TileIcon(icon: "pp_sound", bg: Pastel.at(0), size: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("打卡音效").font(.system(size: 16, weight: .medium)).foregroundStyle(PT.body)
                    Text("关闭后打卡和取消打卡都不发声").font(.system(size: 12.5)).foregroundStyle(PT.faint)
                }
                Spacer(minLength: 0)
                ProtoSwitch(on: P.sound) {
                    store.updatePrefs { $0.sound.toggle() }
                    Feedback.soundOn = store.s.prefs.sound
                    if store.s.prefs.sound { SFX.play(cur) }
                }
            }
            HStack(spacing: 0) {
                ForEach([("in", "完成时"), ("out", "撤销时")], id: \.0) { s in
                    let on = kind == s.0
                    Button { Feedback.tap(); kind = s.0 } label: {
                        Text(s.1).font(.system(size: 14, weight: on ? .semibold : .medium)).foregroundStyle(on ? PT.ink : PT.sub)
                            .frame(maxWidth: .infinity).frame(height: 34)
                            .background { if on { Capsule().fill(Theme.adaptive("#FFFFFF", "#636366")).shadow(color: .black.opacity(0.08), radius: 4, y: 2) } }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(Theme.adaptive("#EDEDF0", "#2F2E2B")))
            .padding(.top, 14).padding(.bottom, 10)
            VStack(spacing: 8) {
                ForEach(Array(SFX.list.enumerated()), id: \.offset) { i, it in
                    let on = it.n == cur
                    Button {
                        SFX.play(it.n)
                        store.updatePrefs { if kind == "in" { $0.sndIn = it.n } else { $0.sndOut = it.n } }
                    } label: {
                        HStack(spacing: 12) {
                            TileIcon(icon: "pp_snd", bg: Pastel.at(i), size: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(it.name).font(.system(size: 16, weight: .medium)).foregroundStyle(PT.body)
                                    if it.n == def {
                                        Text("默认").font(.system(size: 10.5)).foregroundStyle(PT.sub)
                                            .padding(.horizontal, 6).padding(.vertical, 1)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.14)))
                                    }
                                }
                                Text(it.desc).font(.system(size: 12.5)).foregroundStyle(PT.faint).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Circle().strokeBorder(on ? Color(hex: "#007AFF") : PT.faint, lineWidth: on ? 7 : 1.6).frame(width: 22, height: 22)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .frame(minHeight: 58)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? Theme.adaptive("#F7F7F7", "#2A2A28") : WT.card))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(WT.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .opacity(P.sound ? 1 : 0.45)
            HStack(spacing: 8) {
                Image("pp_mute").renderingMode(.template).resizable().frame(width: 22, height: 22).foregroundStyle(PT.ink)
                Text("没有声音？").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.ink)
            }
            .padding(.horizontal, 4).padding(.top, 22).padding(.bottom, 6)
            Text("先看看手机侧边的静音键有没有打开，再把媒体音量调大一些；「设置」里的「按键声音」也要开着。")
                .font(.system(size: 13)).foregroundStyle(PT.faint).lineSpacing(4).padding(.horizontal, 4)
        }
    }
}
