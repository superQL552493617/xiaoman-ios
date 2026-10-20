import Foundation

// 所有计算规则都和网页原型 v256 一致

enum Period: String, CaseIterable, Identifiable {
    case week, month, year
    var id: String { rawValue }
    var name: String { self == .week ? "周" : self == .month ? "月" : "年" }
}

struct HabitStats {
    var cur = 0          // 当前连续
    var best = 0         // 最长连续
    var rate: Int?       // 本月完成率
    var last = "还没打过卡"
    var w7 = 0           // 最近 7 天打卡次数
    var total = 0        // 累计打卡天数
}

struct PerCardStat: Identifiable {
    var card: Card
    var n: Int
    var rate: Int?
    var slots: Int
    /// 应打卡的日子里完成了几天（和完成率对应）
    var done: Int = 0
    var id: String { card.id }
}

struct PeriodStats {
    var start: Date
    var end: Date          // 这一期的最后一天
    var until: Date        // 统计截止（今天或期末）
    var label: String
    var checks = 0
    var notes = 0
    var jn = 0
    var days = 0
    var dayList: [String] = []
    var slots = 0
    var done = 0
    var rate = 0
    var perCard: [PerCardStat] = []
    var wk = [0, 0, 0, 0, 0, 0, 0]
    var evs: [EventItem] = []
}

struct SeriesPoint: Identifiable {
    var id: Int
    var label: String
    var value: Int
    var future: Bool
}

extension AppState {
    var checkCards: [Card] { cards.filter { !$0.isNote } }
    var noteIds: Set<String> { Set((cards + archived).filter { $0.isNote }.map { $0.id }) }

    func card(_ id: String) -> Card? { cards.first { $0.id == id } }
    func cardAny(_ id: String) -> Card? { card(id) ?? archived.first { $0.id == id } }

    func rec(_ k: String, _ id: String) -> Rec? { records[k]?[id] }
    func isChecked(_ k: String, _ id: String) -> Bool { records[k]?[id]?.checked == true }

    // MARK: 循环日 / 暂停

    func daysOn(_ c: Card, _ k: String) -> [Int] {
        if let H = c.daysHist {
            for h in H.sorted(by: { $0.until < $1.until }) where k < h.until { return h.days }
        }
        return c.days
    }

    func pausedOn(_ c: Card, _ k: String) -> Bool {
        (c.pauses ?? []).contains { k >= $0.from && ($0.until == nil || k < $0.until!) }
    }

    func activePause(_ c: Card) -> Pause? {
        let T = DK.today
        return (c.pauses ?? []).first { $0.until == nil || $0.until! > T }
    }

    func scheduled(_ c: Card, _ k: String) -> Bool {
        daysOn(c, k).contains(DK.weekday(k)) && !pausedOn(c, k)
    }

    /// 习惯从哪天开始算（创建日期，或者更早的第一次打卡）
    func cardStart(_ c: Card) -> String? {
        var st = c.createdAt
        let T = DK.today
        for (k, day) in records where k <= T {
            if day[c.id]?.checked == true, st == nil || k < st! { st = k }
        }
        return st
    }

    // MARK: 当天

    /// 当天打卡页显示哪些卡片
    func visibleCards(on k: String) -> [Card] {
        cards.filter { c in
            if c.isNote { return (c.createdAt ?? "") == k || records[k]?[c.id] != nil }
            if pausedOn(c, k) { return false }
            return scheduled(c, k) || isChecked(k, c.id)
        }
    }

    func dayCount(_ k: String) -> Int {
        guard let d = records[k] else { return 0 }
        let N = noteIds
        return d.filter { $0.value.checked && !N.contains($0.key) }.count
    }

    func dayCheckins(_ k: String) -> [(card: Card, rec: Rec)] {
        guard let d = records[k] else { return [] }
        var out: [(card: Card, rec: Rec)] = []
        for (id, r) in d where r.checked {
            if let c = cardAny(id) { out.append((c, r)) }
        }
        return out.sorted { ($0.rec.t ?? 9e15) < ($1.rec.t ?? 9e15) }
    }

