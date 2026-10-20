import SwiftUI
import PhotosUI

// MARK: - 我的（按网页版复刻）

enum MePage: String, Identifiable {
    case cards, memory, backup, events, personal, widget, export, feedback, modules, stats, guide, privacy, terms, credits, settings
    var id: String { rawValue }
}

struct MeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var router: Router
    @EnvironmentObject var purchases: Purchases
    @Environment(\.colorScheme) private var scheme
    @State private var page: MePage?
    @State private var showAccount = false
    @State private var showJr = false

    private var P: Prefs { store.s.prefs }
    private var dark: Bool { scheme == .dark }

    /// 模块（和网页版 MODULES 一样）
    static let modules: [(id: String, icon: String, name: String)] = [
        ("cards", "mt_cards", "习惯管理"), ("memory", "mt_memory", "回忆"), ("backup", "mt_backup", "备份"), ("events", "mt_events", "新事件"),
        ("personal", "mt_personal", "个性化"), ("widget", "mt_widget", "小组件"), ("export", "mt_export", "导出数据"), ("feedback", "mt_feedback", "意见反馈")
    ]
    static func modList(_ p: Prefs) -> [ModulePref] {
        let ids = modules.map(\.id)
        var out = (p.modules ?? []).filter { ids.contains($0.id) }
        for m in modules where !out.contains(where: { $0.id == m.id }) { out.append(ModulePref(id: m.id, on: true)) }
        return out
    }

    private var tiles: [(id: String, icon: String, name: String)] {
        let keys = AppTab.keys(P)
        var t: [(String, String, String)] = keys.contains(.ai) ? [] : [("stats", "mt_stat", "统计")]
        for m in Self.modList(P) where m.on && !(m.id == "memory" && keys.contains(.memory)) {
            if let meta = Self.modules.first(where: { $0.id == m.id }) { t.append(meta) }
        }
        t.append(("modules", "mt_modules", "模块设置"))
        return t
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                top
                profileCard
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 18) {
                    ForEach(tiles, id: \.id) { t in
                        Button { Feedback.tap(); open(t.id) } label: {
                            VStack(spacing: 8) {
                                Image(t.icon).resizable().scaledToFit().frame(width: 26, height: 26)
                                    .frame(width: 46, height: 46)
                                    .background(Circle().fill(dark ? Color.white.opacity(0.08) : Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.1)))
                                Text(t.name).font(.system(size: 14, weight: .medium)).foregroundStyle(PT.body)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressScale())
                    }
                }
                .padding(.top, 22)
                Button { Feedback.tap(); toaster.show("已经是最新版本") } label: {
                    HStack(spacing: 6) {
                        Text("当前版本 V\(DeviceInfo.appVersion)（测试版 \(DeviceInfo.build)）").foregroundStyle(PT.faint)
                        Text("检查更新").fontWeight(.semibold).foregroundStyle(PT.sub).underline(color: PT.chipLine)
                    }
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .padding(.top, 22)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background(PageBG().ignoresSafeArea())
        .onAppear {
            // 截图测试用：-shotMe settings / personal / backup …
            if let m = UserDefaults.standard.string(forKey: "shotMe") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if m == "account" { showAccount = true } else if m == "vip" { router.vip = true } else if let v = MePage(rawValue: m) { page = v }
                }
            }
        }
        .sheet(item: $page) { p in
            sheetContent(p)
                .environmentObject(store).environmentObject(toaster).environmentObject(router).environmentObject(purchases)
                .presentationCornerRadius(30)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAccount) {
            AccountSheet(onPlan: {
                showAccount = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.vip = true }
            }, onBackup: {
                showAccount = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { page = .backup }
            })
            .environmentObject(store).environmentObject(toaster).environmentObject(purchases)
            .presentationCornerRadius(30).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showJr) {
            JournalRangeSheet(from: "0000-00-00", to: "9999-99-99", label: "", title: "笔记")
                .environmentObject(store).environmentObject(toaster)
                .presentationCornerRadius(30).presentationDragIndicator(.visible)
        }
    }

    private func open(_ id: String) {
        switch id {
        case "cards": page = .cards
        case "memory": page = .memory
        case "backup": page = .backup
        case "events": page = .events
        case "personal": page = .personal
        case "widget": page = .widget
        case "export": page = .export
        case "feedback": page = .feedback
        case "stats": page = .stats
        default: page = .modules
        }
    }

    @ViewBuilder private func sheetContent(_ p: MePage) -> some View {
        switch p {
        case .cards: HabitsView()
        case .memory: NavigationStack { MemoryView() }
        case .backup: NavigationStack { BackupPage() }
        case .events: NavigationStack { EventsPage() }
        case .personal: PersonalSheet()
        case .widget: NavigationStack { WidgetPage() }
        case .export: NavigationStack { ExportPage() }
        case .feedback: FeedbackSheet()
        case .modules: NavigationStack { ModulesPage() }
        case .stats: StatsView()
        case .guide: NavigationStack { GuideView() }
        case .privacy: NavigationStack { DocView(title: "隐私政策", text: LegalText.privacy) }
        case .terms: NavigationStack { DocView(title: "用户协议", text: LegalText.terms) }
        case .credits: NavigationStack { DocView(title: "致谢", text: LegalText.credits) }
        case .settings: SettingsSheet()
        }
    }

    // MARK: 顶部：反馈 · 我的 · 设置

    private var top: some View {
        ZStack {
            Text("我的").font(.system(size: 18, weight: .bold)).foregroundStyle(PT.body)
            HStack {
                Button { Feedback.tap(); page = .feedback } label: {
                    Image("mt_help").resizable().frame(width: 24, height: 24).frame(width: 40, height: 40).contentShape(Rectangle())
                }
                .accessibilityLabel("意见反馈")
                Spacer()
                Button { Feedback.tap(); page = .settings } label: {
                    Image("mt_gear").resizable().frame(width: 24, height: 24).frame(width: 40, height: 40).contentShape(Rectangle())
                }
                .accessibilityLabel("设置")
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6).padding(.bottom, 12)
    }

    // MARK: 头像、名字、会员、四个数字

    private var stats: (habits: Int, checks: Int, days: Int) {
        let s = store.s, T = DK.today, N = s.noteIds
        var checks = 0, days = 0
        for (k, d) in s.records where k <= T {
            let n = d.filter { $0.value.checked && !N.contains($0.key) }.count
            checks += n
            if n > 0 { days += 1 }
        }
        return (s.checkCards.count, checks, days)
    }

    private var profileCard: some View {
        let st = stats
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { showAccount = true } label: {
                    AvatarView(prefs: P, size: 64, ring: false)
                        .overlay(Circle().stroke(dark ? Color(hex: "#1B1B1A") : Color.white, lineWidth: 3).padding(-1.5))
                        .compositingGroup()
                        .shadow(color: .black.opacity(dark ? 0 : 0.18), radius: 7, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("账号与头像")
                VStack(alignment: .leading, spacing: 2) {
                    Text(P.nick.isEmpty ? "我" : P.nick).font(.system(size: 22, weight: .semibold)).foregroundStyle(PT.body).lineLimit(1)
                    Text(!P.bio.isEmpty ? P.bio : st.days > 0 ? "已经记录了 \(st.days) 天" : "从今天开始记录吧")
                        .font(.system(size: 12.5)).foregroundStyle(PT.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                Button { Feedback.tap(); router.vip = true } label: {
                    HStack(spacing: 5) {
                        Image("mt_crown").renderingMode(.template).resizable().frame(width: 16, height: 16)
                        Text(purchases.isVIP ? (purchases.plan == "life" ? "永久会员" : "年会员") : "开通会员").font(.system(size: 14.5, weight: .bold))
                    }
                    .foregroundStyle(Color(hex: "#1C1C1E"))
                    .padding(.horizontal, 16).frame(height: 38)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(
                        purchases.isVIP ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#FFD84D"), Color(hex: "#F5A623")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : AnyShapeStyle(Color(hex: "#FFCC00"))))
                }
                .buttonStyle(PressScale(scale: 0.96))
            }
            .padding(.horizontal, 4).padding(.top, 4).padding(.bottom, 14)
            HStack(spacing: 0) {
                num(st.habits, "习惯数")
                sep
                num(st.checks, "打卡次数")
                sep
                Button { Feedback.tap(); showJr = true } label: { num(store.s.journalTotal, "笔记") }.buttonStyle(.plain)
                sep
                num(st.days, "记录天数")
            }
            .padding(.vertical, 16).padding(.horizontal, 4)
            .background {
                let r = RoundedRectangle(cornerRadius: 20, style: .continuous)
                if dark { r.strokeBorder(Color.white.opacity(0.12), lineWidth: 1) }
                else {
                    r.fill(Color.white).shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
                        .overlay(r.strokeBorder(Color.black.opacity(0.05), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, dark ? 12 : 4).padding(.top, dark ? 14 : 4).padding(.bottom, dark ? 4 : 2)
        .background { if dark { RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: "#262624")) } }
        .padding(.horizontal, -4)
    }

    private var sep: some View { Rectangle().fill(PT.hairline).frame(width: 1, height: 40) }

    private func num(_ v: Int, _ l: String) -> some View {
        VStack(spacing: 3) {
            Text("\(v)").font(.system(size: 21, weight: .semibold)).monospacedDigit().foregroundStyle(PT.body)
            Text(l).font(.system(size: 12)).foregroundStyle(PT.muted)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - 模块设置（开关、拖动排序）

struct ModulesPage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let list = MeView.modList(store.s.prefs)
        List {
            Section {
                ForEach(list, id: \.id) { m in
                    let meta = MeView.modules.first { $0.id == m.id }!
                    HStack(spacing: 12) {
                        Image(meta.icon).resizable().frame(width: 22, height: 22)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(PT.chip))
                        Text(meta.name).font(.system(size: 16, weight: .medium)).foregroundStyle(PT.body)
                        Spacer()
                        ProtoSwitch(on: m.on) {
                            var L = MeView.modList(store.s.prefs)
                            if let i = L.firstIndex(where: { $0.id == m.id }) { L[i].on.toggle() }
                            Feedback.tap()
                            store.updatePrefs { $0.modules = L }
                        }
                    }
                    .padding(.vertical, 4)
                    .opacity(m.on ? 1 : 0.6)
                }
                .onMove { from, to in
                    var L = MeView.modList(store.s.prefs)
                    L.move(fromOffsets: from, toOffset: to)
                    store.updatePrefs { $0.modules = L }
                    toaster.show("顺序已保存")
                }
                HStack(spacing: 12) {
                    Image("mt_modules").resizable().frame(width: 22, height: 22)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(PT.chip))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("模块设置").font(.system(size: 16, weight: .medium)).foregroundStyle(PT.body)
                        Text("始终显示，方便找回隐藏的模块").font(.system(size: 12.5)).foregroundStyle(PT.faint)
                    }
                }
                .padding(.vertical, 4)
                .moveDisabled(true)
            } header: {
                Text("按住右侧 ≡ 拖动排序，关闭开关的模块不会出现在“我的”页面。").font(.system(size: 12.5)).foregroundStyle(PT.sub).textCase(nil)
            }
            Section {
                Button("恢复默认顺序") {
                    store.updatePrefs { $0.modules = nil }
                    toaster.show("已恢复默认顺序")
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color(hex: "#007AFF"))
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Theme.adaptive("#FFFFFF", "#1E1E1D").ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) { PageTop(title: "模块设置", back: { dismiss() }) }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - 头像

struct AvatarView: View {
    let prefs: Prefs
    var size: CGFloat = 64
    var ring = true

    var body: some View {
        Group {
            if let img = ImageData.image(prefs.avatar) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                DefaultAvatar(gender: prefs.gender)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { if ring { Circle().stroke(Theme.sep, lineWidth: 1) } }
    }
}

/// 没设置头像时的默认头像（自己画的小芽，不用来源不明的图片）
struct DefaultAvatar: View {
    var gender: String
    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            ZStack {
                LinearGradient(colors: gender == "m" ? [Color(hex: "#CFE3F7"), Color(hex: "#A8CBEF")] : [Color(hex: "#FBE0E6"), Color(hex: "#F5BFCC")],
                               startPoint: .top, endPoint: .bottom)
                Image(systemName: "leaf.fill")
                    .resizable().scaledToFit()
                    .frame(width: s * 0.42)
                    .foregroundStyle(gender == "m" ? Color(hex: "#3D7DBF") : Color(hex: "#5CB874"))
                    .rotationEffect(.degrees(-20))
                    .offset(y: -s * 0.02)
            }
        }
    }
}

// MARK: - 账号（网页版 openAccount：取消 · 账号 · 保存）

struct AccountSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var purchases: Purchases
    @Environment(\.dismiss) private var dismiss
    var onPlan: () -> Void = {}
    var onBackup: () -> Void = {}

    @State private var nick = ""
    @State private var bio = ""
    @State private var gender = "f"
    @State private var avatar: String?
    @State private var pick: PhotosPickerItem?
    @State private var loaded = false

    private let listBg = Theme.adaptive("#FFFFFF", "#2C2A26")
    private let listLine = Theme.adaptive("#EEE7DA", "#3A3732")
    private let secInk = Theme.adaptive("#B0A491", "#B8AE9C")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Text("账号").font(.system(size: 18, weight: .bold)).foregroundStyle(PT.body)
                    HStack {
                        Button("取消") { dismiss() }.font(.system(size: 16)).foregroundStyle(Theme.adaptive("#6B6B70", "#A1A1A6"))
                        Spacer()
                        Button { save() } label: {
                            Text("保存").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.adaptive("#3E3532", "#2A2724"))
                                .padding(.horizontal, 14).frame(height: 34)
                                .background(Capsule().fill(Theme.adaptive("#FFE7A3", "#F5C542")))
                        }
                        .buttonStyle(PressScale())
                    }
                }
                .frame(height: 44).padding(.bottom, 14)

                HStack {
                    PhotosPicker(selection: $pick, matching: .images) {
                        AvatarView(prefs: previewPrefs, size: 84, ring: false)
                    }
                    .accessibilityLabel("更换头像")
                    Spacer(minLength: 12)
                    TextField("昵称", text: $nick)
                        .font(.system(size: 17, weight: .semibold)).multilineTextAlignment(.center).foregroundStyle(PT.body)
                        .fixedSize()
                        .frame(minWidth: 16).frame(height: 40).padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#1E1E1D")))
                        .onChange(of: nick) { _, v in if v.count > 12 { nick = String(v.prefix(12)) } }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.adaptive("#F5F5F7", "#2C2C2E")))
                .padding(.bottom, 12)

                HStack(spacing: 8) {
                    if bio.isEmpty {
                        Text("+").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                            .frame(width: 18, height: 18).background(Circle().fill(Color(hex: "#BDBDC2")))
                    }
                    TextField("", text: $bio, prompt: Text("添加个人介绍").foregroundStyle(Color(hex: "#B5B5BA")))
                        .font(.system(size: 16)).foregroundStyle(PT.body)
                        .onChange(of: bio) { _, v in if v.count > 40 { bio = String(v.prefix(40)) } }
                }
                .padding(.horizontal, 14).frame(height: 46)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.adaptive("#D9D9DE", "#4A4A4E"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                .padding(.bottom, 18)

                list {
                    row("性别") {
                        HStack(spacing: 4) {
                            ForEach([("f", "女"), ("m", "男")], id: \.0) { g in
                                let on = gender == g.0
                                Button { Feedback.tap(); gender = g.0 } label: {
                                    Text(g.1).font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(on ? Theme.adaptive("#FFFFFF", "#1B1B1A") : Theme.adaptive("#9A9AA3", "#8E8E93"))
                                        .frame(minWidth: 52).frame(height: 32)
                                        .background { if on { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.adaptive("#1C1C1E", "#F2F2F7")) } }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(3)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#1E1E1D")))
                    }
                    if avatar != nil {
                        Button { avatar = nil } label: { row("恢复默认头像") { Text("›").foregroundStyle(PT.muted) } }.buttonStyle(.plain)
                    }
                }
                Text(avatar == nil ? "还没有设置头像，默认头像会跟着性别变化。" : "你设置了自己的头像，切换性别不会改变它。")
                    .font(.system(size: 12)).foregroundStyle(Color(hex: "#A39888"))
                    .padding(.horizontal, 8).padding(.top, -10).padding(.bottom, 14)

                sec("用户类型")
                list {
                    row("当前账号") { Text("本机账号（未登录）").font(.system(size: 15, weight: .medium)).foregroundStyle(PT.body) }
                    row("本机 ID") { Text(store.s.prefs.localId ?? "—").font(.system(size: 14)).foregroundStyle(PT.muted).textSelection(.enabled) }
                    Button { onPlan() } label: {
                        row("类型") { Text("\(planName) ›").font(.system(size: 15, weight: .medium)).foregroundStyle(PT.body) }
                    }
                    .buttonStyle(.plain)
                }
                sec("数据")
                list {
                    Button { onBackup() } label: {
                        HStack(spacing: 10) {
                            Image("ac_cloud").renderingMode(.template).resizable().scaledToFit().frame(width: 22, height: 22).foregroundStyle(Color(hex: "#AEAEB2"))
                            Text("备份 / 恢复数据").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(PT.body)
                            Spacer()
                            Text("›").font(.system(size: 15, weight: .medium)).foregroundStyle(PT.body)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 50).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.adaptive("#FFFFFF", "#1E1E1D").ignoresSafeArea())
        .onAppear {
            guard !loaded else { return }
            let P = store.s.prefs
            nick = P.nick; bio = P.bio; gender = P.gender == "m" ? "m" : "f"; avatar = P.avatar
            loaded = true
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: d) {
                    avatar = ImageData.base64(ui, maxSide: 360)
                }
                pick = nil
            }
        }
    }

    private var planName: String {
        switch purchases.plan { case "year": return "年会员"; case "life": return "永久会员"; default: return "普通用户" }
    }

    private func save() {
        let n = nick.trimmingCharacters(in: .whitespaces)
        store.updatePrefs {
            $0.nick = n.isEmpty ? "我" : n
            $0.bio = bio
            $0.gender = gender
            $0.avatar = avatar
        }
        Feedback.tap()
        toaster.show("已保存", gray: true)
        dismiss()
    }

    private var previewPrefs: Prefs {
        var x = Prefs()
        x.avatar = avatar
        x.gender = gender
        return x
    }

    private func sec(_ t: String) -> some View {
        Text(t).font(.system(size: 13, weight: .semibold)).foregroundStyle(secInk).padding(.horizontal, 8).padding(.bottom, 8)
    }

    private func list<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(spacing: 0) { c() }
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(listBg))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(listLine, lineWidth: 1.5))
            .padding(.bottom, 18)
    }

    private func row<C: View>(_ t: String, @ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 12) {
            Text(t).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(PT.body)
            Spacer(minLength: 0)
            c().lineLimit(1)
        }
        .padding(.horizontal, 16).frame(minHeight: 50).contentShape(Rectangle())
    }
}

