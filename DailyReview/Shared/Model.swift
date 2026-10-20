import Foundation

// MARK: - 宽松解码：字段缺失或类型不对时用默认值，保证旧备份、原型备份都能导入

extension KeyedDecodingContainer {
    func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        guard let v = try? decodeIfPresent(type, forKey: key) else { return nil }
        return v
    }
    /// 数字可能被存成 Int / Double / String
    func number(_ key: Key) -> Double? {
        if let d = lenient(Double.self, key) { return d }
        if let i = lenient(Int.self, key) { return Double(i) }
        if let s = lenient(String.self, key) { return Double(s) }
        return nil
    }
    func bool(_ key: Key) -> Bool? {
        if let b = lenient(Bool.self, key) { return b }
        if let i = lenient(Int.self, key) { return i != 0 }
        return nil
    }
}

func newId(_ prefix: String = "c") -> String {
    prefix + "-" + String(UUID().uuidString.prefix(8)).lowercased()
}

// MARK: - 习惯卡片

struct Reminder: Codable, Hashable {
    var h: Int
    var m: Int
    /// 网页版的提醒设置：重复 daily / work / weekend / custom、具体周几、提示音、类型
    var repeatMode: String? = nil
    var days: [Int]? = nil
    var tone: Int? = nil
    var mode: String? = nil

    init(h: Int, m: Int, repeatMode: String? = "daily", days: [Int]? = [0, 1, 2, 3, 4, 5, 6], tone: Int? = 1) {
        self.h = h; self.m = m; self.repeatMode = repeatMode; self.days = days; self.tone = tone; self.mode = "strong"
    }

    enum CodingKeys: String, CodingKey { case h, m, repeatMode = "repeat", days, tone, mode }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        h = Int(c.number(.h) ?? 8); m = Int(c.number(.m) ?? 0)
        repeatMode = c.lenient(String.self, .repeatMode)
        days = c.lenient([Int].self, .days)
        tone = c.number(.tone).map { Int($0) }
        mode = c.lenient(String.self, .mode)
    }

    /// 提醒卡片上的简短说明：每天 / 工作日 / 周末 / 周一 周三…
    var repShort: String {
        let d = Set(days ?? [0, 1, 2, 3, 4, 5, 6])
        if d.count == 7 { return "每天" }
        if d == Set([1, 2, 3, 4, 5]) { return "工作日" }
        if d == Set([0, 6]) { return "周末" }
        return "周" + [1, 2, 3, 4, 5, 6, 0].filter { d.contains($0) }.map { DK.wdName[$0] }.joined()
    }
}

/// 暂停：from 当天起暂停，until 当天恢复（不含），until 为空表示手动恢复
struct Pause: Codable, Hashable {
    var from: String
    var until: String?
}

/// 修改「循环日」前的旧设置：until 之前的日子按 days 计算
struct DaysHist: Codable, Hashable {
    var until: String
    var days: [Int]
}

struct Card: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    /// "icon" 图标 / "text" 文字 / "img" 照片
    var ic: String
    var icon: String
    var text: String
    /// 照片图标（data URL 或 base64 JPEG）
    var icImg: String?
    var hex: String
    /// "check" 打卡卡片 / "note" 记录卡片
    var type: String
    var slot: String
    /// 0 = 周日 … 6 = 周六
    var days: [Int]
    var daysHist: [DaysHist]?
    var group: String?
    var reminders: [Reminder]?
    var pauses: [Pause]?
    var createdAt: String?
    var font: String?

    init(id: String = newId(), name: String, ic: String = "icon", icon: String = "1F33F", text: String = "",
         hex: String = "#7DBF8A", type: String = "check", slot: String = "全天", days: [Int] = [1, 2, 3, 4, 5, 6, 0],
         group: String? = nil, createdAt: String? = DK.today, font: String? = "sys") {
        self.id = id; self.name = name; self.ic = ic; self.icon = icon; self.text = text
        self.icImg = nil; self.hex = hex; self.type = type; self.slot = slot; self.days = days
        self.daysHist = nil; self.group = group; self.reminders = nil; self.pauses = nil
        self.createdAt = createdAt; self.font = font
    }

    enum CodingKeys: String, CodingKey {
        case id, name, ic, icon, text, icImg, hex, type, slot, days, daysHist, group, reminders, pauses, createdAt, font
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenient(String.self, .id) ?? newId()
        name = c.lenient(String.self, .name) ?? "未命名"
        ic = c.lenient(String.self, .ic) ?? "icon"
        icon = c.lenient(String.self, .icon) ?? "1F33F"
        text = c.lenient(String.self, .text) ?? ""
        icImg = c.lenient(String.self, .icImg)
        hex = c.lenient(String.self, .hex) ?? "#7DBF8A"
        type = (c.lenient(String.self, .type) == "note") ? "note" : "check"
        slot = c.lenient(String.self, .slot) ?? "全天"
        days = c.lenient([Int].self, .days) ?? [1, 2, 3, 4, 5, 6, 0]
        daysHist = c.lenient([DaysHist].self, .daysHist)
        group = c.lenient(String.self, .group)
        reminders = c.lenient([Reminder].self, .reminders)
        pauses = c.lenient([Pause].self, .pauses)
        createdAt = c.lenient(String.self, .createdAt)
        font = c.lenient(String.self, .font)
    }

    var isNote: Bool { type == "note" }
    var colors: CardColors { CardColors(hex: hex) }
}

