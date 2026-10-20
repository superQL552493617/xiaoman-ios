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

/// 每个习惯的提醒 + 每日提醒。iOS 最多保留 64 个待发通知，按「每天」或「每周几」的重复规则排。
@MainActor
final class Notifier {
    static let shared = Notifier()
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func rescheduleAll(_ store: Store) { rescheduleAll(store.s) }

    func rescheduleAll(_ s: AppState) {
        center.removeAllPendingNotificationRequests()
        var count = 0
        for c in s.cards where !c.isNote {
            for r in c.reminders ?? [] {
                let days = Set(r.days ?? c.days)
                if days.count == 7 {
                    add(id: "card-\(c.id)-\(r.h)-\(r.m)", title: c.name, body: "该打卡啦，完成后记得点一下", h: r.h, m: r.m, weekday: nil)
                    count += 1
                } else {
                    for wd in days {
                        add(id: "card-\(c.id)-\(wd)-\(r.h)-\(r.m)", title: c.name, body: "该打卡啦，完成后记得点一下", h: r.h, m: r.m, weekday: wd + 1)
                        count += 1
                    }
                }
                if count > 58 { break }
            }
        }
        if s.prefs.daily.on {
            add(id: "daily-review", title: "小满", body: "花一分钟，记录一下今天吧", h: s.prefs.daily.h, m: s.prefs.daily.m, weekday: nil)
        }
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

@MainActor
final class AppLock: ObservableObject {
    @Published var locked = false
    private var wentBackground: Date?

    func appBecameActive(enabled: Bool) {
        guard enabled else { locked = false; return }
        if wentBackground == nil || Date().timeIntervalSince(wentBackground!) > 30 { locked = true }
    }

    func appWentBackground() { wentBackground = Date() }

    func unlock() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { locked = false; return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁小满") { ok, _ in
            Task { @MainActor in if ok { self.locked = false } }
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
