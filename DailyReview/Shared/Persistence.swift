import Foundation

/// 数据文件放在 App 和小组件共用的位置（App Group），这样小组件也能读到、能直接打卡
enum Persistence {
    static let appGroup = "group.site.xiaomanhabit.app"

    static var folder: URL {
        if let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) { return u }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var file: URL { folder.appendingPathComponent("state.json") }

    static func load() -> AppState? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(AppState.self, from: data)
    }

    /// 原始 JSON 文字（网页版直接读写这一份）
    static func loadRaw() -> String? {
        guard let d = try? Data(contentsOf: file) else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func saveRaw(_ v: String) {
        guard let d = v.data(using: .utf8) else { return }
        try? d.write(to: file, options: [.atomic])
    }

    /// 原生版保存：只覆盖原生认识的字段，网页版特有的字段（卡片、设置里的其它内容）原样保留
    static func save(_ s: AppState) {
        guard let data = try? JSONEncoder().encode(s),
              var new = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        if let oldData = try? Data(contentsOf: file),
           let old = (try? JSONSerialization.jsonObject(with: oldData)) as? [String: Any] {
            var merged = old
            if let op = old["prefs"] as? [String: Any], let np = new["prefs"] as? [String: Any] {
                new["prefs"] = op.merging(np) { _, b in b }
            }
            for key in ["cards", "archived", "groups"] {
                guard let oc = old[key] as? [[String: Any]], let nc = new[key] as? [[String: Any]] else { continue }
                var byId: [String: [String: Any]] = [:]
                for c in oc { if let id = c["id"] as? String { byId[id] = c } }
                new[key] = nc.map { c in
                    guard let id = c["id"] as? String, let o = byId[id] else { return c }
                    return o.merging(c) { _, b in b }
                }
            }
            // 总结按期合并，网页版写的额外字段（第几版、自动生成等）不丢
            if let oc = old["aiCache"] as? [String: Any], let nc = new["aiCache"] as? [String: Any] {
                var m = oc
                for (k, v) in nc {
                    if let nv = v as? [String: Any], let ov = oc[k] as? [String: Any] { m[k] = ov.merging(nv) { _, b in b } } else { m[k] = v }
                }
                new["aiCache"] = m
            }
            for (k, v) in new { merged[k] = v }
            new = merged
        }
        guard let out = try? JSONSerialization.data(withJSONObject: new) else { return }
        try? out.write(to: file, options: [.atomic])
    }

    static var modified: Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate]) as? Date
    }

    /// 每天自动留一份快照到「文件」App 能看到的文稿目录，保留最近 7 份
    static func dailySnapshot(_ s: AppState) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("自动备份", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let f = docs.appendingPathComponent("小满-自动备份-\(DK.today).json")
        if FileManager.default.fileExists(atPath: f.path) { return }
        // 直接复制原始数据文件，网页版的全部字段都能保留
        if let raw = try? Data(contentsOf: file) { try? raw.write(to: f, options: [.atomic]) }
        else if let data = try? Backup.encode(s) { try? data.write(to: f, options: [.atomic]) }
        let all = ((try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in all.dropFirst(7) { try? FileManager.default.removeItem(at: old) }
    }
}

