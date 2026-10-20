import AppIntents
import WidgetKit

/// 小组件上点习惯图标直接打卡 / 取消打卡（iOS 17 起支持）
struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "打卡"
    static var description = IntentDescription("完成或取消今天的一个习惯")
    static var isDiscoverable: Bool = false

    @Parameter(title: "习惯")
    var cardId: String

    init() {}
    init(cardId: String) { self.cardId = cardId }

    func perform() async throws -> some IntentResult {
        // 直接改原始 JSON，网页版特有的字段不会丢
        guard let data = try? Data(contentsOf: Persistence.file),
              var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return .result() }
        let k = DK.today
        var records = root["records"] as? [String: Any] ?? [:]
        var day = records[k] as? [String: Any] ?? [:]
        var r = day[cardId] as? [String: Any] ?? [:]
        let was = (r["checked"] as? Bool) ?? ((r["checked"] as? Int).map { $0 != 0 } ?? false)
        r["checked"] = !was
        if !was {
            r["t"] = DK.nowMs
            r["plan"] = false
            let ever = records.values.contains { (($0 as? [String: Any])?[cardId] as? [String: Any])?["checked"] as? Bool == true }
            if !ever, let cards = root["cards"] as? [[String: Any]], let c = cards.first(where: { $0["id"] as? String == cardId }) {
                var evs = root["events"] as? [[String: Any]] ?? []
                evs.append(["type": "first", "id": cardId, "name": c["name"] as? String ?? "", "date": k, "ts": DK.nowMs])
                root["events"] = evs
            }
        }
        day[cardId] = r
        records[k] = day
        root["records"] = records
        if let out = try? JSONSerialization.data(withJSONObject: root) {
            try? out.write(to: Persistence.file, options: [.atomic])
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
