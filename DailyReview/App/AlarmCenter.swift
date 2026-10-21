import SwiftUI
import UIKit
import UserNotifications

// MARK: - 闹钟提醒：到点响铃；没人管每 5 分钟再响一次，最多 3 次；去打卡、稍后提醒、关闭或已经打卡就不再响
//
// 锁屏、后台：系统通知响铃（长按通知可以直接选 去打卡 / 10 分钟后提醒 / 关闭）
// 点开通知或 App 在前台时：全屏响铃页（原生版用自己的页面，网页版交给网页里的响铃页）

/// 一次响铃
struct AlarmRing: Identifiable, Equatable {
    var id: String { occ + "#\(k)" }
    /// 哪天、哪张卡片、哪个时间点：2026-10-21|cardId|21:30（稍后提醒再加 |z时间）
    let occ: String
    let cardId: String
    let h: Int
    let m: Int
    let tone: Int
    /// 第几次响（0、1、2）
    var k: Int = 0
    var snooze = false
    var test = false

    init(occ: String, cardId: String, h: Int, m: Int, tone: Int, k: Int = 0, snooze: Bool = false, test: Bool = false) {
        self.occ = occ; self.cardId = cardId; self.h = h; self.m = m; self.tone = tone; self.k = k; self.snooze = snooze; self.test = test
    }

    init?(info: [AnyHashable: Any]) {
        guard info["xmAlarm"] != nil, let occ = info["occ"] as? String, let card = info["card"] as? String else { return nil }
        self.init(occ: occ, cardId: card, h: (info["h"] as? Int) ?? 0, m: (info["m"] as? Int) ?? 0,
                  tone: (info["tone"] as? Int) ?? 1, k: (info["k"] as? Int) ?? 0, snooze: (info["snz"] as? Bool) ?? false)
    }

    init?(web b: [String: Any]) {
        guard let occ = b["occ"] as? String, let card = b["card"] as? String else { return nil }
        func int(_ k: String) -> Int { (b[k] as? Int) ?? Int((b[k] as? Double) ?? 0) }
        self.init(occ: occ, cardId: card, h: int("h"), m: int("m"), tone: max(1, int("tone")), k: int("k"), snooze: (b["snz"] as? Bool) ?? false)
    }

    var day: String { String(occ.split(separator: "|").first ?? "") }
    var json: String {
        let d: [String: Any] = ["occ": occ, "card": cardId, "h": h, "m": m, "tone": tone, "k": k, "snz": snooze]
        let data = (try? JSONSerialization.data(withJSONObject: d)) ?? Data("{}".utf8)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

enum AlarmRules {
    static let repeats = 3
    static let gap: TimeInterval = 5 * 60
    static let snooze: TimeInterval = 10 * 60
    /// 前台响铃页没人理，响 60 秒后自己停（下一次照常 5 分钟后再响）
    static let ringFor: TimeInterval = 60
    static let category = "XM_ALARM"
    static func occ(day: String, card: String, h: Int, m: Int) -> String { "\(day)|\(card)|\(h):\(m)" }
    static func ids(_ occ: String) -> [String] { (0..<repeats).map { "alm|\(occ)#\($0)" } }
}

/// 处理过的提醒、稍后提醒（存在本机，网页版和原生版共用）
enum AlarmLog {
    private static let d = UserDefaults.standard
    private static let doneKey = "almDone", snzKey = "almSnz"

    static func isDone(_ occ: String) -> Bool { (d.dictionary(forKey: doneKey) ?? [:])[occ] != nil }

    static func markDone(_ occ: String) {
        var m = d.dictionary(forKey: doneKey) ?? [:]
        let now = Date().timeIntervalSince1970
        m = m.filter { now - (($0.value as? Double) ?? 0) < 3 * 86400 }
        m[occ] = now
        d.set(m, forKey: doneKey)
    }

    struct Snooze: Codable { var occ: String; var card: String; var h: Int; var m: Int; var tone: Int; var t0: Double }

    static var snoozes: [Snooze] {
        get {
            guard let data = d.data(forKey: snzKey), let v = try? JSONDecoder().decode([Snooze].self, from: data) else { return [] }
            let now = Date().timeIntervalSince1970
            return v.filter { $0.t0 + Double(AlarmRules.repeats) * AlarmRules.gap > now }
        }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: snzKey) }
    }
}