    func journalList(_ k: String) -> [JournalEntry] { (journal[k] ?? []).sorted { $0.c < $1.c } }
    var journalTotal: Int { journal.values.reduce(0) { $0 + $1.count } }

    func moodOf(_ k: String) -> Mood? { Mood.find(mood[k]) }

    // MARK: 单个习惯

    func habitStats(_ c: Card) -> HabitStats {
        var s = HabitStats()
        let T = DK.today, t0 = DK.todayDate
        let done: (String) -> Bool = { self.isChecked($0, c.id) }
        let st = cardStart(c)
        let start = st.map { DK.date($0) } ?? DK.add(t0, -365)

        var d = t0, first = true
        while d >= start {
            let k = DK.key(d)
            if !scheduled(c, k) && !done(k) { d = DK.add(d, -1); first = false; continue }
            if done(k) { s.cur += 1 } else if first { d = DK.add(d, -1); first = false; continue } else { break }
            d = DK.add(d, -1); first = false
        }

        var run = 0
        d = start
        while d <= t0 {
            let k = DK.key(d)
            if !scheduled(c, k) && !done(k) { d = DK.add(d, 1); continue }
            if done(k) { run += 1; s.best = max(s.best, run) } else if k != T { run = 0 }
            d = DK.add(d, 1)
        }

        var sl = 0, dn = 0
        d = DK.monthStart(t0)
        while d <= t0 {
            let k = DK.key(d)
            d = DK.add(d, 1)
            if let st, k < st { continue }
            if !scheduled(c, k) { continue }
            if k == T && !done(k) { continue }
            sl += 1
            if done(k) { dn += 1 }
        }
        s.rate = sl > 0 ? Int((Double(dn) / Double(sl) * 100).rounded()) : nil

        var last: String?
        d = t0
        for _ in 0..<400 { let k = DK.key(d); if done(k) { last = k; break }; d = DK.add(d, -1) }
        if let last {
            let ld = DK.daysBetween(DK.date(last), t0)
            s.last = ld == 0 ? "今天" : ld == 1 ? "昨天" : ld < 7 ? "\(ld) 天前" : DK.md(last)
        }
        s.w7 = (0..<7).filter { done(DK.key(DK.add(t0, $0 - 6))) }.count
        s.total = records.filter { $0.key <= T && $0.value[c.id]?.checked == true }.count
        return s
    }

    /// 最近 7 天每天是否完成（给习惯卡片上的小圆点用）
    func last7(_ c: Card) -> [Bool] {
        let t0 = DK.todayDate
        return (0..<7).map { isChecked(DK.key(DK.add(t0, $0 - 6)), c.id) }
    }

    // MARK: 一段时间

    func periodRange(_ per: Period, _ off: Int) -> (s: Date, e: Date, label: String) {
        let t = DK.todayDate
        switch per {
        case .week:
            let b = DK.add(t, off * 7)
            let s = DK.weekStart(of: b, weekStart: prefs.weekStart)
            let e = DK.add(s, 6)
            let label = off == 0 ? "本周" : off == -1 ? "上周" : "\(DK.md(DK.key(s)))–\(DK.md(DK.key(e)))"
            return (s, e, label)
        case .month:
            let s = DK.calendar.date(byAdding: .month, value: off, to: DK.monthStart(t)) ?? t
            let e = DK.add(s, DK.daysInMonth(s) - 1)
            let label = off == 0 ? "本月" : "\(DK.year(s))年\(DK.month(s))月"
            return (s, e, label)
        case .year:
            let y = DK.year(t) + off
            let s = DK.calendar.date(from: DateComponents(year: y, month: 1, day: 1)) ?? t
            let e = DK.calendar.date(from: DateComponents(year: y, month: 12, day: 31)) ?? t
            return (s, e, off == 0 ? "今年" : "\(y)年")
        }
    }

