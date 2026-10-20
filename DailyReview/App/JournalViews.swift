import SwiftUI

// MARK: - 写笔记

struct JournalEditor: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @Environment(\.dismiss) private var dismiss

    let day: String
    let entryId: String?

    @State private var e = JournalEntry()
    @State private var date = Date()
    @State private var loaded = false
    @State private var isNew = true
    @State private var confirmDelete = false
    @FocusState private var bodyFocused: Bool

    private var dirty: Bool {
        guard let old = store.s.journal[day]?.first(where: { $0.id == e.id }) else { return !e.text.isEmpty || !e.title.isEmpty }
        return old.title != e.title || old.text != e.text || old.font != e.font || DK.key(date) != day
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: isNew ? "写笔记" : "笔记") {
                Button("取消") { dismiss() }.foregroundStyle(Theme.text2)
            } trailing: {
                Button("保存") { save() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canSave ? Theme.text : Theme.text3)
                    .disabled(!canSave)
            }
            HStack(spacing: 10) {
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                Spacer()
                Menu {
                    Picker("字体", selection: Binding(get: { e.font ?? "sys" }, set: { e.font = $0 })) {
                        Text("系统字体").tag("sys"); Text("圆体").tag("round"); Text("宋体").tag("kai")
                    }
                } label: {
                    Image(systemName: "textformat").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                        .frame(width: 34, height: 34).background(Circle().fill(Theme.pill))
                }
                .accessibilityLabel("字体")
                if !isNew {
                    Button { confirmDelete = true } label: {
                        Image(systemName: "trash").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "#E0525A"))
                            .frame(width: 34, height: 34).background(Circle().fill(Theme.pill))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除")
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 6) {
                TextField("标题（可不填）", text: $e.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.text)
                Divider()
                ZStack(alignment: .topLeading) {
                    if e.text.isEmpty {
                        Text("今天有什么想记下来的？").font(AppFont.note(e.font, size: 16)).foregroundStyle(Theme.text3)
                            .padding(.top, 8).padding(.leading, 5)
                    }
                    TextEditor(text: $e.text)
                        .font(AppFont.note(e.font, size: 16))
                        .lineSpacing(5)
                        .scrollContentBackground(.hidden)
                        .focused($bodyFocused)
                }
            }
            .padding(.horizontal, 16)
            HStack {
                Text("\(e.text.count) 字").font(.system(size: 11.5)).foregroundStyle(Theme.text3)
                Spacer()
                if !isNew { Text("创建于 \(DK.md(DK.key(Date(timeIntervalSince1970: e.c / 1000)))) \(DK.hm(e.c))").font(.system(size: 11.5)).foregroundStyle(Theme.text3) }
            }
            .padding(.horizontal, 18).padding(.vertical, 8)
        }
        .background(Theme.adaptive("#FFFDF8", "#1B1B1A").ignoresSafeArea())
        .interactiveDismissDisabled(dirty)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            date = DK.date(day)
            if let id = entryId, let old = store.s.journal[day]?.first(where: { $0.id == id }) {
                e = old; isNew = false
            } else {
                e = JournalEntry()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { bodyFocused = true }
            }
        }
        .confirmationDialog("删除这篇笔记？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.deleteJournal(e.id, on: day)
                toaster.show("已删除", gray: true)
                dismiss()
            }
        }
    }

    private var canSave: Bool { !e.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !e.title.trimmingCharacters(in: .whitespaces).isEmpty }

    private func save() {
        let to = DK.key(date)
        if isNew { store.saveJournal(e, on: to) } else { store.moveJournal(e, from: day, to: to) }
        Feedback.success()
        toaster.show("已保存", gray: true)
        dismiss()
    }
}

// MARK: - 今日复盘（三个问题）

struct ReviewSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @Environment(\.dismiss) private var dismiss

    let day: String
    @State private var ans: [String: String] = [:]
    @State private var existing: JournalEntry?
    @State private var loaded = false

    static let questions: [(key: String, q: String, hint: String, icon: String, hex: String)] = [
        ("good", "今天做得好的一件事", "比如：早起没有赖床", "hand.thumbsup.fill", "#5CB874"),
        ("less", "有点遗憾的地方", "比如：晚上刷手机太久", "cloud.drizzle.fill", "#62B6E0"),
        ("next", "明天最想完成的一件事", "比如：读完第三章", "flag.fill", "#F29D38")
    ]

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: day == DK.today ? "今日复盘" : "\(DK.md(day)) 复盘") {
                Button("取消") { dismiss() }.foregroundStyle(Theme.text2)
            } trailing: {
                Button("保存") { save() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(hasAny ? Theme.text : Theme.text3)
                    .disabled(!hasAny)
            }
            ScrollView {
                VStack(spacing: 14) {
                    dayCheckins
                    ForEach(Self.questions.indices, id: \.self) { i in
                        let q = Self.questions[i]
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: q.icon).font(.system(size: 13)).foregroundStyle(Color(hex: q.hex))
                                Text(q.q).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                            }
                            TextField(q.hint, text: Binding(get: { ans[q.key] ?? "" }, set: { ans[q.key] = $0 }), axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(2...6)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.tile))
                        }
                    }
                    if existing != nil {
                        Button("删除这次复盘", role: .destructive) {
                            if let e = existing { store.deleteJournal(e.id, on: day) }
                            dismiss()
                        }
                        .font(.system(size: 14)).padding(.top, 6)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.pageBg.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let e = store.s.journalList(day).first(where: { $0.isReview }) {
                existing = e
                ans = e.ans ?? [:]
            }
        }
    }

    /// 顶部显示当天完成了哪些
    @ViewBuilder private var dayCheckins: some View {
        let list = store.s.dayCheckins(day).filter { !$0.card.isNote }
        let total = store.s.visibleCards(on: day).filter { !$0.isNote }.count
        VStack(alignment: .leading, spacing: 10) {
            Text("今天完成了 \(list.count)/\(max(total, list.count)) 个习惯").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text2)
            if !list.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(list.indices, id: \.self) { i in
                            let x = list[i]
                            VStack(spacing: 4) {
                                HabitCircle(card: x.card, checked: true, size: 40)
                                Text(x.card.name).font(.system(size: 10.5)).foregroundStyle(Theme.text2).lineLimit(1)
                            }
                            .frame(width: 54)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.adaptive("#F2F8F3", "#232B25")))
    }

    private var hasAny: Bool { ans.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }

    private func save() {
        var e = existing ?? JournalEntry(title: "今日复盘", kind: "review")
        var clean: [String: String] = [:]
        for (k, v) in ans {
            let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { clean[k] = t }
        }
        e.ans = clean
        e.text = Self.questions.compactMap { q in clean[q.key].map { "\(q.q)\n\($0)" } }.joined(separator: "\n\n")
        store.saveJournal(e, on: day)
        Feedback.success()
        toaster.show("复盘已保存", gray: true)
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
        .sheet(item: $editing) { t in
            JournalEditor(day: t.day, entryId: t.entryId)
                .environmentObject(store).environmentObject(toaster)
                .presentationDragIndicator(.visible)
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
