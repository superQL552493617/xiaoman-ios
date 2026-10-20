import Foundation

/// 日期都用 "yyyy-MM-dd" 字符串作为键，和网页原型的数据格式一致，备份可以互相导入。
enum DK {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        c.locale = Locale(identifier: "zh_CN")
        return c
    }()

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ d: Date) -> String { fmt.string(from: d) }

    static func date(_ k: String) -> Date {
        if let d = fmt.date(from: k) { return calendar.startOfDay(for: d) }
        return calendar.startOfDay(for: Date())
    }

    static var today: String { key(Date()) }
    static var todayDate: Date { calendar.startOfDay(for: Date()) }

    static func add(_ d: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: d) ?? d
    }

    static func addKey(_ k: String, _ days: Int) -> String { key(add(date(k), days)) }

    /// 0 = 周日 … 6 = 周六（和 JS 的 getDay 一致）
    static func weekday(_ d: Date) -> Int { calendar.component(.weekday, from: d) - 1 }
    static func weekday(_ k: String) -> Int { weekday(date(k)) }

    static let wdName = ["日", "一", "二", "三", "四", "五", "六"]

    static func md(_ k: String) -> String {
        let d = date(k)
        return "\(calendar.component(.month, from: d))月\(calendar.component(.day, from: d))日"
    }

    static func year(_ d: Date) -> Int { calendar.component(.year, from: d) }
    static func month(_ d: Date) -> Int { calendar.component(.month, from: d) }
    static func day(_ d: Date) -> Int { calendar.component(.day, from: d) }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
    }

    static func hm(_ ms: Double?) -> String {
        guard let ms, ms > 1e12 else { return "" }
        let d = Date(timeIntervalSince1970: ms / 1000)
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static var nowMs: Double { Date().timeIntervalSince1970 * 1000 }

    /// 一周的第一天（weekStart: 1 = 周一，0 = 周日）
    static func weekStart(of d: Date, weekStart: Int) -> Date {
        let wd = weekday(d)
        let back = (wd - weekStart + 7) % 7
        return add(calendar.startOfDay(for: d), -back)
    }

    static func monthStart(_ d: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: d)) ?? d
    }

    static func daysInMonth(_ d: Date) -> Int {
        calendar.range(of: .day, in: .month, for: d)?.count ?? 30
    }
}