// MARK: - 打卡记录

struct Rec: Codable, Hashable {
    var checked: Bool
    /// 打卡时间（毫秒时间戳，和原型一致）
    var t: Double?
    var note: String?
    var plan: Bool?

    init(checked: Bool = false, t: Double? = nil, note: String? = nil) {
        self.checked = checked; self.t = t; self.note = note; self.plan = nil
    }

    enum CodingKeys: String, CodingKey { case checked, t, note, plan }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        checked = c.bool(.checked) ?? false
        t = c.number(.t)
        note = c.lenient(String.self, .note)
        plan = c.bool(.plan)
    }

    var hasNote: Bool { !(note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - 笔记

struct JournalEntry: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var text: String
    /// 创建时间（毫秒）
    var c: Double
    /// 修改时间（毫秒）
    var t: Double?
    /// nil 普通笔记 / "review" 今日复盘
    var kind: String?
    var ans: [String: String]?
    var font: String?
    var bg: String?

    init(id: String = newId("j"), title: String = "", text: String = "", c: Double = DK.nowMs, kind: String? = nil) {
        self.id = id; self.title = title; self.text = text; self.c = c; self.t = c; self.kind = kind
        self.ans = nil; self.font = nil; self.bg = nil
    }

    enum CodingKeys: String, CodingKey { case id, title, text, c, t, kind, ans, font, bg }

    init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        id = k.lenient(String.self, .id) ?? newId("j")
        title = k.lenient(String.self, .title) ?? ""
        text = k.lenient(String.self, .text) ?? ""
        c = k.number(.c) ?? DK.nowMs
        t = k.number(.t)
        kind = k.lenient(String.self, .kind)
        ans = k.lenient([String: String].self, .ans)
        font = k.lenient(String.self, .font)
        bg = k.lenient(String.self, .bg)
    }

    var isReview: Bool { kind == "review" }

    /// 没写标题时，用正文开头几个字当标题
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty { return "无标题笔记" }
        let firstLine = body.components(separatedBy: .newlines).first ?? body
        return String(firstLine.prefix(16))
    }
}

// MARK: - 分组、事件

struct HabitGroup: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    /// 打卡页上折叠（和网页版一样存在分组上）
    var collapsed: Bool?

    init(id: String = newId("g"), name: String) { self.id = id; self.name = name; self.collapsed = nil }

    enum CodingKeys: String, CodingKey { case id, name, collapsed }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenient(String.self, .id) ?? newId("g")
        name = c.lenient(String.self, .name) ?? "未命名"
        collapsed = c.bool(.collapsed)
    }
}

struct EventItem: Codable, Hashable {
    /// add / del / restore / first / note / jr
    var type: String
    var id: String
    var name: String
    var date: String
    var ts: Double?

    init(type: String, id: String, name: String, date: String = DK.today, ts: Double? = DK.nowMs) {
        self.type = type; self.id = id; self.name = name; self.date = date; self.ts = ts
    }

    enum CodingKeys: String, CodingKey { case type, id, name, date, ts }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.lenient(String.self, .type) ?? "add"
        id = c.lenient(String.self, .id) ?? ""
        name = c.lenient(String.self, .name) ?? ""
        date = c.lenient(String.self, .date) ?? DK.today
        ts = c.number(.ts)
    }

    var text: String {
        switch type {
        case "del": return "删除了习惯「\(name)」"
        case "restore": return "恢复了习惯「\(name)」"
        case "first": return "第一次完成「\(name)」"
        case "note": return "第一次给「\(name)」写日志"
        case "jr": return "写了笔记「\(name)」"
        default: return "新增了习惯「\(name)」"
        }
    }
}

// MARK: - 设置

