import Foundation
import StoreKit
import SwiftUI
import UIKit

/// 会员：年度卡（自动续期，首次 3 天免费试用）、月度卡（自动续期）、永久会员（一次性买断）
/// 商品 ID 要和 App Store Connect 里创建的一致；价格以 App Store 为准，没取到时按地区显示默认价
@MainActor
final class Purchases: ObservableObject {
    static let yearly = "site.xiaomanhabit.app.vip.year"
    static let monthly = "site.xiaomanhabit.app.vip.month"
    static let lifetime = "site.xiaomanhabit.app.vip.life"
    static let kinds = ["year", "life", "month"]
    static func id(_ kind: String) -> String { kind == "year" ? yearly : kind == "month" ? monthly : lifetime }

    @Published var products: [Product] = []
    @Published var isVIP = false
    @Published var plan: String = "free"    // free / month / year / life
    @Published var expires: Date?
    @Published var trialEligible = true
    /// 中国区 App Store（人民币）；其他地区统一美元
    @Published var cn = true
    @Published var busy = false
    @Published var message: String?
    /// 第一次读完购买记录（之前的 plan 还不可信）
    @Published var loaded = false
    /// 测试包里送的会员（不是真的购买）
    @Published var isTestVIP = false

    private var updates: Task<Void, Never>?
    /// 任何页面（包括弹出页里）都能打开会员页
    static weak var shared: Purchases?

    func start() async {
        Self.shared = self
        updates?.cancel()
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
        if let c = await Storefront.current?.countryCode { cn = c == "CHN" }
        else { cn = Locale.current.region?.identifier == "CN" }
        await loadProducts()
        await refresh()
    }

    func loadProducts() async {
        do {
            let ps = try await Product.products(for: [Self.yearly, Self.monthly, Self.lifetime])
            products = ps
            if let y = product("year") { trialEligible = await y.subscription?.isEligibleForIntroOffer ?? false }
            if let p = ps.first { cn = p.priceFormatStyle.currencyCode == "CNY" }
        } catch {
            products = []
        }
    }

    func product(_ kind: String) -> Product? { products.first { $0.id == Self.id(kind) } }

