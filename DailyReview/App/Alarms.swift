import Foundation
#if canImport(AlarmKit)
import AlarmKit
#endif

// MARK: - 旧版的系统闹钟（AlarmKit）
//
// 系统闹钟会一直响到手动关掉，做不到「没人管每 5 分钟响一次、响 3 次就停」，
// 所以提醒改成了通知（见 Notifier）。这里只负责把以前版本排过的系统闹钟清掉。

@MainActor
enum HabitAlarms {
    private static var cleaned = false

    static func cancelAll() {
        guard !cleaned else { return }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let m = AlarmManager.shared
            guard m.authorizationState == .authorized else { cleaned = true; return }
            if let old = try? m.alarms { for a in old { try? m.cancel(id: a.id) } }
        }
        #endif
        cleaned = true
    }
}
