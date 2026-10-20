import SwiftUI

// MARK: - 写笔记（网页版 openJournal：全屏纸张，左边日期，右边标题和正文，底部工具条）

struct JournalEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    let day: String
    let entryId: String?

    @State private var e = JournalEntry()
    @State private var key = DK.today
    @State private var loaded = false
    @State private var isNew = true
    @State private var snap: JournalEntry?
    @State private var askDiscard = false
    @State private var pickDate = false
    @State private var pickTime = false
    @FocusState private var focus: Field?

    enum Field { case title, body }

    static let fonts: [(String, String)] = [("sys", "系统"), ("round", "圆体"), ("kai", "楷体")]
    static let papers: [(id: String, name: String, light: String, dark: String)] = [
        ("white", "白色", "#FFFFFF", "#1B1B1A"), ("cream", "奶白", "#FBF8F2", "#2B2925"), ("mint", "薄荷", "#EEF7F0", "#232B26"), ("sky", "天青", "#EEF4FA", "#222830")
    ]

    private var dark: Bool { scheme == .dark }
    private var fontId: String { store.s.prefs.noteFont ?? "sys" }
    private var paper: (id: String, name: String, light: String, dark: String) { Self.papers.first { $0.id == store.s.prefs.noteBg } ?? Self.papers[0] }
    private var bg: Color { Color(hex: dark ? paper.dark : paper.light) }
    private var ink: Color { Theme.adaptive("#2B2A27", "#F2EDE4") }
    private var has: Bool { !e.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !e.title.trimmingCharacters(in: .whitespaces).isEmpty }
    private var changed: Bool {
        if isNew { return has }
        guard let o = snap else { return false }
        return o.title != e.title || o.text != e.text || o.c != e.c || key != day
    }
    private var cdate: Date { Date(timeIntervalSince1970: e.c / 1000) }

    static func font(_ id: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch id {
        case "round": return .system(size: size, weight: weight, design: .rounded)
        case "kai": return .custom("STKaiti", size: size).weight(weight)
        default: return .system(size: size, weight: weight)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            top
            HStack(alignment: .top, spacing: 14) {
                side
                VStack(alignment: .leading, spacing: 0) {
                    TextField("", text: $e.title, prompt: Text("标题（可选）").foregroundStyle(Color(hex: "#C5BDB1")))
                        .font(Self.font(fontId, size: 24, weight: .heavy))
                        .foregroundStyle(ink)
                        .focused($focus, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focus = .body }
                        .padding(.top, 2).padding(.bottom, 8)
                        .onChange(of: e.title) { _, v in if v.count > 30 { e.title = String(v.prefix(30)) } }
                    ZStack(alignment: .topLeading) {
                        if e.text.isEmpty {
                            Text("点一下开始写。今天发生了什么、想到了什么，随手记下来……")
                                .font(Self.font(fontId, size: 18)).lineSpacing(11)
                                .foregroundStyle(Color(hex: "#B9B2A7"))
                                .padding(.top, 8).padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $e.text)
                            .font(Self.font(fontId, size: 18)).lineSpacing(11)
                            .foregroundStyle(ink)
                            .scrollContentBackground(.hidden)
                            .focused($focus, equals: .body)
                            .onChange(of: e.text) { _, v in if v.count > 5000 { e.text = String(v.prefix(5000)) } }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 8)
            .frame(maxHeight: .infinity, alignment: .top)
            toolbar
        }
        .background(bg.ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: paper.id)
        .onAppear(perform: load)
        .confirmationDialog(isNew ? "放弃这篇笔记？" : "放弃这次修改？", isPresented: $askDiscard, titleVisibility: .visible) {
            Button("放弃", role: .destructive) { dismiss() }
            Button("继续写", role: .cancel) {}
        } message: { Text(isNew ? "写下的内容不会保存。" : "会恢复成打开前的内容。") }
    }

    // MARK: 顶栏：取消 · 笔记 · 完成

    private var top: some View {
        ZStack {
            Text("笔记").font(.system(size: 18, weight: .bold)).foregroundStyle(ink)
            HStack {
                Button { if changed { askDiscard = true } else { dismiss() } } label: {
                    Text("取消").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.adaptive("#4A3F45", "#ECE6DA"))
                        .padding(.horizontal, 18).frame(height: 44)
                        .background(Capsule().fill(dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)))
                }
                .buttonStyle(PressScale(scale: 0.95))
                Spacer()
                Button { save() } label: {
                    Text("完成").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(has ? Color(hex: "#4A3F45") : Color(hex: "#B9B2A7"))
                        .padding(.horizontal, 18).frame(height: 44)
                        .background(Capsule().fill(has ? Color(hex: "#FFE7A3") : (dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))))
                        .overlay { if has { Capsule().strokeBorder(Color(hex: "#4A3F45"), lineWidth: 1.5) } }
                }
                .buttonStyle(PressScale(scale: 0.95))
                .disabled(!has)
            }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
    }

    // MARK: 左边：日、周、时间

    private var side: some View {
        let d = DK.date(key)
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(DK.day(d))日").font(.system(size: 26, weight: .heavy)).foregroundStyle(ink).lineLimit(1).fixedSize()
            Text("周" + DK.wdName[DK.weekday(key)]).font(.system(size: 14)).foregroundStyle(Theme.adaptive("#5B4F45", "#CFC6B8"))
            Button { focus = nil; pickTime = true } label: {
                Text(DK.hm(e.c)).font(.system(size: 14)).monospacedDigit().foregroundStyle(Color(hex: "#A69C90"))
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .popover(isPresented: $pickTime) {
                DatePicker("", selection: Binding(get: { cdate }, set: { setTime($0) }), displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .frame(width: 260, height: 180)
                    .presentationCompactAdaptation(.popover)
            }
        }
        .padding(.trailing, 12)
        .frame(width: 66, alignment: .leading)
        .frame(minHeight: 150, alignment: .top)
        .overlay(alignment: .trailing) {
            Rectangle().fill(dark ? Color.white.opacity(0.12) : Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.12)).frame(width: 1.5)
        }
    }

    // MARK: 底部工具条：日期 | 字体 | 纸张颜色

    private var toolbar: some View {
        HStack(spacing: 0) {
            Button { focus = nil; Feedback.tap(); pickDate = true } label: {
                HStack(spacing: 4) {
                    Image("stg_calendar").renderingMode(.template).resizable().scaledToFit().frame(width: 17, height: 17)
                        .foregroundStyle(Color(hex: dark ? "#A9D59C" : "#7DBE6E"))
                    Text("\(DK.month(DK.date(key)))月\(DK.day(DK.date(key)))日").font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4")).lineLimit(1).fixedSize()
                }
                .padding(.horizontal, 4).frame(height: 34)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $pickDate) { datePop.presentationCompactAdaptation(.popover) }
            sep
            HStack(spacing: 4) {
                ForEach(Self.fonts, id: \.0) { f in
                    let on = fontId == f.0
                    Button { Feedback.tap(); store.updatePrefs { $0.noteFont = f.0 } } label: {
                        Text(f.1).font(Self.font(f.0, size: 13.5, weight: on ? .bold : .regular))
                            .foregroundStyle(on ? Color(hex: "#2E2A27") : Theme.adaptive("#7A6F64", "#CFC6B8"))
                            .padding(.horizontal, 6).frame(height: 34)
                            .background { if on { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#F2EDE4")) } }
                            .overlay { if on { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(hex: "#4A3F45"), lineWidth: 1.5) } }
                    }
                    .buttonStyle(.plain)
                }
            }
            sep
            HStack(spacing: 4) {
                ForEach(Self.papers, id: \.id) { p in
                    let on = paper.id == p.id
                    Button { Feedback.tap(); store.updatePrefs { $0.noteBg = p.id } } label: {
                        Circle().fill(Color(hex: dark && p.id == "white" ? p.dark : p.light))
                            .overlay(Circle().strokeBorder(dark && p.id == "white" ? Color.white.opacity(0.3) : Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.25), lineWidth: 1.5))
                            .frame(width: 24, height: 24)
                            .overlay { if on { Circle().stroke(Color(hex: "#4A3F45"), lineWidth: 1.5).padding(-3.5) } }
                            .frame(width: 30, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("背景：\(p.name)")
                }
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(dark ? Color.white.opacity(0.06) : Color.white.opacity(0.75)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(dark ? Color.white.opacity(0.08) : Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.10), lineWidth: 1.5))
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 10)
    }

    private var sep: some View {
        Rectangle().fill(dark ? Color.white.opacity(0.12) : Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.12)).frame(width: 1.5, height: 22).padding(.horizontal, 3)
    }

    private var datePop: some View {
        VStack(spacing: 8) {
            DatePicker("", selection: Binding(get: { DK.date(key) }, set: { setDay(DK.key($0)) }), in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical).labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .tint(Color(hex: "#7DBE6E"))
            HStack(spacing: 10) {
                Button("昨天") { setDay(DK.addKey(DK.today, -1)); pickDate = false }
                Button("今天") { setDay(DK.today); pickDate = false }
            }
            .font(.system(size: 14, weight: .semibold)).buttonStyle(.bordered).tint(Color(hex: "#5E9E52"))
        }
        .padding(12)
        .frame(width: 330)
    }

    // MARK: 数据

    private func load() {
        guard !loaded else { return }
        loaded = true
        key = day
        if let id = entryId, let old = store.s.journal[day]?.first(where: { $0.id == id }) {
            e = old; isNew = false; snap = old
        } else {
            e = JournalEntry()
            if day != DK.today {
                // 补写以前的笔记：日期用那天，时间用现在
                let n = Date(), comps = DK.calendar.dateComponents([.hour, .minute], from: n)
                let x = DK.calendar.date(bySettingHour: comps.hour ?? 12, minute: comps.minute ?? 0, second: 0, of: DK.date(day)) ?? n
                e.c = x.timeIntervalSince1970 * 1000
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focus = .body }
        }
    }

    private func setDay(_ v: String) {
        guard v != key, v <= DK.today else { return }
        let comps = DK.calendar.dateComponents([.hour, .minute], from: cdate)
        let x = DK.calendar.date(bySettingHour: comps.hour ?? 12, minute: comps.minute ?? 0, second: 0, of: DK.date(v)) ?? DK.date(v)
        e.c = x.timeIntervalSince1970 * 1000
        key = v
        Feedback.tap()
    }

    private func setTime(_ t: Date) {
        let comps = DK.calendar.dateComponents([.hour, .minute], from: t)
        let x = DK.calendar.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: DK.date(key)) ?? t
        e.c = x.timeIntervalSince1970 * 1000
    }

    private func save() {
        guard has else { return }
        Feedback.tap()
        if isNew { store.saveJournal(e, on: key) } else { store.moveJournal(e, from: day, to: key) }
        toaster.show(isNew ? "笔记已保存" : "已保存", gray: true)
        dismiss()
    }
}