    func refresh() async {
        var p = "free"
        var exp: Date?
        let rank = ["free": 0, "month": 1, "year": 2, "life": 3]
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            let k = t.productID == Self.lifetime ? "life" : t.productID == Self.yearly ? "year" : t.productID == Self.monthly ? "month" : "free"
            if rank[k, default: 0] > rank[p, default: 0] { p = k; exp = t.expirationDate }
        }
        // 测试包：没买也当作会员（摇一摇菜单可以关掉）
        isTestVIP = p == "free" && TestMode.vip
        if isTestVIP { p = "life"; exp = nil }
        plan = p
        expires = p == "life" ? nil : exp
        isVIP = p != "free"
        loaded = true
        if let y = product("year") { trialEligible = await y.subscription?.isEligibleForIntroOffer ?? false }
    }

    // MARK: 价格文字（网页版和原生版共用）

    struct Offer {
        var kind: String
        var title: String
        /// 大字价格：¥1.5/月、¥35
        var price: String
        /// 下面一行说明
        var note: String
        var badge: String?
        var trial: Bool
    }

    /// 价格文字：人民币去掉多余的 .00（¥18、¥3.5），美元保持 $2.90 这样的写法
    func priceText(_ p: Product) -> String {
        p.priceFormatStyle.currencyCode == "CNY" ? p.price.formatted(p.priceFormatStyle.precision(.fractionLength(0...2))) : p.displayPrice
    }

    func offer(_ kind: String) -> Offer {
        let fallbackYear = cn ? "¥18" : "$2.90", fallbackMonth = cn ? "¥3.5" : "$1.90", fallbackLife = cn ? "¥35" : "$9.90"
        let perMonthFallback = cn ? "¥1.5" : "$0.24"
        switch kind {
        case "year":
            let p = product("year")
            let full = p.map(priceText) ?? fallbackYear
            let per = p.map { ($0.price / 12).formatted($0.priceFormatStyle.precision(.fractionLength(0...2))) } ?? perMonthFallback
            let hasTrial = p.map { $0.subscription?.introductoryOffer?.paymentMode == .freeTrial } ?? true
            let trial = trialEligible && hasTrial && plan == "free"
            // 实际扣费的年价要最醒目（App Store 审核要求），折合月价放在下面
            return Offer(kind: kind, title: "年度卡", price: "\(full)/年",
                         note: trial ? "先免费用 3 天，约 \(per)/月" : "约 \(per)/月，每年自动续费", badge: "推荐", trial: trial)
        case "month":
            let full = product("month").map(priceText) ?? fallbackMonth
            return Offer(kind: kind, title: "月度卡", price: "\(full)/月", note: "每月 \(full)，随时可取消", badge: nil, trial: false)
        default:
            let full = product("life").map(priceText) ?? fallbackLife
            return Offer(kind: kind, title: "永久会员", price: full, note: "付一次，一直能用", badge: "买断", trial: false)
        }
    }

    /// 底部大按钮的文字
    func cta(_ kind: String) -> (title: String, sub: String, enabled: Bool) {
        if isTestVIP { return ("测试包已是会员", "摇一摇手机，可以关掉测试会员来测购买", false) }
        if plan == "life" { return ("你已是永久会员", "谢谢你一直支持小满", false) }
        if plan == kind { return ("当前正在使用", kind == "month" ? "每月自动续费，可随时在系统设置里取消" : "每年自动续费，可随时在系统设置里取消", false) }
        switch kind {
        case "year":
            let full = product("year").map(priceText) ?? (cn ? "¥18" : "$2.90")
            return offer("year").trial ? ("免费试用 3 天", "3 天后按 \(full)/年续费，试用期间取消不扣费", true) : ("开通年度卡", "每年 \(full) 自动续费，可随时在系统设置里取消", true)
        case "month": return ("开通月度卡", "每月自动续费，可随时在系统设置里取消", true)
        default: return (plan == "free" ? "买断永久会员" : "升级为永久会员", "一次购买，不会自动续费", true)
        }
    }

    var planName: String { isTestVIP ? "测试会员" : (["month": "月度会员", "year": "年度会员", "life": "永久会员"][plan] ?? "普通用户") }

    // MARK: 购买

    @discardableResult
    func buy(kind: String) async -> Bool {
        if products.isEmpty { await loadProducts() }
        guard let p = product(kind) else {
            message = L("暂时连不上 App Store，请检查网络后再试")
            return false
        }
        return await buy(p)
    }

    @discardableResult
    func buy(_ product: Product) async -> Bool {
        busy = true
        defer { busy = false }
        do {
            let r = try await product.purchase()
            switch r {
            case .success(let v):
                if case .verified(let t) = v { await t.finish(); message = L("开通成功，谢谢你的支持") }
                await refresh()
                return isVIP
            case .userCancelled: return false
            case .pending: message = L("购买正在等待确认"); return false
            @unknown default: return false
            }
        } catch {
            message = L("购买没有完成：") + error.localizedDescription
            return false
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = isVIP ? "已恢复\(planName)" : "没有找到可以恢复的购买"
        } catch {
            message = L("恢复失败，请稍后再试")
        }
    }
}

/// 会员权益：只写小满里真的有、并且只有会员才能用的功能
enum VipPerks {
    /// (网页图标, 原生图标, 标题, 说明)
    static let list: [(web: String, asset: String, title: String, sub: String)] = [
        ("shield", "sf:sparkles", "纯净无广告", "没有弹窗打扰，坚持起来更轻松"),
        ("cards", "vp_list", "解锁无限习惯数量", "想养多少个好习惯都可以，一个都不用舍弃"),
        ("camera", "vp_photo", "照片做图标", "拍一张或从相册选，做成独一无二的习惯图标"),
        ("lockf", "sf:lock.fill", "密码锁和面容 ID", "打开小满先验证，日记和打卡只有你能看"),
        ("heart", "sf:heart.fill", "支持小满走得更远", "你的支持会变成更多好用的小功能")
    ]
    static let free = "打卡、闹钟提醒、统计、笔记、小组件、主题背景和数据备份，所有人都能免费用。"
    static let freeLimit = 4
    /// 免费可用的主题背景
    static let freeThemes: Set<String> = ["white", "cream", "mist"]
}

/// 会员功能的入口：已是会员直接用；不是会员就在最上层弹出会员页
@MainActor
enum VipGate {
    static var isVIP: Bool { Purchases.shared?.isVIP ?? false }

    static func present() {
        guard let p = Purchases.shared, let top = UIApplication.topViewController() else { return }
        weak var vc: UIViewController?
        let host = UIHostingController(rootView: VipSheet(onClose: { vc?.dismiss(animated: true) }).environmentObject(p))
        vc = host
        host.modalPresentationStyle = .pageSheet
        if let sh = host.sheetPresentationController { sh.prefersGrabberVisible = true; sh.preferredCornerRadius = 30 }
        top.present(host, animated: true)
    }

    /// 需要会员时返回 false 并弹出会员页
    static func check() -> Bool {
        if isVIP { return true }
        Feedback.tap()
        present()
        return false
    }
}
