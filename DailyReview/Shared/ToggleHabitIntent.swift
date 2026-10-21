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

/// 小组件里没打卡的习惯放不下时，点右上角的「›」翻到下一页（小组件本身不能滑动）
struct WidgetNextPageIntent: AppIntent {
    static var title: LocalizedStringResource = "下一页"
    static var description = IntentDescription("显示小组件里的下一组习惯")
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        let d = UserDefaults(suiteName: Persistence.appGroup)
        d?.set((d?.integer(forKey: "widgetPage") ?? 0) + 1, forKey: "widgetPage")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 页面主题在小组件上的底色（和「个性化 → 主题」一致；深色模式下统一用深灰）
enum ThemeFill {
    static func colors(_ id: String) -> (top: String, base: String) {
        switch id {
        case "cream": return ("#FAF7F0", "#FAF7F0")
        case "mist": return ("#F3F4F6", "#F3F4F6")
        case "sky": return ("#E6F0FC", "#F2F7FD")
        case "sage": return ("#E5F1E6", "#F3F8F3")
        case "peach": return ("#FBE9DA", "#FDF6F0")
        case "dots": return ("#FBFBFA", "#FBFBFA")
        case "grid": return ("#FCFCFA", "#FCFCFA")
        case "dream": return ("#E9DED2", "#DCE9EE")
        case "fog": return ("#FBF8F2", "#F6EBDD")
        case "beach": return ("#F8F7F2", "#EEF1EA")
        case "plaid": return ("#FAFCFE", "#EEF4FA")
        case "forest": return ("#F7F7F2", "#ECF0E6")
        default: return ("#FFFFFF", "#FFFFFF")
        }
    }
}