    func periodStats(_ per: Period, _ off: Int) -> PeriodStats {
        let (s, e, label) = periodRange(per, off)
        let T = DK.today, today0 = DK.todayDate
        let until = e < today0 ? e : today0
        var st = PeriodStats(start: s, end: e, until: until, label: label)
        let N = noteIds
        var starts: [String: String] = [:]
        for c in checkCards { if let k = cardStart(c) { starts[c.id] = k } }
        var byCard: [String: Int] = [:]
        var days = Set<String>()

        var d = s
        while d <= e {
            let k = DK.key(d)
            if d <= today0 {
                let day = records[k] ?? [:]
                for (id, r) in day {
                    if r.checked && !N.contains(id) {
                        st.checks += 1; days.insert(k); byCard[id, default: 0] += 1
                        st.wk[DK.weekday(d)] += 1
                    }
                    if r.hasNote { st.notes += 1 }
                }
                for c in checkCards {
                    if let sk = starts[c.id], sk > k { continue }
                    if !scheduled(c, k) { continue }
                    let ok = day[c.id]?.checked == true
                    if k == T && !ok { continue }
                    st.slots += 1
                    if ok { st.done += 1 }
                }
            }
            d = DK.add(d, 1)
        }
        st.rate = st.slots > 0 ? Int((Double(st.done) / Double(st.slots) * 100).rounded()) : 0
        st.days = days.count
        st.dayList = days.sorted()

        st.perCard = checkCards.map { c in
            var sl = 0, dn = 0
            var x = s
            while x <= until {
                let k = DK.key(x)
                x = DK.add(x, 1)
                if let sk = starts[c.id], sk > k { continue }
                if !scheduled(c, k) { continue }
                let ok = isChecked(k, c.id)
                if k == T && !ok { continue }
                sl += 1
                if ok { dn += 1 }
            }
            return PerCardStat(card: c, n: byCard[c.id] ?? 0, rate: sl > 0 ? Int((Double(dn) / Double(sl) * 100).rounded()) : nil, slots: sl, done: dn)
        }
        let sk = DK.key(s), ek = DK.key(e), uk = DK.key(until)
        st.evs = allChangeEvents.filter { ["add", "del", "restore"].contains($0.type) && $0.date >= sk && $0.date <= ek }
        st.jn = journal.filter { $0.key >= sk && $0.key <= uk }.reduce(0) { $0 + $1.value.count }
        return st
    }

    func series(_ per: Period, _ off: Int) -> [SeriesPoint] {
        let (s, e, _) = periodRange(per, off)
        let today = DK.todayDate
        var out: [SeriesPoint] = []
        if per == .year {
            let y = DK.year(s)
            for m in 1...12 {
                let ms = DK.calendar.date(from: DateComponents(year: y, month: m, day: 1)) ?? s
                var n = 0
                var d = ms
                while DK.month(d) == m && d <= today { n += dayCount(DK.key(d)); d = DK.add(d, 1) }
                out.append(SeriesPoint(id: m, label: "\(m)", value: n, future: ms > today))
            }
        } else {
            var d = s, i = 0
            while d <= e {
                let fut = d > today
                out.append(SeriesPoint(id: i, label: per == .week ? DK.wdName[DK.weekday(d)] : "\(DK.day(d))", value: fut ? 0 : dayCount(DK.key(d)), future: fut))
                d = DK.add(d, 1); i += 1
            }
        }
        return out
    }