struct HomePrefs: Codable, Hashable {
    var quick = true, jr = true, prog = true, cheer = true, strip = true

    init() {}
    enum CodingKeys: String, CodingKey { case quick, jr, prog, cheer, strip }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        quick = c.bool(.quick) ?? true
        jr = c.bool(.jr) ?? true
        prog = c.bool(.prog) ?? true
        cheer = c.bool(.cheer) ?? true
        strip = c.bool(.strip) ?? true
    }
}

struct DailyReminder: Codable, Hashable {
    var on = false
    var h = 21
    var m = 0
    init() {}
    enum CodingKeys: String, CodingKey { case on, h, m }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        on = c.bool(.on) ?? false
        h = Int(c.number(.h) ?? 21)
        m = Int(c.number(.m) ?? 0)
    }
}

struct ModulePref: Codable, Hashable {
    var id: String
    var on: Bool
}

/// 桌面小组件设置（和网页版 prefs.widget 一样）
struct WidgetPrefs: Codable, Hashable {
    var tap = true
    var bg = "default"
    var custom = "#E8F0FF"
    init() {}
    enum CodingKeys: String, CodingKey { case tap, bg, custom }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tap = c.bool(.tap) ?? true
        bg = c.lenient(String.self, .bg) ?? "default"
        custom = c.lenient(String.self, .custom) ?? "#E8F0FF"
    }
    static let bgs: [(id: String, name: String, hex: String)] = [
        ("default", "默认", ""), ("cream", "米白", "#FBF7EE"), ("blue", "淡蓝", "#EDF3FF"), ("green", "淡绿", "#EAF7EF"),
        ("pink", "淡粉", "#FFEEF3"), ("purple", "淡紫", "#F3EEFF"), ("yellow", "淡黄", "#FFF9E3"), ("grey", "浅灰", "#F1F1F4")
    ]
    /// nil = 默认（白色 / 深色模式下深灰）
    var bgHex: String? { bg == "custom" ? custom : Self.bgs.first { $0.id == bg }.flatMap { $0.hex.isEmpty ? nil : $0.hex } }
}

/// 网页版自己做的配色板
struct MyPalette: Codable, Hashable {
    var id: String
    var n: String
    var c: [String]
}

struct Prefs: Codable, Hashable {
    var nick = "我"
    var bio = ""
    /// "f" / "m"
    var gender = "f"
    /// 头像（JPEG 的 base64）
    var avatar: String?
    /// 1 = 周一开始，0 = 周日开始
    var weekStart = 1
    var flat = false
    var home = HomePrefs()
    var quickItems: [String: Bool] = [:]
    var dateColor = "green"
    /// "system" / "light" / "dark"
    var mode = "system"
    /// "loose" 每行 3 个 / "dense" 4 个 / "compact" 5 个
    var layout = "loose"
    /// "circle" / "square"
    var shape = "circle"
    var sound = true
    var haptic = true
    var daily = DailyReminder()
    var modules: [ModulePref]?
    var localId: String?
    var tabLabel = false
    var lockOn = false
    var aiLogs = false
    var collapsed: [String] = []
    /// 底部栏大小 s / m / l
    var tabSize = "m"
    /// 卡片边框 solid / dash / dot / none
    var line = "solid"
    /// 笔记区折叠
    var jrFold = false
    /// 不分组时的卡片顺序
    var flatOrder: [String]?
    /// 底部栏中间三个位置（bars / ai / memory / journal / none）
    var tabs: [String]?
    /// 页面背景主题、自定义背景图（base64）
    var pageBg = "white"
    var bgImg: String?
    /// App 字体 sys / round
    var appFont = "sys"
    /// 配色板，以及换色前每张卡片自己的颜色
    var palette: String?
    var ownHex: [String: String]?
    /// 完成 / 撤销音效编号
    var sndIn: Int?
    var sndOut: Int?
    var noBadge = false
    var widget: WidgetPrefs?
    var myPal: [MyPalette]?
    /// 笔记编辑页的字体 sys / round / kai、纸张颜色 white / cream / mint / sky（和网页版同名字段）
    var noteFont: String?
    var noteBg: String?

    init() {}

