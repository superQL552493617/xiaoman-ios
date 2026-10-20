import SwiftUI

/// 打开全屏页面（编辑卡片、写笔记等）的统一入口，任何页面都能调用
@MainActor
final class Router: ObservableObject {
    @Published var designer: DesignerTarget?
    @Published var journal: JournalTarget?
    /// 网页版样式的小弹出菜单（心情、笔记 ⋮、长按图标）
    @Published var pop: PopMenuState?
    @Published var memory = false
    @Published var vip = false
    /// 打卡弹窗（盖住底部栏，所以放在最外层）
    @Published var check: CheckTarget?
    var checkTop: CGFloat = 158
    /// 从统计页点某一天：切到打卡页并选中那天
    @Published var goDay: String?
}

struct DesignerTarget: Identifiable {
    let id = UUID()
    var cardId: String?
    var group: String?
}

struct JournalTarget: Identifiable {
    let id = UUID()
    var day: String
    var entryId: String?
}

struct DayTarget: Identifiable {
    let id = UUID()
    var day: String
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var lock: AppLock
    @EnvironmentObject var purchases: Purchases
    @StateObject private var toaster = Toaster()
    @StateObject private var router = Router()
    @State private var tab: AppTab = .today
    @State private var askWeb = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .today: TodayView()
                case .bars: HabitsView()
                case .ai: StatsView()
                case .memory: NavigationStack { MemoryView(asTab: true) }
                case .journal, .me: MeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(tab: $tab, showLabels: store.s.prefs.tabLabel, size: store.s.prefs.tabSize,
                           keys: AppTab.keys(store.s.prefs)) {
                router.journal = JournalTarget(day: DK.today, entryId: nil)
            }
            .padding(.bottom, 12)
            .onChange(of: store.s.prefs.tabs) { _, _ in
                if !AppTab.keys(store.s.prefs).contains(tab) { tab = .today }
            }

            if let ct = router.check {
                CheckDialogOverlay(cardId: ct.cardId, day: ct.day, top: router.checkTop) { router.check = nil }
                    .id(ct.id)
                    .zIndex(5)
            }

            PopMenuLayer(state: $router.pop).zIndex(6)

            if let t = toaster.text {
                ToastView(text: t, gray: toaster.gray)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .environmentObject(toaster)
        .environmentObject(router)
        // 所有从下往上弹出的页面都可以下滑关闭
        .sheet(item: $router.designer) { t in
            DesignerView(target: t)
                .environmentObject(store).environmentObject(toaster).environmentObject(router).environmentObject(purchases)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $router.journal) { t in
            JournalEditor(day: t.day, entryId: t.entryId)
                .environmentObject(store).environmentObject(toaster)
        }
        .sheet(isPresented: $router.memory) {
            NavigationStack { MemoryView() }
                .environmentObject(store).environmentObject(toaster).environmentObject(router)
        }
        .sheet(isPresented: $router.vip) {
            VipSheet()
                .environmentObject(store).environmentObject(purchases).environmentObject(toaster)
                .presentationCornerRadius(30).presentationDragIndicator(.visible)
        }
        .overlay {
            if lock.locked { LockScreen().environmentObject(lock).transition(.opacity) }
        }
        .onAppear {
            syncFeedback()
            // 截图测试用：启动参数 -shotTab bars 直接打开某个页签
            if let t = UserDefaults.standard.string(forKey: "shotTab"), let v = AppTab(rawValue: t) { tab = v }
            // 截图测试用：-shotSeed 1 造 40 天的打卡数据（和网页版对比图用的一样）
            if UserDefaults.standard.bool(forKey: "shotSeed") {
                let t0 = DK.todayDate
                for i in 0..<40 {
                    let k = DK.key(DK.add(t0, -i))
                    for (j, c) in store.s.cards.enumerated() where (i + j) % 3 != 0 {
                        store.s.records[k, default: [:]][c.id] = Rec(checked: true, t: DK.nowMs)
                    }
                }
            }
        }
        .onChange(of: store.s.prefs) { _, _ in syncFeedback() }
        .onChange(of: router.goDay) { _, k in if k != nil { withAnimation(.spring(response: 0.3)) { tab = .today } } }
        // 桌面小组件：xiaoman://journal 写今天的笔记，xiaoman://today 回到打卡页
        .onOpenURL { url in
            switch url.host {
            case "journal": router.journal = JournalTarget(day: DK.today, entryId: nil)
            case "today": tab = .today
            default: break
            }
        }
        // 摇一摇：切回网页版（和网页版里摇一摇切到原生版对应）
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in askWeb = true }
        .confirmationDialog("界面模式", isPresented: $askWeb, titleVisibility: .visible) {
            Button("切换到网页版界面") {
                store.saveNow()
                UserDefaults.standard.set("web", forKey: UIMode.key)
            }
            Button("取消", role: .cancel) {}
        } message: { Text("当前是原生版界面（测试中），数据两边共用。") }
        .onChange(of: store.s.prefs.sound) { _, _ in syncFeedback() }
    }

    private func syncFeedback() {
        Feedback.hapticOn = store.s.prefs.haptic
        Feedback.soundOn = store.s.prefs.sound
        SFX.inSound = store.s.prefs.sndIn ?? SFX.inDefault
        SFX.outSound = store.s.prefs.sndOut ?? SFX.outDefault
    }
}

struct LockScreen: View {
    @EnvironmentObject var lock: AppLock
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image("prog_palm").resizable().scaledToFit().frame(width: 72, height: 72)
            Text("小满已锁定").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
            Text("用\(AppLock.biometryName)解锁").font(.system(size: 14)).foregroundStyle(Theme.text2)
            Spacer()
            Button("解锁") { lock.unlock() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40).padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.pageBg.ignoresSafeArea())
        .onAppear { lock.unlock() }
    }
}
