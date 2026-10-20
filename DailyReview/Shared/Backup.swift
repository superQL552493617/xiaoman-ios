import Foundation

enum BackupError: LocalizedError {
    case notJSON, notOurs
    var errorDescription: String? {
        switch self {
        case .notJSON: return "内容格式不对，请使用完整的备份文件"
        case .notOurs: return "这不是每日复盘的备份内容"
        }
    }
}

enum Backup {
    /// 完整备份（JSON），格式和网页原型兼容
    static func encode(_ s: AppState) throws -> Data {
        var s = s
        s.exportedAt = ISO8601DateFormatter().string(from: Date())
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(s)
    }

    /// 按唯一编号合并：已有的习惯、记录、笔记保持不变，只补上缺少的
    static func merge(into S: inout AppState, data: Data) throws -> (cards: Int, records: Int, notes: Int) {
        guard let obj = try? JSONSerialization.jsonObject(with: data), let dict = obj as? [String: Any] else { throw BackupError.notJSON }
        if (dict["app"] as? String) != "daily-review" && dict["cards"] == nil { throw BackupError.notOurs }
        let d = try JSONDecoder().decode(AppState.self, from: data)
        var nc = 0, nr = 0, nj = 0
        var known = Set(S.cards.map { $0.id } + S.archived.map { $0.id })
        for c in d.cards where !known.contains(c.id) { S.cards.append(c); known.insert(c.id); nc += 1 }
        for c in d.archived where !known.contains(c.id) { S.archived.append(c); known.insert(c.id) }
        for (k, day) in d.records where isKey(k) {
            var cur = S.records[k] ?? [:]
            for (id, inc) in day {
                if let old = cur[id] {
                    // 只替换「打开过但没打卡也没写日志」的空记录
                    if !old.checked && !old.hasNote && (inc.checked || inc.hasNote) { cur[id] = inc; nr += 1 }
                } else { cur[id] = inc; nr += 1 }
            }
            S.records[k] = cur
        }
        for (k, list) in d.journal where isKey(k) {
            var cur = S.journal[k] ?? []
            for e in list where !cur.contains(where: { $0.id == e.id }) { cur.append(e); nj += 1 }
            if !cur.isEmpty { S.journal[k] = cur }
        }
        for g in d.groups where !S.groups.contains(where: { $0.id == g.id }) { S.groups.append(g) }
        for (k, m) in d.mood where isKey(k) && S.mood[k] == nil && Mood.find(m) != nil { S.mood[k] = m }
        let sig: (EventItem) -> String = { "\($0.type)|\($0.id)|\($0.ts ?? 0)" }
        var seen = Set(S.events.map(sig))
        for e in d.events where !seen.contains(sig(e)) { S.events.append(e); seen.insert(sig(e)) }
        return (nc, nr, nj)
    }

    static func isKey(_ k: String) -> Bool {
        k.count == 10 && k.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }

    // MARK: CSV

    static func csv(_ rows: [[String]]) -> String {
        let body = rows.map { r in
            r.map { v -> String in
                if v.contains(",") || v.contains("\"") || v.contains("\n") { return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
                return v
            }.joined(separator: ",")
        }.joined(separator: "\n")
        return "\u{FEFF}" + body   // 加 BOM，Excel 打开中文不乱码
    }

    static func recordRows(_ S: AppState, from: String, to: String) -> [[String]] {
        var rows = [["日期", "星期", "习惯", "状态", "打卡时间", "打卡日志"]]
        for k in S.records.keys.filter({ $0 >= from && $0 <= to }).sorted(by: >) {
            for (id, r) in S.records[k] ?? [:] {
                guard let c = S.cardAny(id), r.checked || r.hasNote else { continue }
                rows.append([k, "周" + DK.wdName[DK.weekday(k)], c.name, c.isNote ? "记录" : (r.checked ? "已完成" : "未完成"), DK.hm(r.t), r.note ?? ""])
            }
        }
        return rows
    }

    static func noteRows(_ S: AppState, from: String, to: String) -> [[String]] {
        var rows = [["日期", "星期", "时间", "类型", "标题", "内容", "当天心情"]]
        for k in S.journal.keys.filter({ isKey($0) && $0 >= from && $0 <= to }).sorted(by: >) {
            let mood = S.moodOf(k)?.name ?? ""
            for e in S.journalList(k) {
                rows.append([k, "周" + DK.wdName[DK.weekday(k)], DK.hm(e.c), e.isReview ? "今日复盘" : "笔记", e.title, e.text, mood])
            }
        }
        return rows
    }

    static func cardRows(_ S: AppState) -> [[String]] {
        var rows = [["名称", "类型", "重复", "提醒", "状态", "累计打卡"]]
        let T = DK.today
        for (c, st) in S.cards.map({ ($0, "使用中") }) + S.archived.map({ ($0, "已删除") }) {
            let n = S.records.filter { $0.key <= T && $0.value[c.id]?.checked == true }.count
            let rem = (c.reminders ?? []).map { String(format: "%02d:%02d", $0.h, $0.m) }.joined(separator: " ")
            rows.append([c.name, c.isNote ? "记录卡片" : "打卡卡片", c.isNote ? "—" : S.daysLabel(c), rem, st, "\(n)"])
        }
        return rows
    }

    /// 写到临时文件，交给系统分享面板（存储到「文件」、AirDrop、微信…）
    static func tempFile(name: String, data: Data) -> URL? {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try data.write(to: u, options: [.atomic]); return u } catch { return nil }
    }
}