    /// 习惯变动（和网页版 allEvents 一样：没记过「新增」的习惯，用创建日期补一条），新的在前
    var allChangeEvents: [EventItem] {
        let N = noteIds
        var out = events.filter { !N.contains($0.id) }
        let have = Set(out.map { $0.type + "|" + $0.id })
        let keys = records.keys.sorted()
        let T = DK.today
        for c in (cards + archived) where !c.isNote && !have.contains("add|" + c.id) {
            var first: String?
            for k in keys where k <= T { if records[k]?[c.id]?.checked == true { first = k; break } }
            if let d = c.createdAt ?? first ?? keys.first { out.append(EventItem(type: "add", id: c.id, name: c.name, date: d, ts: 0)) }
        }
        return out.sorted { a, b in a.date != b.date ? a.date > b.date : (a.ts ?? 0) > (b.ts ?? 0) }
    }

    // MARK: 打卡总结（键和网页版一致："week|2026-10-12"）

    struct SumTarget {
        var per: Period
        var off: Int
        var s: Date
        var e: Date
        var label: String
        var key: String
        var picked: Bool
    }

    func sumTarget(_ per: Period, _ off: Int) -> SumTarget {
        let r = periodRange(per, off)
        let md = { (d: Date) in DK.md(DK.key(d)) }
        let label: String
        switch per {
        case .week: label = (off == -1 ? "上周 " : "") + "\(md(r.s))–\(md(r.e))"
        case .month: label = "\(DK.year(r.s))年\(DK.month(r.s))月"
        case .year: label = "\(DK.year(r.s))年"
        }
        return SumTarget(per: per, off: off, s: r.s, e: r.e, label: label, key: "\(per.rawValue)|\(DK.key(r.s))", picked: off != -1)
    }

    func sumLabel(_ t: SumTarget) -> String {
        t.per == .week ? "\(t.label) · 周总结" : "\(t.label) · \(t.per == .year ? "年度" : "月度") AI 总结"
    }

    static func hashN(_ s: String) -> UInt32 {
        var h: UInt32 = 7
        for u in s.utf16 { h = h &* 31 &+ UInt32(u) }
        return h
    }

    /// 周总结：只在本机统计（和网页版 weekText 一样，数字用 <b> 加粗）
    func weekText(_ off: Int) -> AISum {
        let st = periodStats(.week, off), pv = periodStats(.week, off - 1)
        let rated = st.perCard.filter { $0.rate != nil && $0.slots > 0 }
        let best = rated.max { ($0.rate ?? 0) < ($1.rate ?? 0) }
        let low = rated.min { ($0.rate ?? 0) < ($1.rate ?? 0) }
        let md = { (d: Date) in DK.md(DK.key(d)) }
        var p: [String] = []
        let dr = st.rate - pv.rate
        var first = "\(md(st.start))–\(md(st.end)) 这一周你打卡 <b>\(st.checks)</b> 次，有 <b>\(st.days)</b> 天打了卡，完成率 <b>\(st.rate)%</b>"
        if pv.slots > 0 { first += "，" + (dr > 0 ? "比前一周高 \(dr) 个百分点" : dr < 0 ? "比前一周低 \(-dr) 个百分点" : "和前一周持平") }
        p.append(first + "。")
        if let best, (best.rate ?? 0) > 0 {
            var t = "最稳的习惯：「\(best.card.name)」\(best.done)/\(best.slots) 天，完成率 <b>\(best.rate ?? 0)%</b>。"
            if let low, low.card.id != best.card.id, (low.rate ?? 0) < (best.rate ?? 0) {
                t += "最需要加把劲：「\(low.card.name)」\(low.done)/\(low.slots) 天，完成率 \(low.rate ?? 0)%。"
            }
            p.append(t)
        }
        if st.checks > 0, let mx = st.wk.indices.max(by: { st.wk[$0] < st.wk[$1] }) {
            p.append("打卡最多的一天是周\(DK.wdName[mx])，共 \(st.wk[mx]) 次。")
        }
        // 习惯变动：新增、删除、恢复，写上名字和日期
        let evText: (String, String) -> String? = { type, verb in
            let L = st.evs.filter { $0.type == type }.sorted { $0.date < $1.date }
            guard !L.isEmpty else { return nil }
            return verb + L.prefix(4).map { "「\($0.name)」（\(DK.md($0.date))）" }.joined(separator: "、") + (L.count > 4 ? " 等 \(L.count) 个" : "")
        }
        let evParts = [evText("add", "新增了习惯 "), evText("restore", "恢复了 "), evText("del", "删除了 ")].compactMap { $0 }
        if !evParts.isEmpty { p.append("这周" + evParts.joined(separator: "；") + "。") }
        var ex: [String] = []
        if st.jn > 0 { ex.append("\(st.jn) 篇笔记") }
        if st.notes > 0 { ex.append("\(st.notes) 条打卡日志") }
        if !ex.isEmpty { p.append("还写了 " + ex.joined(separator: "、") + "。") }
        let cheer = Theme.cheer[Int(Self.hashN(st.label + md(st.start)) % UInt32(Theme.cheer.count))]
        return AISum(paras: p, cheer: cheer, at: DK.nowMs, local: true, sig: "\(st.checks)|\(st.notes)|\(st.evs.count)",
                     stat: SumStat(rate: st.rate, checks: st.checks, days: st.days))
    }

