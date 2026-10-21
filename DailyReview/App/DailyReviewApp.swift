import SwiftUI

@main
struct DailyReviewApp: App {
    @StateObject private var store = Store()
    @StateObject private var purchases = Purchases()
    @StateObject private var lock = AppLock()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environmentObject(store)
                .environmentObject(purchases)
                .environmentObject(lock)
                .preferredColorScheme(UIMode.current != "native" ? nil : store.s.prefs.mode == "light" ? .light : store.s.prefs.mode == "dark" ? .dark : nil)
                .tint(Theme.text)
                .task {
                    lock.start(enabled: UIMode.current == "native" && store.s.prefs.lockOn)
                    await purchases.start()
                    store.vip = purchases.isVIP
                    Notifier.shared.rescheduleAll(Persistence.load() ?? store.s)
                    Persistence.dailySnapshot(store.s)
                }
                .onChange(of: purchases.isVIP) { _, v in store.vip = v }
                .onChange(of: phase) { _, p in
                    switch p {
                    case .active:
                        if UIMode.current == "native" { store.reloadIfChanged() }
                        lock.appBecameActive(enabled: UIMode.current == "native" && store.s.prefs.lockOn)
                    case .background:
                        // 网页版自己保存；这里只在原生版时写入，避免旧数据覆盖网页版的修改
                        if UIMode.current == "native" { store.saveNow() }
                        Persistence.dailySnapshot(store.s)
                        lock.appWentBackground(enabled: UIMode.current == "native" && store.s.prefs.lockOn)
                    default: break
                    }
                }
        }
    }
}

/// 按界面模式显示网页版或原生版
struct AppRoot: View {
    @AppStorage(UIMode.key) private var uiMode = "web"
    @EnvironmentObject var store: Store
    var body: some View {
        if uiMode == "native" {
            // 个性化里的「圆体」：所有页面（包括弹出页）一起换
            RootView().fontDesign(store.s.prefs.appFont == "round" ? .rounded : .default)
        } else { WebRootView() }
    }
}