    enum CodingKeys: String, CodingKey {
        case nick, bio, gender, avatar, weekStart, flat, home, quickItems, dateColor, mode, layout, shape, sound, haptic, daily, modules, localId, tabLabel, lockOn, aiLogs, collapsed, tabSize, line, jrFold, flatOrder, tabs, pageBg, bgImg, appFont, palette, ownHex, sndIn, sndOut, noBadge, widget, myPal, noteFont, noteBg
    }
    /// 网页版的每日提醒字段
    private enum ProtoKeys: String, CodingKey { case remind, time }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nick = c.lenient(String.self, .nick) ?? "我"
        bio = c.lenient(String.self, .bio) ?? ""
        gender = c.lenient(String.self, .gender) == "m" ? "m" : "f"
        avatar = c.lenient(String.self, .avatar)
        weekStart = Int(c.number(.weekStart) ?? 1) == 0 ? 0 : 1
        flat = c.bool(.flat) ?? false
        home = c.lenient(HomePrefs.self, .home) ?? HomePrefs()
        quickItems = c.lenient([String: Bool].self, .quickItems) ?? [:]
        dateColor = c.lenient(String.self, .dateColor) ?? "green"
        mode = c.lenient(String.self, .mode) ?? "system"
        layout = c.lenient(String.self, .layout) ?? "loose"
        shape = c.lenient(String.self, .shape) ?? "circle"
        sound = c.bool(.sound) ?? true
        haptic = c.bool(.haptic) ?? true
        if let d = c.lenient(DailyReminder.self, .daily) {
            daily = d
        } else if let pk = try? decoder.container(keyedBy: ProtoKeys.self) {
            var d = DailyReminder()
            d.on = pk.bool(.remind) ?? false
            if let t = pk.lenient(String.self, .time) {
                let parts = t.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2 { d.h = parts[0]; d.m = parts[1] }
            }
            daily = d
        } else { daily = DailyReminder() }
        modules = c.lenient([ModulePref].self, .modules)
        localId = c.lenient(String.self, .localId)
        tabLabel = c.bool(.tabLabel) ?? false
        lockOn = c.bool(.lockOn) ?? false
        aiLogs = c.bool(.aiLogs) ?? false
        collapsed = c.lenient([String].self, .collapsed) ?? []
        tabSize = c.lenient(String.self, .tabSize) ?? "m"
        line = c.lenient(String.self, .line) ?? "solid"
        jrFold = c.bool(.jrFold) ?? false
        flatOrder = c.lenient([String].self, .flatOrder)
        tabs = c.lenient([String].self, .tabs)
        pageBg = c.lenient(String.self, .pageBg) ?? "white"
        bgImg = c.lenient(String.self, .bgImg)
        appFont = c.lenient(String.self, .appFont) ?? "sys"
        palette = c.lenient(String.self, .palette)
        ownHex = c.lenient([String: String].self, .ownHex)
        sndIn = c.number(.sndIn).map { Int($0) }
        sndOut = c.number(.sndOut).map { Int($0) }
        noBadge = c.bool(.noBadge) ?? false
        widget = c.lenient(WidgetPrefs.self, .widget)
        myPal = c.lenient([MyPalette].self, .myPal)
        noteFont = c.lenient(String.self, .noteFont)
        noteBg = c.lenient(String.self, .noteBg)
    }

    /// 底部栏中间三格（和网页版 tabSlots 一样）
    var tabSlots: [String] {
        let pick = ["bars", "ai", "memory", "journal", "none"]
        let v = tabs ?? ["bars", "none", "ai"]
        return (0..<3).map { i in i < v.count && pick.contains(v[i]) ? v[i] : "none" }
    }

    func quickOn(_ id: String) -> Bool { quickItems[id] ?? true }
}

// MARK: - 周总结（本机计算）

struct SummaryEntry: Codable, Hashable {
    var paras: [String]
    var cheer: String
    var at: Double
    var rate: Int
    var checks: Int
    var days: Int
}

/// 网页版 aiCache 里的一份总结（键是 "week|2026-10-12" 这样的格式，两边共用）
struct SumStat: Codable, Hashable {
    var rate: Int
    var checks: Int
    var days: Int
    init(rate: Int, checks: Int, days: Int) { self.rate = rate; self.checks = checks; self.days = days }
    enum CodingKeys: String, CodingKey { case rate, checks, days }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rate = Int(c.number(.rate) ?? 0); checks = Int(c.number(.checks) ?? 0); days = Int(c.number(.days) ?? 0)
    }
}

struct AISum: Codable, Hashable {
    var paras: [String]
    var cheer: String
    var at: Double?
    var local: Bool?
    var sig: String?
    var stat: SumStat?
    var n: Int?
    var auto: Bool?

