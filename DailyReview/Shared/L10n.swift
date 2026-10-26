import Foundation

/// 原生部分（开屏、提醒通知、小组件、系统弹窗、隐私政策等）的多语言。
/// 语言跟网页里的「语言」设置一致（数据文件里的 prefs.lang）：auto 跟随系统，zh-Hans / zh-Hant / en。
/// 词典：简体原文 → [英文, 繁体]，繁体由 OpenCC（台湾用语）转换生成。
enum L10n {
    private static var cached: (String, Date)?
    /// 当前语言：zh-Hans / zh-Hant / en
    static var lang: String {
        if let c = cached, Date().timeIntervalSince(c.1) < 2 { return c.0 }
        var pref = "auto"
        if let d = try? Data(contentsOf: Persistence.file),
           let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
           let p = j["prefs"] as? [String: Any], let l = p["lang"] as? String { pref = l }
        let r = resolve(pref)
        cached = (r, Date())
        return r
    }
    /// 数据文件里存的语言设置（auto / zh-Hans / zh-Hant / en），注入给网页
    static var pref: String {
        guard let d = try? Data(contentsOf: Persistence.file),
              let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let p = j["prefs"] as? [String: Any], let l = p["lang"] as? String,
              ["auto", "zh-Hans", "zh-Hant", "en"].contains(l) else { return "auto" }
        return l
    }
    static func resolve(_ pref: String) -> String {
        if pref == "zh-Hans" || pref == "zh-Hant" || pref == "en" { return pref }
        let l = (Locale.preferredLanguages.first ?? "zh-Hans").lowercased()
        if l.hasPrefix("zh") { return (l.contains("hant") || l.contains("-tw") || l.contains("-hk") || l.contains("-mo")) ? "zh-Hant" : "zh-Hans" }
        return "en"
    }
    /// 用户刚在网页里换了语言
    static func reset() { cached = nil }

    static func t(_ zh: String) -> String {
        let l = lang
        if l == "zh-Hans" { return zh }
        guard let v = dict[zh] else { return zh }
        return l == "en" ? v[0] : v[1]
    }

    static let monthsEN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    static let weekdaysEN = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    /// 10月26日 周一 / 10月26日 週一 / Mon, Oct 26（weekday: 0 = 周日）
    static func monthDayWeek(_ m: Int, _ d: Int, _ weekday: Int) -> String {
        let cn = ["日", "一", "二", "三", "四", "五", "六"][max(0, min(6, weekday))]
        switch lang {
        case "en": return "\(weekdaysEN[max(0, min(6, weekday))]), \(monthsEN[max(0, min(11, m - 1))]) \(d)"
        case "zh-Hant": return "\(m)月\(d)日 週\(cn)"
        default: return "\(m)月\(d)日 周\(cn)"
        }
    }
    /// 2026年10月26日 / Oct 26, 2026
    static func ymd(_ y: Int, _ m: Int, _ d: Int) -> String {
        lang == "en" ? "\(monthsEN[max(0, min(11, m - 1))]) \(d), \(y)" : "\(y)年\(m)月\(d)日"
    }