    // MARK: 周总结（本机统计，不联网）

    func weekSummary(_ off: Int) -> SummaryEntry {
        let st = periodStats(.week, off), pv = periodStats(.week, off - 1)
        let rated = st.perCard.filter { $0.slots > 0 }
        let best = rated.max { ($0.rate ?? 0) < ($1.rate ?? 0) }
        let low = rated.min { ($0.rate ?? 0) < ($1.rate ?? 0) }
        var p: [String] = []
        let dr = st.rate - pv.rate
        var first = "\(DK.md(DK.key(st.start)))–\(DK.md(DK.key(st.end))) 这一周你打卡 \(st.checks) 次，有 \(st.days) 天打了卡，完成率 \(st.rate)%"
        if pv.slots > 0 { first += dr > 0 ? "，比前一周高 \(dr) 个百分点" : dr < 0 ? "，比前一周低 \(-dr) 个百分点" : "，和前一周持平" }
        p.append(first + "。")
        if let best, (best.rate ?? 0) > 0 {
            var t = "最稳的习惯：「\(best.card.name)」\(best.done)/\(best.slots) 天，完成率 \(best.rate ?? 0)%。"
            if let low, low.card.id != best.card.id { t += "最需要加把劲：「\(low.card.name)」\(low.done)/\(low.slots) 天，完成率 \(low.rate ?? 0)%。" }
            p.append(t)
        }
        if st.checks > 0, let mx = st.wk.indices.max(by: { st.wk[$0] < st.wk[$1] }) {
            p.append("打卡最多的一天是周\(DK.wdName[mx])，共 \(st.wk[mx]) 次。")
        }
        var ex: [String] = []
        if !st.evs.isEmpty { ex.append("\(st.evs.count) 个习惯变动") }
        if st.jn > 0 { ex.append("\(st.jn) 篇笔记") }
        if st.notes > 0 { ex.append("\(st.notes) 条打卡日志") }
        if !ex.isEmpty { p.append("这周还有 " + ex.joined(separator: "、") + "。") }
        let seed = DK.key(st.start).unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let cheer = Theme.cheer[seed % Theme.cheer.count]
        return SummaryEntry(paras: p, cheer: cheer, at: DK.nowMs, rate: st.rate, checks: st.checks, days: st.days)
    }

    func daysLabel(_ c: Card) -> String {
        let d = Set(c.days)
        if d.count == 7 { return "每天" }
        if d == Set([1, 2, 3, 4, 5]) { return "工作日" }
        if d == Set([0, 6]) { return "周末" }
        let order = [1, 2, 3, 4, 5, 6, 0]
        return "周" + order.filter { d.contains($0) }.map { DK.wdName[$0] }.joined()
    }
}
