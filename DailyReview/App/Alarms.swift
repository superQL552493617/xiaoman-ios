import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
import ActivityKit
#endif

// MARK: - 闹钟提醒（iOS 26 的 AlarmKit：到点全屏响铃，锁屏和静音时也会响，手动关掉才停）

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct HabitAlarmMeta: AlarmMetadata {
    var cardId: String = ""
}
#endif

@MainActor
enum HabitAlarms {
    /// 已经拿到闹钟权限（iOS 26 以上）
    static var ready: Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return AlarmManager.shared.authorizationState == .authorized }
        #endif
        return false
    }

    /// 第一次设置提醒时请求闹钟权限；返回是否可以用闹钟
    @discardableResult
    static func requestIfNeeded() async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let m = AlarmManager.shared
            switch m.authorizationState {
            case .authorized: return true
            case .denied: return false
            default:
                let st = try? await m.requestAuthorization()
                return st == .authorized
            }
        }
        #endif
        return false
    }

    /// 按当前的习惯重新排所有闹钟（先清掉旧的）
    static func reschedule(_ s: AppState) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let m = AlarmManager.shared
            guard m.authorizationState == .authorized else { return }
            if let old = try? m.alarms { for a in old { try? m.cancel(id: a.id) } }
            let T = DK.today
            var jobs: [(Card, Reminder)] = []
            for c in s.cards where !c.isNote {
                if let p = s.activePause(c), p.from <= T { continue }
                for r in c.reminders ?? [] where (r.mode ?? "strong") == "strong" { jobs.append((c, r)) }
            }
            Task {
                for (c, r) in jobs { await schedule(c, r) }
            }
        }
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static func schedule(_ c: Card, _ r: Reminder) async {
        let all: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let days = (r.days ?? c.days).filter { (0...6).contains($0) }
        guard !days.isEmpty else { return }
        let wds = Array(Set(days)).sorted().map { all[$0] }
        let time = Alarm.Schedule.Relative.Time(hour: r.h, minute: r.m)
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: .weekly(wds)))
        let stop = AlarmButton(text: "关闭", textColor: .white, systemImageName: "checkmark.circle.fill")
        let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: c.name), stopButton: stop)
        let attrs = AlarmAttributes<HabitAlarmMeta>(presentation: AlarmPresentation(alert: alert),
                                                    metadata: HabitAlarmMeta(cardId: c.id),
                                                    tintColor: PT.vivid(c.hex))
        let tone = r.tone ?? 1
        let sound: AlertConfiguration.AlertSound = Bundle.main.url(forResource: "tone_\(tone)", withExtension: "wav") != nil ? .named("tone_\(tone).wav") : .default
        let cfg = AlarmManager.AlarmConfiguration<HabitAlarmMeta>.alarm(schedule: schedule, attributes: attrs, sound: sound)
        _ = try? await AlarmManager.shared.schedule(id: UUID(), configuration: cfg)
    }
    #endif
}