    static let dict: [String: [String]] = [
        "每天一点点，日子就慢慢满了。": ["A little every day, and life slowly fills up.", "每天一點點，日子就慢慢滿了。"],
        "小满记 · 记下每一点小小的满足": ["XIAOMAN · NOTE EVERY LITTLE JOY", "小滿記 · 記下每一點小小的滿足"],
        "意见反馈": ["Feedback", "意見反饋"],
        "完成": ["Done", "完成"],
        "隐私政策": ["Privacy Policy", "隱私政策"],
        "致谢与版权": ["Credits", "致謝與版權"],
        "用户协议": ["Terms of Use", "使用者協議"],
        "关闭": ["Close", "關閉"],
        "解锁小满": ["Unlock Xiaoman", "解鎖小滿"],
        "好的": ["OK", "好的"],
        "取消": ["Cancel", "取消"],
        "确定": ["OK", "確定"],
        "小满记": ["Xiaoman", "小滿記"],
        "小满": ["Xiaoman", "小滿"],
        "花一分钟，记录一下今天吧": ["Take a minute to note down your day", "花一分鐘，記錄一下今天吧"],
        "稍后提醒：到时间啦，做完记得打个卡": ["Snoozed: time’s up, remember to check in when you’re done", "稍後提醒：到時間啦，做完記得打個卡"],
        "到时间啦，做完记得打个卡": ["Time’s up. Remember to check in when you’re done", "到時間啦，做完記得打個卡"],
        "还没打卡哦 · 第 %d 次提醒": ["Not checked in yet · Reminder #%d", "還沒打卡哦 · 第 %d 次提醒"],
        "（今天最后一次）": [" (last one today)", "（今天最後一次）"],
        "面容 ID": ["Face ID", "Face ID"],
        "触控 ID": ["Touch ID", "Touch ID"],
        "设备密码": ["Passcode", "裝置密碼"],
        "去打卡": ["Check in", "去打卡"],
        "10 分钟后提醒": ["Remind in 10 min", "10 分鐘後提醒"],
        "10 分钟后再提醒": ["Remind me in 10 minutes", "10 分鐘後再提醒"],
        "试响": ["Test", "試響"],
        " · 试响": [" · Test", " · 試響"],
        " · 稍后提醒 · 第 %d 次": [" · Snoozed · #%d", " · 稍後提醒 · 第 %d 次"],
        " · 稍后提醒": [" · Snoozed", " · 稍後提醒"],
        " · 第 %d 次提醒": [" · Reminder #%d", " · 第 %d 次提醒"],
        "今日打卡": ["Today", "今日打卡"],
        "今天没有需要打卡的习惯": ["Nothing to check in today", "今天沒有需要打卡的習慣"],
        "显示今天还没打卡的习惯，点图标直接打卡，打完的自动消失。": ["Shows today’s unchecked habits. Tap an icon to check in; finished ones disappear.", "顯示今天還沒打卡的習慣，點圖示直接打卡，打完的自動消失。"],
        "笔记": ["Notes", "筆記"],
        "点一下直接写今天的笔记，桌面上不会显示笔记内容。": ["Tap to write today’s note. Note content isn’t shown on the Home Screen.", "點一下直接寫今天的筆記，桌面上不會顯示筆記內容。"],
        "记录一下今天的自己": ["Write down today’s you", "記錄一下今天的自己"],
        "不管好坏，都是生活的一部分。": ["Good or bad, it’s all part of life.", "不管好壞，都是生活的一部分。"],
        "全部打卡完成": ["All checked in", "全部打卡完成"],
        "今天的你，很棒。": ["You did great today.", "今天的你，很棒。"],
        "今日份坚持，已收下": ["Today’s effort, received", "今日份堅持，已收下"],
        "一点一点，都在长大。": ["Little by little, you’re growing.", "一點一點，都在長大。"],
        "今天的小目标，都达成了": ["Today’s small goals, all done", "今天的小目標，都達成了"],
        "好好休息一下吧。": ["Get some good rest.", "好好休息一下吧。"],
        "完美收工": ["All wrapped up", "完美收工"],
        "明天也一起加油。": ["Let’s keep going tomorrow.", "明天也一起加油。"],
        "小满打卡": ["Xiaoman check-in", "小滿打卡"],
        "打开小满记，记录今天的打卡": ["Open Xiaoman to record today’s check-ins", "開啟小滿記，記錄今天的打卡"],
        "写笔记": ["Write a note", "寫筆記"],
        "今天 %d 篇": ["%d today", "今天 %d 篇"],
        "暂时连不上 App Store，请检查网络后再试": ["Can’t reach the App Store; please check your network and try again", "暫時連不上 App Store，請檢查網路後再試"],
        "开通成功，谢谢你的支持": ["You’re all set. Thanks for your support", "開通成功，謝謝你的支持"],
        "购买正在等待确认": ["Purchase is pending approval", "購買正在等待確認"],
        "购买没有完成：": ["Purchase not completed: ", "購買沒有完成："],
        "恢复失败，请稍后再试": ["Restore failed, please try again later", "恢復失敗，請稍後再試"],
        "未命名": ["Untitled", "未命名"],
    ]
}

/// 简写：L("简体原文")
func L(_ zh: String) -> String { L10n.t(zh) }