    init(paras: [String], cheer: String, at: Double?, local: Bool?, sig: String?, stat: SumStat?) {
        self.paras = paras; self.cheer = cheer; self.at = at; self.local = local; self.sig = sig; self.stat = stat
    }
    enum CodingKeys: String, CodingKey { case paras, cheer, at, local, sig, stat, n, auto }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paras = c.lenient([String].self, .paras) ?? []
        cheer = c.lenient(String.self, .cheer) ?? ""
        at = c.number(.at)
        local = c.bool(.local)
        sig = c.lenient(String.self, .sig)
        stat = c.lenient(SumStat.self, .stat)
        n = c.number(.n).map { Int($0) }
        auto = c.bool(.auto)
    }
}

struct AILast: Codable, Hashable {
    var key: String
    var label: String
}

// MARK: - 全部数据

struct AppState: Codable {
    var app = "daily-review"
    var version = 3
    var cards: [Card] = []
    var archived: [Card] = []
    /// records[日期][卡片 id]
    var records: [String: [String: Rec]] = [:]
    /// journal[日期] = 当天的笔记
    var journal: [String: [JournalEntry]] = [:]
    var groups: [HabitGroup] = []
    var ungroupedName = "未分组"
    /// 网页版的「未分组」（名字、折叠状态）
    var ungrouped: HabitGroup?
    var mood: [String: String] = [:]
    var events: [EventItem] = []
    var prefs = Prefs()
    var lastBackup: String?
    var summaries: [String: SummaryEntry] = [:]
    /// 打卡总结（和网页版共用同一份）
    var aiCache: [String: AISum] = [:]
    var aiLast: AILast?
    var exportedAt: String?

    init() {}

    enum CodingKeys: String, CodingKey {
        case app, version, cards, archived, records, journal, groups, ungroupedName, ungrouped, mood, events, prefs, lastBackup, summaries, aiCache, aiLast, exportedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = c.lenient(String.self, .app) ?? "daily-review"
        version = Int(c.number(.version) ?? 3)
        cards = c.lenient([Card].self, .cards) ?? []
        archived = c.lenient([Card].self, .archived) ?? []
        records = c.lenient([String: [String: Rec]].self, .records) ?? [:]
        journal = c.lenient([String: [JournalEntry]].self, .journal) ?? [:]
        groups = c.lenient([HabitGroup].self, .groups) ?? []
        ungrouped = c.lenient(HabitGroup.self, .ungrouped)
        ungroupedName = c.lenient(String.self, .ungroupedName) ?? ungrouped?.name ?? "未分组"
        mood = c.lenient([String: String].self, .mood) ?? [:]
        events = c.lenient([EventItem].self, .events) ?? []
        prefs = c.lenient(Prefs.self, .prefs) ?? Prefs()
        lastBackup = c.lenient(String.self, .lastBackup)
        summaries = c.lenient([String: SummaryEntry].self, .summaries) ?? [:]
        aiCache = c.lenient([String: AISum].self, .aiCache) ?? [:]
        aiLast = c.lenient(AILast.self, .aiLast)
        // 旧版原生界面存在 summaries 里的周总结，搬到 aiCache
        for (k, e) in summaries where k.hasPrefix("w-") {
            let key = "week|" + k.dropFirst(2)
            if aiCache[key] == nil {
                aiCache[key] = AISum(paras: e.paras, cheer: e.cheer, at: e.at, local: true, sig: nil, stat: SumStat(rate: e.rate, checks: e.checks, days: e.days))
            }
        }
        exportedAt = c.lenient(String.self, .exportedAt)
    }

    /// 第一次打开时的示例习惯（和原型一致）
    static func seeded() -> AppState {
        var s = AppState()
        let g1 = HabitGroup(id: "g-study", name: "学习成长"), g2 = HabitGroup(id: "g-life", name: "生活日常")
        s.groups = [g1, g2]
        s.cards = [
            Card(id: "sys-en", name: "学英语", ic: "text", icon: "1F524", text: "Ab", hex: "#3D8FE0", slot: "晨间", group: g1.id, font: "round"),
            Card(id: "sys-skill", name: "新技能", icon: "1F9E0", hex: "#F5C542", group: g1.id),
            Card(id: "sys-read", name: "读书", icon: "1F4DA", hex: "#F29D38", slot: "睡前", group: g1.id),
            Card(id: "sys-room", name: "整理房间", icon: "1F9F9", hex: "#50A8B0", slot: "晚间", group: g2.id),
            Card(id: "sys-gain", name: "其他收获", icon: "1F33F", hex: "#7DBF8A", slot: "睡前", group: g2.id),
            Card(id: "sys-happy", name: "值得开心的事", icon: "1F308", hex: "#F3A6B8", slot: "睡前", group: g2.id, font: "kai")
        ]
        s.prefs.localId = "L" + String(UUID().uuidString.prefix(6))
        return s
    }
}
