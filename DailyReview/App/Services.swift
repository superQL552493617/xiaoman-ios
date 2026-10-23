import SwiftUI
import UIKit
import AudioToolbox
import AVFoundation
import UserNotifications
import LocalAuthentication

// MARK: - 触感和声音

@MainActor
enum Feedback {
    static var hapticOn = true
    static var soundOn = true

    static func tap() {
        guard hapticOn else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func soft() {
        guard hapticOn else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    static func success() {
        if hapticOn { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        if soundOn { AudioServicesPlaySystemSound(1104) }
    }
    static func check() {
        if hapticOn { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        if soundOn { SFX.play(SFX.inSound) }
    }
    /// 取消打卡
    static func uncheck() {
        if hapticOn { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        if soundOn { SFX.play(SFX.outSound) }
    }
    static func warn() {
        guard hapticOn else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// MARK: - 打卡音效（网页版用代码合成的声音，预先渲染成了 wav 文件）

@MainActor
enum SFX {
    static let list: [(n: Int, name: String, desc: String)] = [
        (n: 40, name: "气泡水“啵 + 呲”", desc: "啵一声，接着短短的气泡声"),
        (n: 39, name: "软木塞慢拔“啵～”", desc: "先有一点摩擦，再“啵”地拔出，尾音悠长"),
        (n: 1, name: "沙锤·轻摇一下", desc: "握着小沙锤轻轻晃一下，短而柔"),
        (n: 4, name: "一撮沙", desc: "最短的一下，干净利落"),
        (n: 5, name: "细沙洒落", desc: "一小把细沙撒在纸上，颗粒感明显"),
        (n: 6, name: "沙子滑过", desc: "沙在瓶里滑动，连续而顺滑"),
        (n: 11, name: "旋钮卡位·一格", desc: "拧动金属旋钮，卡进一格的“咔”"),
        (n: 12, name: "旋钮·连拧三格", desc: "“咔咔咔”三下，每格音高略有不同"),
        (n: 13, name: "棘轮拧紧", desc: "越拧越快，最后一下锁死"),
        (n: 15, name: "金属瓶盖拧开", desc: "拧开铁皮盖，两声“咔啦”"),
        (n: 16, name: "手表上弦", desc: "转动表冠的一串细密轻响，很安静"),
        (n: 18, name: "开香槟（只要“啵”）", desc: "只有最干脆的那一下"),
        (n: 23, name: "易拉罐开罐", desc: "“咔—嘶”，拉环一响，气跑出来"),
        (n: 27, name: "打火机开盖“叮”", desc: "金属盖翻开的一声，余音清亮"),
        (n: 28, name: "冰块碰杯", desc: "玻璃杯里冰块轻轻一碰"),
        (n: 31, name: "咔 + 沙沙", desc: "先“咔”一下锁定，紧接着一串细沙沙"),
        (n: 50, name: "摇沙 +“咔”", desc: "先摇一下沙子，再“咔”地卡进卡扣"),
        (n: 51, name: "“咔”+ 摇沙", desc: "先卡扣锁定，沙子跟着晃一下收尾"),
        (n: 54, name: "棘轮沙沙", desc: "每一格卡扣下面都带一点细沙"),
        (n: 55, name: "轻柔版", desc: "沙声和卡扣都更轻，适合安静环境")
    ]
    static let inDefault = 40, outDefault = 39
    static var inSound = 40
    static var outSound = 39
    private static var players: [Int: AVAudioPlayer] = [:]
    private static var sessionReady = false

    static func name(_ n: Int) -> String { list.first { $0.n == n }?.name ?? "" }

    private static var tonePlayer: AVAudioPlayer?

    /// 试听提醒铃声（静音键打开时也能听到，和闹钟响起时一样）
    static func playTone(_ n: Int) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        sessionReady = false
        guard let url = Bundle.main.url(forResource: "tone_\(n)", withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return }
        tonePlayer?.stop()
        p.volume = 1
        p.play()
        tonePlayer = p
    }

    static func stopTone() { tonePlayer?.stop(); tonePlayer = nil }

    static func play(_ n: Int) {
        if !sessionReady {
            // 跟随静音键，不打断别的 App 正在放的音乐
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            sessionReady = true
        }
        let p: AVAudioPlayer
        if let old = players[n] { p = old } else {
            guard let url = Bundle.main.url(forResource: "sfx_\(n)", withExtension: "wav"),
                  let np = try? AVAudioPlayer(contentsOf: url) else { return }
            np.prepareToPlay()
            players[n] = np
            p = np
        }
        p.currentTime = 0
        p.volume = 0.9
        p.play()
    }
}

// MARK: - 提醒通知

/// 闹钟提醒 + 每日提醒。
/// 闹钟：每次提醒按 0、5、10 分钟排三条一次性通知（没人管就每 5 分钟响一次，最多 3 次），
/// 处理过或打过卡就取消剩下的。iOS 最多保留 64 条待发通知，所以只排最近的 60 条，每次打开 App、保存、打卡时重排。
@MainActor
/// 提醒通知上的习惯图标：画成一张小图片附在通知上（锁屏和横幅右侧会显示这个习惯的图标）
enum AlarmIcon {
    private static var cache: [String: Data] = [:]

    static func attachment(_ c: Card?, id: String) -> [UNNotificationAttachment] {
        guard let c, let png = png(c) else { return [] }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("almicon-\(abs(id.hashValue)).png")
        do {
            try png.write(to: url, options: .atomic)
            return [try UNNotificationAttachment(identifier: "icon", url: url, options: nil)]
        } catch { return [] }
    }

    static func png(_ c: Card) -> Data? {
        let key = [c.id, c.ic, c.icon, c.text, c.hex, c.imgFit ?? "", String(c.icImg?.count ?? 0)].joined(separator: "|")
        if let d = cache[key] { return d }
        let side: CGFloat = 180
        let h = HexColor(c.hex)
        let bg = UIColor(h.mixWhite(0.55).color)
        let r = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let img = r.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: side, height: side)
            UIBezierPath(roundedRect: rect, cornerRadius: side * 0.24).addClip()
            bg.setFill(); ctx.fill(rect)
            if c.ic == "img", let ui = ImageData.image(c.icImg) {
                let fill = c.imgFit == "fill"
                let s = fill ? side : side * 0.7
                let r2 = CGRect(x: (side - s) / 2, y: (side - s) / 2, width: s, height: s)
                if !fill { UIBezierPath(roundedRect: r2, cornerRadius: s * 0.24).addClip() }
                let k = max(s / ui.size.width, s / ui.size.height)
                let w = ui.size.width * k, hh = ui.size.height * k
                ui.draw(in: CGRect(x: r2.midX - w / 2, y: r2.midY - hh / 2, width: w, height: hh))
            } else if c.ic == "text" {
                let t = c.text.isEmpty ? String(c.name.prefix(1)) : c.text
                let f = UIFont.systemFont(ofSize: side * (t.count > 1 ? 0.34 : 0.46), weight: .bold)
                let at: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: UIColor(Color(hex: c.hex)).withAlphaComponent(1)]
                let sz = (t as NSString).size(withAttributes: at)
                (t as NSString).draw(at: CGPoint(x: (side - sz.width) / 2, y: (side - sz.height) / 2), withAttributes: at)
            } else if let ui = UIImage(named: IconCatalog.assetName(c.icon)) {
                let s = side * 0.64
                ui.draw(in: CGRect(x: (side - s) / 2, y: (side - s) / 2, width: s, height: s))
            }
        }
        let d = img.pngData()
        if let d { cache[key] = d }
        return d
    }
}

final class Notifier {
    static let shared = Notifier()
    private let center = UNUserNotificationCenter.current()
    private var soon: Task<Void, Never>?

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func rescheduleAll(_ store: Store) { rescheduleAll(store.s) }

    /// 连续打卡时只排一次
    func rescheduleSoon(_ store: Store) {
        soon?.cancel()
        soon = Task { [weak self, weak store] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, let self, let store else { return }
            self.rescheduleAll(store.s)
        }
    }

    func rescheduleAll(_ s: AppState) {
        center.removeAllPendingNotificationRequests()
        // 以前版本排过的系统闹钟（会一直响到手动关掉）清掉，统一用下面的提醒规则
        HabitAlarms.cancelAll()
        let now = Date(), cal = Calendar.current, T = DK.today
        var items: [(Date, UNNotificationRequest)] = []
        for off in 0..<14 {
            let date = DK.add(DK.todayDate, off), k = DK.key(date), wd = DK.weekday(date)
            for c in s.cards where !c.isNote && !s.pausedOn(c, k) {
                if k == T && s.isChecked(k, c.id) { continue }
                for r in c.reminders ?? [] {
                    let days = (r.days?.isEmpty == false ? r.days! : c.days)
                    guard days.contains(wd) else { continue }
                    let occ = AlarmRules.occ(day: k, card: c.id, h: r.h, m: r.m)
                    if AlarmLog.isDone(occ) { continue }
                    guard let t0 = cal.date(bySettingHour: r.h, minute: r.m, second: 0, of: date) else { continue }
                    for i in 0..<AlarmRules.repeats {
                        let at = t0.addingTimeInterval(Double(i) * AlarmRules.gap)
                        if at <= now { continue }
                        items.append((at, alarmRequest(occ: occ, name: c.name, card: c.id, h: r.h, m: r.m, tone: r.tone ?? 1, k: i, snooze: false, at: at, c: c)))
                    }
                }
            }
        }
        // 稍后提醒
        for z in AlarmLog.snoozes {
            guard let c = s.card(z.card), !AlarmLog.isDone(z.occ) else { continue }
            let day = String(z.occ.split(separator: "|").first ?? "")
            if s.isChecked(day, c.id) { continue }
            for i in 0..<AlarmRules.repeats {
                let at = Date(timeIntervalSince1970: z.t0 + Double(i) * AlarmRules.gap)
                if at <= now { continue }
                items.append((at, alarmRequest(occ: z.occ, name: c.name, card: c.id, h: z.h, m: z.m, tone: z.tone, k: i, snooze: true, at: at, c: c)))
            }
        }
        items.sort { $0.0 < $1.0 }
        for (_, req) in items.prefix(60) { center.add(req) }
        if s.prefs.daily.on {
            add(id: "daily-review", title: "小满记", body: "花一分钟，记录一下今天吧", h: s.prefs.daily.h, m: s.prefs.daily.m, weekday: nil)
        }
    }

    /// 这次提醒处理过了：剩下没响的取消，通知中心里已经响过的也收起来
    func cancel(_ occ: String) {
        let ids = AlarmRules.ids(occ)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// 10 分钟后再提醒（没人管同样每 5 分钟再响，最多 3 次）
    func addSnooze(_ z: AlarmLog.Snooze, name: String) async {
        for i in 0..<AlarmRules.repeats {
            let at = Date(timeIntervalSince1970: z.t0 + Double(i) * AlarmRules.gap)
            try? await center.add(alarmRequest(occ: z.occ, name: name, card: z.card, h: z.h, m: z.m, tone: z.tone, k: i, snooze: true, at: at, c: Persistence.load()?.card(z.card)))
        }
    }

    private func alarmRequest(occ: String, name: String, card: String, h: Int, m: Int, tone: Int, k: Int, snooze: Bool, at: Date, c: Card? = nil) -> UNNotificationRequest {
        let ct = UNMutableNotificationContent()
        ct.attachments = AlarmIcon.attachment(c, id: "\(occ)#\(k)")
        ct.title = name
        if k == 0 {
            ct.body = snooze ? "稍后提醒：到时间啦，做完记得打个卡" : "到时间啦，做完记得打个卡"
        } else {
            ct.body = "还没打卡哦 · 第 \(k + 1) 次提醒" + (k == AlarmRules.repeats - 1 ? "（今天最后一次）" : "")
        }
        ct.sound = Self.ringSound(tone)
        ct.categoryIdentifier = AlarmRules.category
        ct.threadIdentifier = occ
        ct.interruptionLevel = .timeSensitive
        ct.relevanceScore = 1
        ct.userInfo = ["xmAlarm": 1, "occ": occ, "card": card, "h": h, "m": m, "tone": tone, "k": k, "snz": snooze]
        let dc = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: at)
        return UNNotificationRequest(identifier: "alm|\(occ)#\(k)", content: ct,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false))
    }

    /// 响铃声：约 28 秒的循环铃声（通知声音最长 30 秒）
    static func ringSound(_ tone: Int) -> UNNotificationSound {
        if Bundle.main.url(forResource: "alm_\(tone)", withExtension: "caf") != nil {
            return UNNotificationSound(named: UNNotificationSoundName("alm_\(tone).caf"))
        }
        if Bundle.main.url(forResource: "tone_\(tone)", withExtension: "wav") != nil {
            return UNNotificationSound(named: UNNotificationSoundName("tone_\(tone).wav"))
        }
        return .default
    }

    private func add(id: String, title: String, body: String, h: Int, m: Int, weekday: Int?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var dc = DateComponents()
        dc.hour = h; dc.minute = m
        if let weekday { dc.weekday = weekday }
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

// MARK: - 密码锁（面容 ID / 触控 ID / 设备密码）

/// 规则：冷启动时上锁；退到后台超过 30 秒再回来上锁；在前台时（包括面容 ID 弹窗、控制中心）都不会再要求验证
@MainActor
final class AppLock: ObservableObject {
    @Published var locked = false
    private var wentBackground: Date?
    private var started = false
    /// 正在验证：系统的面容 ID 弹窗会让 App 短暂失去焦点，这期间不能再触发一次
    private var evaluating = false
    /// 只在启动、从后台回来时自动弹一次验证；取消后停在锁屏页，点「解锁」再试
    private var autoPrompt = false

    /// App 启动时调用一次
    func start(enabled: Bool) {
        guard !started else { return }
        started = true
        if enabled { locked = true; autoPrompt = true; promptIfNeeded() }
    }

    func appBecameActive(enabled: Bool) {
        guard enabled else { locked = false; return }
        if let t = wentBackground {
            wentBackground = nil
            _ = t; locked = true; autoPrompt = true   // 离开过 App 就要重新验证
        }
        promptIfNeeded()
    }

    func appWentBackground(enabled: Bool) {
        guard enabled, !evaluating else { return }
        wentBackground = Date()
    }

    func promptIfNeeded() {
        guard locked, autoPrompt, !evaluating, UIApplication.shared.applicationState == .active else { return }
        autoPrompt = false
        unlock()
    }

    func unlock() {
        guard !evaluating else { return }
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { locked = false; return }
        evaluating = true
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁小满") { ok, _ in
            Task { @MainActor in
                self.evaluating = false
                if ok { withAnimation(.easeOut(duration: 0.25)) { self.locked = false } }
            }
        }
    }

    /// 开关 APP 锁前先验证一次
    static func verify(reason: String, _ done: @escaping @MainActor (Bool) -> Void) {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { done(true); return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
            Task { @MainActor in done(ok) }
        }
    }

    static var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "面容 ID"
        case .touchID: return "触控 ID"
        default: return "设备密码"
        }
    }
}

// MARK: - 设备信息（意见反馈用）

enum DeviceInfo {
    static var model: String {
        var sys = utsname()
        uname(&sys)
        let mirror = Mirror(reflecting: sys.machine)
        return mirror.children.reduce("") { id, el in
            guard let v = el.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
    }
    static var osVersion: String { UIDevice.current.systemVersion }
    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
    static var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }
}