// MARK: - 习惯管理（已删除的习惯可以恢复）

struct CardManageView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var router: Router
    @State private var forever: Card?

    var body: some View {
        List {
            Section("正在使用（\(store.s.cards.count)）") {
                ForEach(store.s.cards) { c in
                    Button { router.designer = DesignerTarget(cardId: c.id) } label: {
                        HStack(spacing: 10) {
                            HabitCircle(card: c, checked: true, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).foregroundStyle(Theme.text)
                                Text(c.isNote ? "记录卡片" : store.s.daysLabel(c)).font(.system(size: 12)).foregroundStyle(Theme.text3)
                            }
                        }
                    }
                }
            }
            Section {
                if store.s.archived.isEmpty {
                    Text("没有已删除的习惯").foregroundStyle(Theme.text3)
                }
                ForEach(store.s.archived) { c in
                    HStack(spacing: 10) {
                        HabitCircle(card: c, checked: false, size: 34)
                        Text(c.name).foregroundStyle(Theme.text2)
                        Spacer()
                        Button("恢复") { store.restore(c.id); toaster.show("已恢复「\(c.name)」", gray: true) }
                            .buttonStyle(.borderless).foregroundStyle(Theme.text)
                    }
                    .swipeActions {
                        Button("彻底删除", role: .destructive) { forever = c }
                    }
                }
            } header: { Text("已删除") } footer: { Text("左滑可以彻底删除，连同它的全部打卡记录，无法撤销。") }
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("习惯管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog("彻底删除「\(forever?.name ?? "")」？", isPresented: Binding(get: { forever != nil }, set: { if !$0 { forever = nil } }), titleVisibility: .visible) {
            Button("彻底删除", role: .destructive) {
                if let c = forever { store.deleteForever(c.id) }
                forever = nil
            }
        } message: { Text("它的所有打卡记录和日志都会被删除，无法恢复。") }
    }
}

