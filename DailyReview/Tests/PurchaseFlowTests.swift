import XCTest
import StoreKit
import StoreKitTest
@testable import DailyReview

/// 会员购买流程：用本地 StoreKit 测试环境（和 App Store 沙盒同一套接口）跑一遍
/// 大陆商店（人民币）和美国商店（美元）各测一次：价格、免费试用、购买、升级、到期、网页版拿到的数据
@MainActor
final class PurchaseFlowTests: XCTestCase {

    private func session(_ file: String, _ storefront: String) throws -> SKTestSession {
        TestMode.setVip(false)   // 测购买流程：不要测试会员
        let s = try SKTestSession(configurationFileNamed: file)
        s.resetToDefaultState()
        s.disableDialogs = true
        s.clearTransactions()
        s.storefront = storefront
        s.askToBuyEnabled = false
        return s
    }

    private func log(_ t: String) { print("FLOW| " + t) }

    private func entitlement(_ id: String) async -> Transaction? {
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, t.productID == id { return t }
        }
        return nil
    }

    func testChinaStore() async throws {
        let s = try session("ProductsCN", "CHN")
        _ = s
        let p = Purchases()
        await p.start()
        log("大陆商店：取到 \(p.products.count) 个商品，人民币=\(p.cn)")
        XCTAssertEqual(p.products.count, 3)
        XCTAssertTrue(p.cn, "大陆商店应显示人民币")
        for k in Purchases.kinds {
            let o = p.offer(k), c = p.cta(k)
            log("大陆 \(o.title)：\(o.price) ｜ \(o.note) ｜ 按钮「\(c.title)」\(c.sub)")
        }
        XCTAssertTrue(p.offer("year").price.contains("18"))
        XCTAssertTrue(p.offer("month").price.contains("3.5"))
        XCTAssertTrue(p.offer("life").price.contains("35"))
        XCTAssertTrue(p.offer("year").trial, "新用户应有 3 天免费试用")

        // 1. 开通年度卡（免费试用）
        let ok = await p.buy(kind: "year")
        log("购买年度卡：\(ok ? "成功" : "失败") 状态=\(p.plan) 提示=\(p.message ?? "")")
        XCTAssertTrue(ok)
        XCTAssertEqual(p.plan, "year")
        let t = await entitlement(Purchases.yearly)
        log("年度卡交易：offerType=\(String(describing: t?.offerType)) 到期=\(String(describing: t?.expirationDate))")
        XCTAssertEqual(t?.offerType, .introductory, "第一次开通应走免费试用")
        XCTAssertFalse(p.cta("year").enabled)
        log("开通后：年度卡按钮「\(p.cta("year").title)」，永久按钮「\(p.cta("life").title)」，试用资格=\(p.trialEligible)")
        XCTAssertFalse(p.trialEligible, "试用过一次后不应再有试用")

        // 2. 网页版拿到的会员页数据
        let info = WebBridge().vipInfo(p)
        let json = String(data: try JSONSerialization.data(withJSONObject: info), encoding: .utf8) ?? ""
        log("网页版会员数据：\(json)")
        XCTAssertEqual(info["plan"] as? String, "year")

        // 3. 升级永久会员
        let ok2 = await p.buy(kind: "life")
        log("升级永久会员：\(ok2 ? "成功" : "失败") 状态=\(p.plan)")
        XCTAssertEqual(p.plan, "life")
        XCTAssertFalse(p.cta("month").enabled)
    }

    func testUSStoreMonthlyExpire() async throws {
        let s = try session("ProductsUS", "USA")
        let p = Purchases()
        await p.start()
        log("美国商店：取到 \(p.products.count) 个商品，人民币=\(p.cn)")
        XCTAssertEqual(p.products.count, 3)
        XCTAssertFalse(p.cn, "非大陆商店应显示美元")
        for k in Purchases.kinds {
            let o = p.offer(k)
            log("美国 \(o.title)：\(o.price) ｜ \(o.note)")
        }
        XCTAssertTrue(p.offer("year").price.contains("2.9"))
        XCTAssertTrue(p.offer("life").price.contains("9.9"))

        // 月度卡：开通 → 到期 → 变回普通用户
        let ok = await p.buy(kind: "month")
        log("购买月度卡：\(ok ? "成功" : "失败") 状态=\(p.plan)")
        XCTAssertEqual(p.plan, "month")
        try s.expireSubscription(productIdentifier: Purchases.monthly)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        await p.refresh()
        log("月度卡到期后：状态=\(p.plan) 会员=\(p.isVIP)")
        XCTAssertEqual(p.plan, "free")

        // 到期后再开通年度卡：月度卡用过，年度卡的试用仍按 Apple 规则判断（同一群组只能试用一次）
        log("到期后年度卡：\(p.offer("year").note) ｜ 按钮「\(p.cta("year").title)」")
    }

    func testCancelledPurchaseKeepsFree() async throws {
        let s = try session("ProductsCN", "CHN")
        s.failTransactionsEnabled = true
        s.failureError = .unknown
        let p = Purchases()
        await p.start()
        let ok = await p.buy(kind: "life")
        log("购买失败的情况：返回=\(ok) 状态=\(p.plan) 提示=\(p.message ?? "")")
        XCTAssertFalse(ok)
        XCTAssertEqual(p.plan, "free")
        XCTAssertNotNil(p.message)
    }
}
