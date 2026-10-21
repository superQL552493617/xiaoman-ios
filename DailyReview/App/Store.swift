import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class Store: ObservableObject {
    @Published var s: AppState { didSet { if oldValue.prefs.appFont != s.prefs.appFont { AppFont.current = s.prefs.appFont } } }
    @Published var vip = false
    private var saveTask: Task<Void, Never>?
    private var loadedAt = Date()

    init() {
        if let st = Persistence.load() {
            s = st
        } else {
            // 还没有数据：先用示例习惯显示，有修改时才写文件（网页版第一次打开会用它自己的示例数据）
            s = AppState.seeded()
        }
        if s.prefs.localId == nil { s.prefs.localId = "L" + String(UUID().uuidString.prefix(6)) }
        AppFont.current = s.prefs.appFont
        // 打卡图标默认改为圆形无边框（只改一次，之后按用户自己的选择）
        if !UserDefaults.standard.bool(forKey: "def258") {
            UserDefaults.standard.set(true, forKey: "def258")
            if s.prefs.line == "solid" { s.prefs.line = "none" }
        }
    }

    // MARK: 保存

    func save() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            self.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        Persistence.save(s)
        loadedAt = Date()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 从网页版切回来时，重新读取最新数据
    func reloadFromDisk() {
        if let st = Persistence.load() { s = st; loadedAt = Date() }
    }

    /// 回到前台时，如果小组件改过数据，就重新读一遍
    func reloadIfChanged() {
        if let m = Persistence.modified, m > loadedAt.addingTimeInterval(0.5), let st = Persistence.load() {
            s = st
            loadedAt = Date()
        }
    }

    // MARK: 打卡

    func toggle(_ id: String, on k: String) {
        var day = s.records[k] ?? [:]
        var r = day[id] ?? Rec()
        r.checked.toggle()
        if r.checked {
            r.t = DK.nowMs
            if !hasEverChecked(id), let c = s.card(id) { s.events.append(EventItem(type: "first", id: id, name: c.name)) }
        }
        day[id] = r
        s.records[k] = day
        save()
        // 今天打了卡：这张卡片今天剩下的闹钟不再响（取消打卡则补回来）
        if k == DK.today && !(s.card(id)?.reminders ?? []).isEmpty { Notifier.shared.rescheduleSoon(self) }
    }

    func setChecked(_ id: String, on k: String, _ v: Bool) {
        if s.isChecked(k, id) != v { toggle(id, on: k) }
    }

    private func hasEverChecked(_ id: String) -> Bool {
        s.records.values.contains { $0[id]?.checked == true }
    }

    func setNote(_ id: String, on k: String, _ text: String) {
        var day = s.records[k] ?? [:]
        var r = day[id] ?? Rec()
        let had = r.hasNote
        r.note = text.isEmpty ? nil : text
        if !had && r.hasNote, !s.events.contains(where: { $0.type == "note" && $0.id == id }), let c = s.cardAny(id) {
            s.events.append(EventItem(type: "note", id: id, name: c.name))
        }
        day[id] = r
        s.records[k] = day
        save()
        // 今天打了卡：这张卡片今天剩下的闹钟不再响（取消打卡则补回来）
        if k == DK.today && !(s.card(id)?.reminders ?? []).isEmpty { Notifier.shared.rescheduleSoon(self) }
    }

    // MARK: 卡片

    func upsert(_ c: Card) {
        if let i = s.cards.firstIndex(where: { $0.id == c.id }) {
            var new = c
            let old = s.cards[i]
            // 循环日改了：今天以前的日子仍按旧规则计算
            if Set(old.days) != Set(c.days) && !c.isNote {
                let T = DK.today
                var H = (old.daysHist ?? []).filter { $0.until < T }
                H.append(DaysHist(until: T, days: s.daysOn(old, DK.addKey(T, -1))))
                new.daysHist = H.sorted { $0.until < $1.until }
            }
            s.cards[i] = new
        } else {
            s.cards.append(c)
            if !c.isNote { s.events.append(EventItem(type: "add", id: c.id, name: c.name)) }
        }
        save()
        Notifier.shared.rescheduleAll(self)
    }

    /// 删除：卡片不再出现，以前的记录保留在统计里
    func archive(_ id: String) {
        guard let i = s.cards.firstIndex(where: { $0.id == id }) else { return }
        let c = s.cards.remove(at: i)
        s.archived.append(c)
        if !c.isNote { s.events.append(EventItem(type: "del", id: c.id, name: c.name)) }
        save()
        Notifier.shared.rescheduleAll(self)
    }

    func restore(_ id: String) {
        guard let i = s.archived.firstIndex(where: { $0.id == id }) else { return }
        let c = s.archived.remove(at: i)
        s.cards.append(c)
        s.events.append(EventItem(type: "restore", id: c.id, name: c.name))
        save()
    }

    /// 彻底删除：连同所有打卡记录和日志
    func deleteForever(_ id: String) {
        s.cards.removeAll { $0.id == id }
        s.archived.removeAll { $0.id == id }
        for k in s.records.keys {
            s.records[k]?.removeValue(forKey: id)
            if s.records[k]?.isEmpty == true { s.records.removeValue(forKey: k) }
        }
        save()
        Notifier.shared.rescheduleAll(self)
    }

    func move(_ id: String, before target: String?, group: String?) {
        guard let i = s.cards.firstIndex(where: { $0.id == id }) else { return }
        var c = s.cards.remove(at: i)
        c.group = group
        if let target, let j = s.cards.firstIndex(where: { $0.id == target }) {
            s.cards.insert(c, at: j)
        } else {
            // 放到这一组的最后
            if let last = s.cards.lastIndex(where: { ($0.group ?? "") == (group ?? "") }) { s.cards.insert(c, at: last + 1) }
            else { s.cards.append(c) }
        }
        save()
    }

    // MARK: 暂停

    /// rg.to 是最后一天（含），为空表示手动恢复
    func pause(_ id: String, from: String, to: String?) {
        guard let i = s.cards.firstIndex(where: { $0.id == id }) else { return }
        let T = DK.today
        let start = from > T ? from : T
        let until = to.map { DK.addKey($0, 1) }
        var P = (s.cards[i].pauses ?? []).filter { ($0.until ?? "9999") <= T }
        P.append(Pause(from: start, until: until))
        s.cards[i].pauses = P
        save()
        Notifier.shared.rescheduleAll(self)
    }

    func resume(_ id: String) {
        guard let i = s.cards.firstIndex(where: { $0.id == id }) else { return }
        let T = DK.today
        var P = (s.cards[i].pauses ?? []).filter { $0.from <= T }
        P = P.map { p in (p.until == nil || p.until! > T) ? Pause(from: p.from, until: T) : p }
        s.cards[i].pauses = P.isEmpty ? nil : P
        save()
        Notifier.shared.rescheduleAll(self)
    }

    // MARK: 分组

    func addGroup(_ name: String) -> HabitGroup {
        let g = HabitGroup(name: name)
        s.groups.append(g)
        save()
        return g
    }

    func renameGroup(_ id: String, _ name: String) {
        if let i = s.groups.firstIndex(where: { $0.id == id }) { s.groups[i].name = name; save() }
    }

    func deleteGroup(_ id: String) {
        s.groups.removeAll { $0.id == id }
        for i in s.cards.indices where s.cards[i].group == id { s.cards[i].group = nil }
        save()
    }

    /// 打卡页分组折叠（存在分组上，和网页版一致；"" 是未分组）
    func toggleGroupCollapsed(_ gid: String) {
        if gid.isEmpty {
            var u = s.ungrouped ?? HabitGroup(id: "", name: s.ungroupedName)
            u.collapsed = !(u.collapsed ?? false)
            s.ungrouped = u
        } else if let i = s.groups.firstIndex(where: { $0.id == gid }) {
            s.groups[i].collapsed = !(s.groups[i].collapsed ?? false)
        }
        save()
    }

    /// 分组上移 / 下移（只在有卡片的分组之间调整）
    func moveGroup(_ gid: String, by d: Int) {
        guard let i = s.groups.firstIndex(where: { $0.id == gid }) else { return }
        var j = i + d
        while j >= 0 && j < s.groups.count && !s.cards.contains(where: { $0.group == s.groups[j].id }) { j += d }
        guard j >= 0 && j < s.groups.count else { return }
        s.groups.swapAt(i, j)
        save()
    }

    func toggleCollapsed(_ gid: String) {
        if let i = s.prefs.collapsed.firstIndex(of: gid) { s.prefs.collapsed.remove(at: i) } else { s.prefs.collapsed.append(gid) }
        save()
    }

    // MARK: 笔记 / 心情 / 复盘

    func saveJournal(_ e: JournalEntry, on k: String) {
        var L = s.journal[k] ?? []
        var e = e
        e.t = DK.nowMs
        if let i = L.firstIndex(where: { $0.id == e.id }) { L[i] = e } else {
            L.append(e)
            if !e.isReview { s.events.append(EventItem(type: "jr", id: e.id, name: e.displayTitle, date: k)) }
        }
        s.journal[k] = L
        save()
    }

    func deleteJournal(_ id: String, on k: String) {
        s.journal[k]?.removeAll { $0.id == id }
        if s.journal[k]?.isEmpty == true { s.journal.removeValue(forKey: k) }
        save()
    }

    /// 把笔记换到另一天
    func moveJournal(_ e: JournalEntry, from: String, to: String) {
        guard from != to else { saveJournal(e, on: from); return }
        deleteJournal(e.id, on: from)
        var L = s.journal[to] ?? []
        L.append(e)
        s.journal[to] = L
        save()
    }

    func setMood(_ id: String?, on k: String) {
        if let id { s.mood[k] = id } else { s.mood.removeValue(forKey: k) }
        save()
    }

    // MARK: 设置

    func updatePrefs(_ f: (inout Prefs) -> Void) {
        f(&s.prefs)
        save()
    }

    // MARK: 导入备份

    @discardableResult
    func importBackup(_ data: Data) throws -> (cards: Int, records: Int, notes: Int) {
        let r = try Backup.merge(into: &s, data: data)
        saveNow()
        Notifier.shared.rescheduleAll(self)
        return r
    }
}