// MARK: - 回忆：日历 + 当天时间线

struct MemoryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    /// 当底部栏的一个页签时没有返回键
    var asTab = false

    @State private var y = DK.year(DK.todayDate)
    @State private var m = DK.month(DK.todayDate)
    @State private var sel = DK.today
    @State private var editing: JournalTarget?
    @State private var showJr = false

    private var dark: Bool { scheme == .dark }
    private var ink: Color { Theme.adaptive("#3E3532", "#F2EDE4") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image("mm_sun").resizable().frame(width: 26, height: 26)
                    Text("今天的小小进步，都收在这里").font(.system(size: 15)).foregroundStyle(Theme.adaptive("#7A6F64", "#B8AE9C"))
                }
                .padding(.horizontal, 4).padding(.top, 2).padding(.bottom, 16)
                calendar.padding(.top, 14)
                dayHead
                stats
                timeline.padding(.top, 16)
            }
            .padding(.horizontal, asTab ? 16 : 18).padding(.top, 10).padding(.bottom, asTab ? 130 : 30)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            if asTab {
                Text("回忆").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(Theme.adaptive("#FFFFFFE6", "#1E1E1DE6")).background(.ultraThinMaterial)
            } else {
                PageTop(title: "回忆", back: { dismiss() })
            }
        }
        .background((asTab ? AnyView(PageBG()) : AnyView(Theme.adaptive("#FFFFFF", "#1E1E1D"))).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $editing) { t in
            JournalEditor(day: t.day, entryId: t.entryId)
                .environmentObject(store).environmentObject(toaster)
        }
        .sheet(isPresented: $showJr) {
            JournalRangeSheet(from: sel, to: sel, label: "\(DK.month(DK.date(sel)))月\(DK.day(DK.date(sel)))日")
                .environmentObject(store).environmentObject(toaster)
                .presentationCornerRadius(30).presentationDragIndicator(.visible)
        }
    }

    // MARK: 月历（顶上两个「装订环」）

    private var calendar: some View {
        let t = DK.todayDate, ty = DK.year(t), tm = DK.month(t)
        let first = DK.calendar.date(from: DateComponents(year: y, month: m, day: 1)) ?? t
        let n = DK.daysInMonth(first)
        let ws = store.s.prefs.weekStart == 0 ? 0 : 1
        let lead = (DK.weekday(first) - ws + 7) % 7
        let wd = ws == 1 ? ["一", "二", "三", "四", "五", "六", "日"] : ["日", "一", "二", "三", "四", "五", "六"]
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                navBtn("«", disabled: false) { y -= 1 }
                navBtn("‹", disabled: false) { m -= 1; if m < 1 { m = 12; y -= 1 } }
                Text(verbatim: "\(y)年\(m)月").font(.system(size: 19, weight: .bold)).monospacedDigit().foregroundStyle(ink).frame(maxWidth: .infinity)
                navBtn("›", disabled: y == ty && m >= tm) { m += 1; if m > 12 { m = 1; y += 1 } }
                navBtn("»", disabled: y >= ty) { y += 1; if y == ty && m > tm { m = tm } }
            }
            .padding(.horizontal, 4).padding(.top, 6).padding(.bottom, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.adaptive("#EFE9DD", "#3A3732")).frame(height: 1.5) }
            HStack(spacing: 0) {
                ForEach(wd, id: \.self) { w in Text(w).font(.system(size: 13)).foregroundStyle(Color(hex: "#A69C90")).frame(maxWidth: .infinity) }
            }
            .padding(.top, 12).padding(.bottom, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(0..<lead, id: \.self) { i in Color.clear.frame(height: 46).id("l\(i)") }
                ForEach(1...n, id: \.self) { i in
                    let k = DK.key(DK.add(first, i - 1))
                    let has = !store.s.dayCheckins(k).isEmpty || !store.s.journalList(k).isEmpty
                    let fut = k > DK.today, isSel = k == sel
                    Button { Feedback.tap(); sel = k } label: {
                        ZStack {
                            Text("\(i)").font(.system(size: 16, weight: k == DK.today ? .heavy : isSel ? .bold : .medium)).monospacedDigit()
                                .foregroundStyle(ink)
                                .frame(width: 31, height: 31)
                                .background { if isSel { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.adaptive("#FBEFD9", "#4A4237")) } }
                                .overlay { if isSel { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.adaptive("#C9BBA6", "#7A6F62"), lineWidth: 1.2) } }
                                .padding(.bottom, 6)
                            if has { Circle().fill(Color(hex: "#8DB98A")).frame(width: 5, height: 5).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 1) }
                            if isSel {
                                Image("mm_sprout").resizable().frame(width: 18, height: 18).rotationEffect(.degrees(14))
                                    .offset(x: 14, y: -17)
                            }
                        }
                        .frame(height: 46).frame(maxWidth: .infinity)
                        .opacity(fut ? 0.35 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(fut)
                }
            }
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 14)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.adaptive("#FFFDF8", "#2A2825")))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.adaptive("#EAE3D6", "#3A3732"), lineWidth: 1.5))
        .overlay(alignment: .top) {
            GeometryReader { g in
                ring.position(x: g.size.width * 0.24 + 6, y: 0)
                ring.position(x: g.size.width * 0.76 - 6, y: 0)
            }
        }
    }

    private var ring: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.adaptive("#FBEFD9", "#4A4237"))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.adaptive("#5B4F45", "#E8E0D2"), lineWidth: 1.5))
            .frame(width: 12, height: 26)
    }

    private func navBtn(_ t: String, disabled: Bool, _ a: @escaping () -> Void) -> some View {
        Button { Feedback.tap(); a() } label: {
            Text(t).font(.system(size: 22)).foregroundStyle(Theme.adaptive("#5B4F45", "#F2EDE4")).frame(width: 30, height: 32)
        }
        .buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.25 : 1)
    }

    // MARK: 选中那天：大号日期 + 四个数字

    private var dayHead: some View {
        let d = DK.date(sel)
        return HStack(spacing: 12) {
            Text("\(DK.day(d))").font(.system(size: 52, weight: .heavy)).monospacedDigit().tracking(-1).foregroundStyle(ink)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(DK.month(d))月 · 周\(DK.wdName[DK.weekday(sel)])").font(.system(size: 17, weight: .semibold)).foregroundStyle(ink)
                Text(verbatim: "\(DK.year(d))").font(.system(size: 15)).foregroundStyle(Color(hex: "#9C9186"))
            }
            Spacer()
            if let mood = store.s.moodOf(sel) {
                VStack(spacing: 2) {
                    Image(mood.asset).resizable().frame(width: 34, height: 34)
                    Text(mood.name).font(.system(size: 12)).foregroundStyle(Color(hex: "#8F857A"))
                }
            }
        }
        .padding(.horizontal, 4).padding(.top, 26).padding(.bottom, 14)
    }

    private var stats: some View {
        let chk = store.s.dayCheckins(sel).filter { !$0.card.isNote }
        let jr = store.s.journalList(sel)
        let sched = store.s.checkCards.filter { store.s.scheduled($0, sel) }.count
        let rate = sched > 0 ? Int((Double(min(chk.count, sched)) / Double(sched) * 100).rounded()) : 0
        var streak = 0
        var dd = DK.date(sel)
        while !store.s.dayCheckins(DK.key(dd)).isEmpty { streak += 1; dd = DK.add(dd, -1) }
        let divider = Rectangle().fill(Theme.adaptive("#E6DDCC", "#3A3732")).frame(width: 1.5, height: 30)
        return HStack(spacing: 0) {
            stat("mm_check", "\(chk.count)", "打卡")
            divider
            Button { if !jr.isEmpty { Feedback.tap(); showJr = true } } label: {
                stat("mm_note", "\(jr.count)", jr.isEmpty ? "笔记" : "笔记 ›", green: !jr.isEmpty)
            }
            .buttonStyle(.plain)
            divider
            stat("mm_rate", "\(rate)%", "完成率")
            divider
            stat("mm_streak", "\(streak)", "连续天")
        }
        .padding(.horizontal, 6).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.adaptive("#F6F0E4", "#2A2825")))
    }

    private func stat(_ icon: String, _ v: String, _ l: String, green: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(icon).resizable().frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(v).font(.system(size: 15, weight: .bold)).monospacedDigit().foregroundStyle(ink)
                Text(l).font(.system(size: 10.5, weight: green ? .semibold : .regular)).foregroundStyle(Color(hex: green ? "#6F9A63" : "#8F857A"))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 时间线（上午 / 下午 / 晚上）

    private struct Row: Identifiable { let id: String; let t: Double?; let card: Card?; let jr: JournalEntry? }

    private var timeline: some View {
        let chk = store.s.dayCheckins(sel)
        let jr = store.s.journalList(sel)
        var rows = chk.map { Row(id: "c" + $0.card.id, t: $0.rec.t, card: $0.card, jr: nil) } + jr.map { Row(id: "j" + $0.id, t: $0.c, card: nil, jr: $0) }
        rows.sort { ($0.t.flatMap { $0 > 1e12 ? $0 : nil } ?? 9e15) < ($1.t.flatMap { $0 > 1e12 ? $0 : nil } ?? 9e15) }
        let part: (Double?) -> Int = { t in
            guard let t, t > 1e12 else { return 0 }
            let h = DK.calendar.component(.hour, from: Date(timeIntervalSince1970: t / 1000))
            return h < 12 ? 0 : h < 18 ? 1 : 2
        }
        let parts: [(String, String, String)] = [("上午", "mm_sprout", "#EEF5EA"), ("下午", "mm_cloudsun", "#FBF3DF"), ("晚上", "mm_moon", "#EEEDF8")]
        return VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                HStack(spacing: 10) {
                    Image("mm_sprout").resizable().frame(width: 22, height: 22)
                    Text("这一天还没有记录\n打卡、写笔记之后会出现在这里").font(.system(size: 13.5)).lineSpacing(5).foregroundStyle(Color(hex: "#9C9186"))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                ForEach(0..<3, id: \.self) { pi in
                    let list = rows.filter { part($0.t) == pi }
                    if !list.isEmpty {
                        HStack(spacing: 8) {
                            Image(parts[pi].1).resizable().scaledToFit().frame(width: 22, height: 22).frame(width: 30)
                            Text(parts[pi].0).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Color(hex: "#4A4038"))
                                .padding(.horizontal, 13).frame(height: 30)
                                .background(Capsule().fill(Color(hex: parts[pi].2)))
                                .brightness(dark ? -0.08 : 0)
                            Rectangle().fill(Theme.adaptive("#EFE9DD", "#3A3732")).frame(height: 1.5).padding(.leading, 6)
                        }
                        .padding(.top, 4).padding(.bottom, 6)
                        ForEach(list) { r in row(r, pi) }
                    }
                }
                Image("mm_sprout").resizable().frame(width: 22, height: 22).padding(.leading, 4).padding(.top, 6)
            }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.adaptive("#FFFDF8", "#2A2825")))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.adaptive("#EAE3D6", "#3A3732"), lineWidth: 1.5))
    }

    @ViewBuilder private func row(_ r: Row, _ pi: Int) -> some View {
        let fl = r.jr != nil ? "mm_flower2" : pi == 2 ? "mm_flower1" : "mm_flower0"
        let content = HStack(spacing: 10) {
            Image(fl).resizable().frame(width: 14, height: 14).frame(width: 30)
            Text(r.t.map { DK.hm($0) }.flatMap { $0.isEmpty ? nil : $0 } ?? "—").font(.system(size: 13.5)).monospacedDigit()
                .foregroundStyle(Color(hex: "#B3AA9E")).frame(width: 44, alignment: .leading)
            if let c = r.card {
                Group {
                    if c.ic == "text" {
                        Text(c.text.isEmpty ? String(c.name.prefix(1)) : c.text).font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: "#3E3532"))
                    } else if c.ic == "img", let ui = ImageData.image(c.icImg) {
                        Image(uiImage: ui).resizable().scaledToFill().frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(IconCatalog.assetName(c.icon)).resizable().scaledToFit().frame(width: 28, height: 28)
                    }
                }
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(cmix(c.hex, 0.22, "#FFFFFF")))
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                    Text("已完成").font(.system(size: 13)).foregroundStyle(Color(hex: "#B3AA9E"))
                }
            } else {
                Image("mm_note").resizable().frame(width: 28, height: 28)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color(hex: "#FDF1CF")))
                VStack(alignment: .leading, spacing: 2) {
                    Text("写了一篇笔记").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(ink)
                    Text("点开查看").font(.system(size: 13)).foregroundStyle(Color(hex: "#B3AA9E"))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .background(alignment: .leading) { Rectangle().fill(Color(hex: "#D8D2C2")).frame(width: 1.5).padding(.leading, 14.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.adaptive("#F3EEE4", "#3A3732")).frame(height: 1.5) }
        if let j = r.jr {
            Button { editing = JournalTarget(day: sel, entryId: j.id) } label: { content.contentShape(Rectangle()) }.buttonStyle(.plain)
        } else { content }
    }
}
