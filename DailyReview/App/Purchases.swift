import Foundation
import StoreKit

/// 会员：年会员（自动续期订阅）+ 永久会员（一次性买断）
/// 商品 ID 要和 App Store Connect 里创建的一致，上线前在那边建好这两个商品
@MainActor
final class Purchases: ObservableObject {
    static let yearly = "site.xiaomanhabit.app.vip.year"
    static let lifetime = "site.xiaomanhabit.app.vip.life"

    @Published var products: [Product] = []
    @Published var isVIP = false
    @Published var plan: String = "free"    // free / year / life
    @Published var busy = false
    @Published var message: String?

    private var updates: Task<Void, Never>?

    func start() async {
        updates?.cancel()
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
        await loadProducts()
        await refresh()
    }

    func loadProducts() async {
        do {
            let ps = try await Product.products(for: [Self.yearly, Self.lifetime])
            products = ps.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    func refresh() async {
        var p = "free"
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            if t.productID == Self.lifetime { p = "life" }
            else if t.productID == Self.yearly && p != "life" { p = "year" }
        }
        plan = p
        isVIP = p != "free"
    }

    func buy(_ product: Product) async {
        busy = true
        defer { busy = false }
        do {
            let r = try await product.purchase()
            switch r {
            case .success(let v):
                if case .verified(let t) = v { await t.finish(); message = "购买成功，感谢支持" }
                await refresh()
            case .userCancelled: break
            case .pending: message = "购买正在等待确认"
            @unknown default: break
            }
        } catch {
            message = "购买没有完成：\(error.localizedDescription)"
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = isVIP ? "已恢复会员" : "没有找到可以恢复的购买"
        } catch {
            message = "恢复失败，请稍后再试"
        }
    }
}