@MainActor
final class AlarmCenter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = AlarmCenter()

    @Published var ringing: AlarmRing?
    /// 原生版：读卡片、去打卡
    weak var store: Store?
    var openCheck: ((String) -> Void)?
    /// 网页版：在网页里执行脚本（页面没准备好时先排队）
    private var web: ((String) -> Void)?
    private var pendingJS: [String] = []
    private var window: UIWindow?
    private var hideTask: Task<Void, Never>?

    enum Act: String { case go, snooze, off, timeout }

    /// App 启动时调用：接管通知的点击和前台显示，注册通知上的三个按钮
    func setup() {
        let c = UNUserNotificationCenter.current()
        c.delegate = self
        let go = UNNotificationAction(identifier: "XM_GO", title: "去打卡", options: [.foreground])
        let snz = UNNotificationAction(identifier: "XM_SNZ", title: "10 分钟后提醒", options: [])
        let off = UNNotificationAction(identifier: "XM_OFF", title: "关闭", options: [.destructive])
        let cat = UNNotificationCategory(identifier: AlarmRules.category, actions: [go, snz, off],
                                         intentIdentifiers: [], options: [.customDismissAction])
        c.setNotificationCategories([cat])
    }

    // MARK: 通知回调

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let info = notification.request.content.userInfo
        guard let ring = AlarmRing(info: info) else { return [.banner, .list, .sound] }
        // App 开着：不弹横幅，直接显示全屏响铃页
        await MainActor.run { self.present(ring) }
        return []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let act = response.actionIdentifier
        guard let ring = AlarmRing(info: info) else { return }
        switch act {
        case "XM_GO": await handle(ring, .go)
        case "XM_SNZ": await handle(ring, .snooze)
        case "XM_OFF", UNNotificationDismissActionIdentifier: await handle(ring, .off)
        default: await MainActor.run { self.present(ring) }   // 点开通知：全屏响铃页
        }
    }

    // MARK: 显示响铃页

    /// 到点（App 在前台）或点开了通知
    func present(_ ring: AlarmRing) {
        guard !ring.test else { show(ring); return }
        let s = (UIMode.current == "native" ? store?.s : nil) ?? Persistence.load()
        // 已经打卡、已经处理过、卡片删了：不再响，剩下的也取消
        if let s {
            if s.card(ring.cardId) == nil || s.isChecked(ring.day, ring.cardId) || AlarmLog.isDone(ring.occ) {
                Notifier.shared.cancel(ring.occ)
                return
            }
        }
        if UIMode.current == "native" { show(ring) } else { runJS("window.__xmAlarm&&__xmAlarm(\(ring.json))") }
    }

    /// 添加提醒页里的「试响一次」
    func test(card: Card, tone: Int) {
        show(AlarmRing(occ: "test", cardId: card.id, h: 0, m: 0, tone: tone, test: true), card: card)
    }

    private var testCard: Card?

    func card(for r: AlarmRing) -> Card? {
        if r.test, let c = testCard { return c }
        return store?.s.card(r.cardId) ?? Persistence.load()?.card(r.cardId)
    }

    private func show(_ ring: AlarmRing, card: Card? = nil) {
        testCard = ring.test ? card : nil
        hideTask?.cancel()
        ringing = ring
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let host = UIHostingController(rootView: AlarmRingHost())
        host.view.backgroundColor = .clear
        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        w.backgroundColor = .clear
        let mode = (store?.s ?? Persistence.load())?.prefs.mode
        w.overrideUserInterfaceStyle = mode == "dark" ? .dark : mode == "light" ? .light : .unspecified
        w.rootViewController = host
        w.isHidden = false
        window = w
    }

    private func hide() {
        ringing = nil
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self, self.ringing == nil else { return }
            self.window?.isHidden = true
            self.window = nil
        }
    }

    // MARK: 处理

    /// 响铃页、通知按钮、网页版都走这里
    func handle(_ ring: AlarmRing, _ act: Act, fromWeb: Bool = false) async {
        if ringing?.occ == ring.occ { hide() }
        guard !ring.test else { return }
        if act == .timeout { return }   // 没人理：剩下的照常再响
        AlarmLog.markDone(ring.occ)
        Notifier.shared.cancel(ring.occ)
        switch act {
        case .go:
            if !fromWeb {
                if UIMode.current == "native" { openCheck?(ring.cardId) }
                else { runJS("window.__xmAlarmGo&&__xmAlarmGo(\(ring.json))") }
            }
        case .snooze:
            let base = String(ring.occ.components(separatedBy: "|z").first ?? ring.occ)
            let now = Date().timeIntervalSince1970
            let z = AlarmLog.Snooze(occ: "\(base)|z\(Int(now))", card: ring.cardId, h: ring.h, m: ring.m, tone: ring.tone, t0: now + AlarmRules.snooze)
            var list = AlarmLog.snoozes
            list.append(z)
            AlarmLog.snoozes = list
            await Notifier.shared.addSnooze(z, name: card(for: ring)?.name ?? "小满")
        case .off, .timeout:
            break
        }
    }

    // MARK: 网页版

    /// 网页加载完成：之后的脚本直接执行
    func attachWeb(_ run: @escaping (String) -> Void) {
        web = run
        let q = pendingJS
        pendingJS = []
        for js in q { run(js) }
    }

    func detachWeb() { web = nil }

    private func runJS(_ js: String) {
        if let web { web(js) } else { pendingJS.append(js) }
    }
}