// MARK: - 习惯变动

struct EventsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let evs = store.s.events.sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
        let days = Array(Dictionary(grouping: evs, by: { $0.date }).keys).sorted(by: >)
        List {
            if evs.isEmpty { Text("还没有记录").foregroundStyle(Theme.text3) }
            ForEach(days, id: \.self) { d in
                Section(d == DK.today ? "今天" : "\(DK.year(DK.date(d)))年\(DK.md(d))") {
                    ForEach(Array(evs.filter { $0.date == d }.enumerated()), id: \.offset) { _, e in
                        HStack(spacing: 10) {
                            Image(systemName: icon(e.type)).foregroundStyle(color(e.type)).frame(width: 22)
                            Text(e.text).foregroundStyle(Theme.text)
                            Spacer()
                            Text(DK.hm(e.ts)).font(.system(size: 12)).foregroundStyle(Theme.text3)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("习惯变动")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func icon(_ t: String) -> String {
        switch t {
        case "del": return "minus.circle.fill"
        case "restore": return "arrow.uturn.backward.circle.fill"
        case "first": return "star.circle.fill"
        case "note": return "text.bubble.fill"
        case "jr": return "book.closed.fill"
        default: return "plus.circle.fill"
        }
    }
    private func color(_ t: String) -> Color {
        switch t {
        case "del": return Color(hex: "#EC6F6B")
        case "restore": return Color(hex: "#3D8FE0")
        case "first": return Color(hex: "#E2A72E")
        case "note", "jr": return Color(hex: "#C86FB0")
        default: return Theme.green
        }
    }
}

// MARK: - 文本页面（隐私政策、协议、致谢、指南）

struct DocView: View {
    let title: String
    let text: String
    var body: some View {
        ScrollView {
            Text(LocalizedStringKey(text))
                .font(.system(size: 15)).foregroundStyle(Theme.text).lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
        }
        .pageBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

struct GuideView: View {
    var body: some View { DocView(title: "使用指南", text: LegalText.guide) }
}