// MARK: - 全屏响铃页（和网页版的响铃页一致）

struct AlarmRingHost: View {
    @ObservedObject private var center = AlarmCenter.shared
    var body: some View {
        ZStack {
            if let r = center.ringing {
                AlarmRingView(ring: r, card: center.card(for: r)) { act in
                    Task { await center.handle(r, act) }
                }
                .id(r.id)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: center.ringing)
    }
}

struct AlarmRingView: View {
    let ring: AlarmRing
    let card: Card?
    var onAct: (AlarmCenter.Act) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var now = Date()
    @State private var shake = false
    @State private var timer: Timer?
    @State private var started = Date()

    private var dark: Bool { scheme == .dark }
    private var ink: Color { dark ? Color(hex: "#F2EDE4") : Color(hex: "#3E3532") }
    private let gray = Color(hex: "#8F857A")

    var body: some View {
        ZStack {
            LinearGradient(colors: dark ? [Color(hex: "#2A2620"), Color(hex: "#1E1B17")] : [Color(hex: "#FFF3D9"), Color(hex: "#FBE3C8")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                Text(String(format: "%02d:%02d", Calendar.current.component(.hour, from: now), Calendar.current.component(.minute, from: now)))
                    .font(.app(size: 64, weight: .light)).monospacedDigit().kerning(-1.2).foregroundStyle(ink)
                Text(dateLine).font(.app(size: 15)).foregroundStyle(gray).padding(.top, 2).padding(.bottom, 34)
                avatar.modifier(AlarmShake(on: shake))
                Text(title).font(.app(size: 24, weight: .heavy)).foregroundStyle(ink).padding(.top, 20)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("到时间啦，做完记得打个卡").font(.app(size: 14)).foregroundStyle(gray).padding(.top, 6)
                VStack(spacing: 10) {
                    if !ring.test && card != nil {
                        Button { onAct(.go) } label: {
                            Text("去打卡").font(.app(size: 17, weight: .bold)).foregroundStyle(Color(hex: "#3E3532"))
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(Capsule().fill(Color(hex: "#FFE7A3")))
                                .overlay(Capsule().strokeBorder(Color(hex: "#4A3F45"), lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                    Button { onAct(.snooze) } label: {
                        Text("10 分钟后再提醒").font(.app(size: 17, weight: .bold))
                            .foregroundStyle(dark ? Color(hex: "#ECE6DA") : Color(hex: "#4A3F45"))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Capsule().fill(Color.white.opacity(dark ? 0.1 : 0.75)))
                    }
                    .buttonStyle(.plain)
                    Button { onAct(.off) } label: {
                        Text("关闭").font(.app(size: 17, weight: .bold)).foregroundStyle(gray)
                            .frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 42)
                Spacer()
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private var title: String {
        let n = (card?.name ?? "").trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? (ring.test ? "试响" : "小满") : n
    }

    private var dateLine: String {
        let k = DK.key(now)
        var s = "\(DK.month(now))月\(DK.day(now))日 周\(DK.wdName[DK.weekday(k)])"
        if ring.test { s += " · 试响" }
        else if ring.snooze { s += ring.k > 0 ? " · 稍后提醒 · 第 \(ring.k + 1) 次" : " · 稍后提醒" }
        else if ring.k > 0 { s += " · 第 \(ring.k + 1) 次提醒" }
        return s
    }

    @ViewBuilder private var avatar: some View {
        if let c = card {
            ProtoDot(card: c, on: true, shape: "circle", line: "solid", size: 92)
        } else {
            Text("⏰").font(.app(size: 44)).frame(width: 92, height: 92).background(Circle().fill(Color(hex: "#F5C542")))
        }
    }

    private func start() {
        shake = true
        started = Date()
        ringOnce()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 4.2, repeats: true) { _ in
            Task { @MainActor in
                now = Date()
                if Date().timeIntervalSince(started) > AlarmRules.ringFor { stop(); onAct(.timeout); return }
                ringOnce()
            }
        }
    }

    private func ringOnce() {
        SFX.playTone(ring.tone)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        SFX.stopTone()
    }
}

/// 头像左右摇晃（和网页版 almShake 一样：1.2 秒一轮，后半段停住）
private struct AlarmShake: ViewModifier {
    var on: Bool
    func body(content: Content) -> some View {
        if on {
            content.keyframeAnimator(initialValue: 0.0, repeating: true) { v, a in
                v.rotationEffect(.degrees(a))
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-9, duration: 0.12)
                    LinearKeyframe(8, duration: 0.12)
                    LinearKeyframe(-6, duration: 0.12)
                    LinearKeyframe(4, duration: 0.12)
                    LinearKeyframe(0, duration: 0.24)
                    LinearKeyframe(0, duration: 0.48)
                }
            }
        } else { content }
    }
}
