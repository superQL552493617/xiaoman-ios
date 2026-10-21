import SwiftUI
import UniformTypeIdentifiers

// MARK: - 打卡主页（按网页版 v256 复刻）

struct TodayView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var router: Router
    @Environment(\.colorScheme) private var scheme

    @State private var sel = DK.today
    @State private var stripOpen = true
    @State private var sparkle = 0
    @State private var pulses: [String: Int] = [:]
    @State private var lastAllDone: [String: Bool] = [:]
    @State private var popAll = false
    // 左右拖动换一天（网页版 bindDaySwipe）
    @State private var swipeX: CGFloat = 0
    @State private var swipeAxis = 0
    @State private var paneX: CGFloat = 0
    @State private var paneOpacity: Double = 1
    /// 长按卡片拖动换位置（网页版 gest：按住 0.42 秒抬起，拖到别的卡片上换位置）
    @State private var dragging: String?

    private var P: Prefs { store.s.prefs }
    private var isToday: Bool { sel == DK.today }
    private var shape: String { CardShapes.normalize(P.shape) }
    private var line: String { ["solid", "dash", "dot", "none"].contains(P.line) ? P.line : "solid" }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                tray(width: geo.size.width)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 130)
                    .offset(x: paneX)
                    .opacity(paneOpacity)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { topFix }
            .background(PageBG().ignoresSafeArea())
            .overlay(alignment: .leading) { dayHint(left: true) }
            .overlay(alignment: .trailing) { dayHint(left: false) }
        }
        .onAppear {
            stripOpen = P.home.strip; noteAllDone(animate: false)
            // 截图测试用：启动参数 -shotCheck 1 先打卡第一张
            if UserDefaults.standard.bool(forKey: "shotCheck"), let c = countable.first, !store.s.isChecked(sel, c.id) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tapCard(c) }
            }
            // 截图测试用：-shotDlg done/undo/pause 打开第一张卡片的弹窗；-shotDesigner new/edit 打开编辑页
            // 截图测试用：-shotAllDone 1 先把其它的都打上，6 秒多时点最后一个，截图时正好在冒光点
            if UserDefaults.standard.bool(forKey: "shotAllDone") {
                let left = countable.filter { !store.s.isChecked(sel, $0.id) }
                for c in left.dropLast() { store.toggle(c.id, on: sel) }
                noteAllDone(animate: false)
                if let last = left.last { DispatchQueue.main.asyncAfter(deadline: .now() + 6.2) { tapCard(last) } }
            }
            if UserDefaults.standard.string(forKey: "shotDlg") != nil, let c = countable.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { openDialog(c) }
            }
            if let d = UserDefaults.standard.string(forKey: "shotDesigner") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    router.designer = DesignerTarget(cardId: d == "edit" ? countable.first?.id : nil)
                }
            }
        }
        .onChange(of: sel) { _, _ in noteAllDone(animate: false) }
        .onAppear { if let k = router.goDay { sel = k; router.goDay = nil } }
        .onChange(of: router.goDay) { _, k in if let k { withAnimation { sel = k }; router.goDay = nil } }
    }

    // MARK: 顶部：标题 + 日期条（固定在上面，内容从下面滑过）

    private var topFix: some View {
        VStack(spacing: 0) {
            header
            // 日期条一直留在界面里，只改变高度，展开收起时不用重新排版 800 天的日期
            DateStrip(sel: $sel, dateColor: P.dateColor)
                .frame(height: 78)
                .opacity(stripOpen ? 1 : 0)
                .offset(y: stripOpen ? 0 : -24)
                .frame(height: stripOpen ? 78 : 0, alignment: .top)
                .clipped()
                .allowsHitTesting(stripOpen)
            Rectangle().fill(PT.hairline).frame(height: 1)
        }
        .background(
            (scheme == .dark ? Color(hex: "#0B0B0A").opacity(0.86) : Color(hex: P.pageBg == "custom" ? "#FFFFFF" : PageTheme.base(P.pageBg)).opacity(0.88))
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        )
        .clipped()
    }

    private var dayLabel: String {
        let dd = DK.daysBetween(DK.todayDate, DK.date(sel))
        return dd == 0 ? "今日" : dd == -1 ? "昨日" : dd == 1 ? "明天" : "\(DK.month(DK.date(sel)))月\(DK.day(DK.date(sel)))日"
    }

    private var header: some View {
        Button {
            Feedback.tap()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.92)) { stripOpen.toggle() }
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(dayLabel).tracking(0.2)
                    Text("•").font(.app(size: 16, weight: .semibold))
                    Text("周" + DK.wdName[DK.weekday(sel)]).tracking(0.2)
                    Image(systemName: "chevron.down")
                        .font(.app(size: 10, weight: .bold))
                        .foregroundStyle(PT.faint)
                        .rotationEffect(.degrees(stripOpen ? 180 : 0))
                        .padding(.leading, 1)
                }
                .font(.app(size: 16.5, weight: .semibold))
                .foregroundStyle(PT.ink)
                Text("今天想坚持的几件事").font(.app(size: 10)).foregroundStyle(PT.sub)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .accessibilityLabel("\(dayLabel)，点击\(stripOpen ? "收起" : "展开")日期栏")
    }

    // MARK: 主体

    private var visible: [Card] { store.s.visibleCards(on: sel) }
    private var countable: [Card] { visible.filter { !$0.isNote } }
    private var doneCount: Int { countable.filter { store.s.isChecked(sel, $0.id) }.count }
    private var allDone: Bool { !countable.isEmpty && doneCount == countable.count }

    @ViewBuilder private func tray(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if P.home.quick { QuickRow(day: sel).padding(.horizontal, 12).padding(.bottom, 12) }
            if P.home.jr { JournalStrip(day: sel) }
            VStack(alignment: .leading, spacing: 0) {
                trayHead.padding(.horizontal, 4).padding(.top, 6).padding(.bottom, 14).zIndex(2)
                groupsView(width: width)
                Text(isToday ? "今天的都完成了，真不错" : "这一天的都完成了，真不错")
                    .font(.app(size: 13))
                    .foregroundStyle(PT.cheer)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 88)
                    .opacity(allDone && P.home.cheer ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: allDone)
            }
            .contentShape(Rectangle())
            // 左右拖动换一天：页面跟着手指走一点，边上出现「前往明天 / 回到昨天」，拉够了松手就换（笔记卡片上的左滑留给删除）
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { v in
                        if swipeAxis == 0 { swipeAxis = abs(v.translation.width) > abs(v.translation.height) * 1.2 ? 1 : 2 }
                        guard swipeAxis == 1 else { return }
                        let wasGo = abs(swipeX) >= 80
                        swipeX = v.translation.width
                        paneX = swipeX * 0.35
                        if !wasGo && abs(swipeX) >= 80 { Feedback.soft() }
                    }
                    .onEnded { _ in
                        defer { swipeAxis = 0 }
                        guard swipeAxis == 1 else { return }
                        let dx = swipeX
                        swipeX = 0
                        if abs(dx) >= 80 {
                            Feedback.tap()
                            withAnimation(.easeIn(duration: 0.16)) { paneX = dx < 0 ? -60 : 60; paneOpacity = 0 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                sel = DK.addKey(sel, dx < 0 ? 1 : -1)
                                paneX = dx < 0 ? 60 : -60
                                withAnimation(.easeOut(duration: 0.22)) { paneX = 0; paneOpacity = 1 }
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.22)) { paneX = 0 }
                        }
                    }
            )
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
        // 松手的地方不在卡片上：结束拖动
        .onDrop(of: [UTType.text], isTargeted: nil) { _ in dragging = nil; store.save(); return true }
    }

    // MARK: 屏幕边上的竖排提示：前往明天 / 回到昨天

    @ViewBuilder private func dayHint(left: Bool) -> some View {
        let word = isToday ? (left ? "回到昨天" : "前往明天") : (left ? "前一天" : "后一天")
        let p = min(1, abs(swipeX) / 80)
        let shown = left ? swipeX > 0 : swipeX < 0
        let go = shown && p >= 1
        VStack(spacing: 2) {
            ForEach(Array(word.enumerated()), id: \.offset) { _, ch in Text(String(ch)) }
        }
        .font(.app(size: 13, weight: .medium))
        .foregroundStyle(go ? Theme.adaptive("#5E6B5A", "#CFE0C8") : PT.faint)
        .padding(.vertical, 12).padding(.horizontal, 5)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: left ? 0 : 12, bottomLeadingRadius: left ? 0 : 12,
                                   bottomTrailingRadius: left ? 12 : 0, topTrailingRadius: left ? 12 : 0, style: .continuous)
                .fill(go ? Theme.adaptive("#E7EEE3", "#34402F") : PT.chip.opacity(0.85))
        )
        .opacity(shown ? p : 0)
        .animation(.easeOut(duration: 0.15), value: go)
        .allowsHitTesting(false)
    }

    // MARK: 「日常打卡」标题行

    private var trayHead: some View {
        HStack(spacing: 8) {
            Text("日常打卡").font(.app(size: 16.5, weight: .semibold)).tracking(0.2).foregroundStyle(PT.ink)
            Button {
                store.updatePrefs { $0.flat.toggle() }
                Feedback.tap()
                toaster.show(store.s.prefs.flat ? "已切换至非分组模式" : "已切换至分组模式", gray: true)
            } label: {
                DoodleIcon(kind: .flat).frame(width: 18, height: 18).foregroundStyle(PT.iconGray)
                    .frame(width: 28, height: 28).contentShape(Circle())
            }
            .buttonStyle(.plain).padding(.leading, 4)
            .accessibilityLabel(P.flat ? "切换为分组显示" : "切换为不分组显示")
            Button { router.designer = DesignerTarget() } label: {
                DoodleIcon(kind: .add).frame(width: 18, height: 18).foregroundStyle(PT.iconGray)
                    .frame(width: 28, height: 28).contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新建卡片")
            Spacer(minLength: 0)
            if !isToday {
                BackTodayButton { withAnimation(.easeOut(duration: 0.25)) { sel = DK.today } }
                Spacer(minLength: 0)
            }
            if !countable.isEmpty && P.home.prog { progressPill }
        }
        .frame(height: 34)
    }

    private var progressPill: some View {
        HStack(spacing: 4) {
            Image(allDone ? "pg_palm_on" : "pg_palm_off").resizable().scaledToFit()
                .frame(width: 22, height: 22)
                .scaleEffect(popAll ? 1 : (allDone ? 1 : 1))
                .keyframeAnimator(initialValue: CGFloat(1), trigger: sparkle) { v, s in v.scaleEffect(s) } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(0.7, duration: 0.01)
                        SpringKeyframe(1.0, duration: 0.5, spring: .init(response: 0.35, dampingRatio: 0.45))
                    }
                }
                .overlay { SparkleBurst(trigger: sparkle) }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(doneCount)").font(.app(size: 14, weight: .bold)).foregroundStyle(PT.ink)
                Text("/").font(.app(size: 14, weight: .medium)).foregroundStyle(PT.faint).opacity(0.75).padding(.horizontal, 1.5)
                Text("\(countable.count)").font(.app(size: 14, weight: .semibold)).foregroundStyle(PT.faint)
            }
            .monospacedDigit()
        }
        .padding(.leading, 7).padding(.trailing, 11).frame(height: 34)
        .background(Capsule().fill(PT.chip))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("已完成 \(doneCount) 项，共 \(countable.count) 项")
    }

    // MARK: 分组 + 卡片

    private struct GroupBlock: Identifiable { let id: String; let name: String; let collapsed: Bool; let cards: [Card] }

    private var blocks: [GroupBlock] {
        let vis = visible
        if P.flat {
            let order = P.flatOrder ?? []
            let idx: (Card) -> Int = { c in order.firstIndex(of: c.id) ?? (10_000 + (store.s.cards.firstIndex(of: c) ?? 0)) }
            return [GroupBlock(id: "__flat", name: "", collapsed: false, cards: vis.sorted { idx($0) < idx($1) })]
        }
        let known = Set(store.s.groups.map { $0.id })
        var out = store.s.groups.map { g in GroupBlock(id: g.id, name: g.name, collapsed: g.collapsed == true, cards: vis.filter { $0.group == g.id }) }
        let ug = store.s.ungrouped
        out.append(GroupBlock(id: "", name: ug?.name ?? store.s.ungroupedName, collapsed: ug?.collapsed == true,
                              cards: vis.filter { $0.group == nil || !known.contains($0.group!) }))
        return out.filter { !$0.cards.isEmpty }
    }

    @ViewBuilder private func groupsView(width: CGFloat) -> some View {
        let bs = blocks
        if bs.isEmpty || visible.isEmpty {
            VStack(spacing: 8) {
                if store.s.cards.isEmpty {
                    Text("从一个小习惯开始吧").font(.app(size: 15, weight: .semibold)).foregroundStyle(PT.ink)
                    Text("点「日常打卡」旁边的 +，种下第一张打卡卡片。每天点亮一次，日子会慢慢亮起来。")
                        .font(.app(size: 13)).foregroundStyle(PT.sub).multilineTextAlignment(.center)
                } else {
                    Text("这一天没有安排打卡，给自己放个假吧。").font(.app(size: 13)).foregroundStyle(PT.sub)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 30).padding(.horizontal, 20)
        } else {
            let heads = !store.s.groups.isEmpty && !P.flat
            let named = bs.filter { !$0.id.isEmpty && $0.id != "__flat" }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(bs) { b in
                    VStack(alignment: .leading, spacing: 0) {
                        if heads { groupHead(b, named: named).padding(.bottom, 12) }
                        if !b.collapsed || !heads {
                            grid(b.cards, width: width).padding(.top, heads ? 6 : 0)
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func groupHead(_ b: GroupBlock, named: [GroupBlock]) -> some View {
        let left = b.cards.filter { !$0.isNote && !store.s.isChecked(sel, $0.id) }.count
        let cnt = b.cards.filter { !$0.isNote }.count
        let ni = named.firstIndex { $0.id == b.id }
        return HStack(spacing: 4) {
            Button {
                Feedback.tap()
                withAnimation(.easeInOut(duration: 0.25)) { store.toggleGroupCollapsed(b.id) }
            } label: {
                HStack(spacing: 5) {
                    Text(b.name).font(.app(size: 13, weight: .semibold)).foregroundStyle(PT.ink)
                    if cnt > 0 { Text("• \(left)").font(.app(size: 12.5, weight: .medium)).foregroundStyle(PT.muted) }
                    Image(systemName: "chevron.down")
                        .font(.app(size: 7.5, weight: .heavy))
                        .foregroundStyle(PT.cvInk)
                        .rotationEffect(.degrees(b.collapsed ? -90 : 0))
                        .frame(width: 17, height: 17)
                        .background(Circle().fill(PT.cvBg))
                        .padding(.leading, 2)
                }
                .padding(.leading, 12).padding(.trailing, 6).frame(height: 31)
                .background(Capsule().fill(PT.chip))
                .overlay(Capsule().strokeBorder(PT.chipLine, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(b.name)，待完成 \(left) 项")
            if let ni, named.count > 1 {
                moveButton(up: true, enabled: ni > 0) { store.moveGroup(b.id, by: -1) }
                moveButton(up: false, enabled: ni < named.count - 1) { store.moveGroup(b.id, by: 1) }
            }
        }
    }

    private func moveButton(up: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Feedback.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { action() }
        } label: {
            Image(systemName: up ? "chevron.up" : "chevron.down")
                .font(.app(size: 11, weight: .bold))
                .foregroundStyle(PT.faint)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.28)
        .disabled(!enabled)
        .accessibilityLabel(up ? "上移分组" : "下移分组")
    }

    /// 网页版的网格：铺满整个屏幕宽度，列宽 = (屏宽 + 56) / (列数 + 1)
    private func grid(_ cards: [Card], width: CGFloat) -> some View {
        let n = PT.columns(P.layout)
        let colW = (width + PT.dot) / CGFloat(n + 1)
        let pad = colW / 2 - PT.dot / 2
        let rows = stride(from: 0, to: cards.count, by: n).map { Array(cards[$0..<min($0 + n, cards.count)]) }
        return VStack(alignment: .leading, spacing: PT.rowGap(P.layout)) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(rows[r]) { c in
                        ProtoCell(card: c, rec: store.s.rec(sel, c.id), layout: P.layout, shape: shape, line: line,
                                  pulse: pulses[c.id] ?? 0, width: colW)
                            .opacity(dragging == c.id ? 0.35 : 1)
                            .onTapGesture { tapCard(c) }
                            .onDrag {
                                dragging = c.id
                                Feedback.tap()
                                return NSItemProvider(object: c.id as NSString)
                            } preview: {
                                ProtoDot(card: c, on: store.s.isChecked(sel, c.id), shape: shape, line: line)
                                    .padding(6)
                                    .environmentObject(store)
                            }
                            .onDrop(of: [UTType.text], delegate: TodayDrop(target: c, store: store, flat: P.flat, order: cards.map(\.id), dragging: $dragging))
                    }
                }
            }
        }
        .padding(.horizontal, pad)
        .frame(width: width, alignment: .leading)
        .padding(.leading, -18)
    }

    private func tapCard(_ c: Card) {
        if store.s.isChecked(sel, c.id) {
            openDialog(c)
            Feedback.tap()
            return
        }
        store.toggle(c.id, on: sel)
        pulses[c.id, default: 0] += 1
        Feedback.check()
        noteAllDone(animate: true)
        if c.isNote {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) { openDialog(c) }
        }
    }

    /// 弹窗放在日期条下面，日期仍然看得见
    private func openDialog(_ c: Card) {
        router.checkTop = stripOpen ? 158 : 80
        router.check = CheckTarget(cardId: c.id, day: sel)
    }

    /// 当天从「没做完」变成「全部完成」的那一刻：椰树变彩色并冒出光点
    private func noteAllDone(animate: Bool) {
        let now = allDone && P.home.prog
        if animate, now, lastAllDone[sel] == false { sparkle += 1; Feedback.success() }
        lastAllDone[sel] = now
    }
}

/// 打卡页拖动换位置：拖到哪张卡片上，就排到它的位置（分组模式下也会换到那个分组）
private struct TodayDrop: DropDelegate {
    let target: Card
    let store: Store
    let flat: Bool
    let order: [String]
    @Binding var dragging: String?

    func validateDrop(info: DropInfo) -> Bool { dragging != nil }
    func dropEntered(info: DropInfo) {
        guard let d = dragging, d != target.id else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if flat {
                var ids = store.s.prefs.flatOrder ?? []
                for c in store.s.cards where !ids.contains(c.id) { ids.append(c.id) }
                guard let from = ids.firstIndex(of: d), let to = ids.firstIndex(of: target.id) else { return }
                ids.remove(at: from)
                ids.insert(d, at: to)
                store.s.prefs.flatOrder = ids
            } else {
                guard let from = store.s.cards.firstIndex(where: { $0.id == d }),
                      let to = store.s.cards.firstIndex(where: { $0.id == target.id }) else { return }
                var c = store.s.cards.remove(at: from)
                c.group = target.group
                store.s.cards.insert(c, at: min(to, store.s.cards.count))
            }
        }
        Feedback.tap()
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        store.save()
        return true
    }
    func dropExited(info: DropInfo) {}
}

struct CheckTarget: Identifiable {
    var id: String { cardId + day }
    let cardId: String
    let day: String
}

// MARK: - 回到今日（虚线小按钮，呼吸闪烁）

struct BackTodayButton: View {
    var action: () -> Void
    @State private var breathe = false
    var body: some View {
        Button(action: action) {
            Text("回到今日").font(.app(size: 12, weight: .medium)).foregroundStyle(Color(hex: "#7BB37A"))
                .padding(.horizontal, 10).frame(height: 26)
                .overlay(Capsule().strokeBorder(Color(hex: "#9CCB9A"), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                .opacity(breathe ? 0.9 : 0.28)
        }
        .buttonStyle(.plain)
        .onAppear { withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathe = true } }
    }
}

// MARK: - 日期条（左右滑动，停下的那天就是选中的日子）

struct DateStrip: View {
    @Binding var sel: String
    var dateColor: String
    @State private var pos: String?
    @State private var settle: Task<Void, Never>?
    @Environment(\.colorScheme) private var scheme

    private static let span = 400
    private let keys: [String] = {
        let t0 = DK.todayDate
        return (-span...span).map { DK.key(DK.add(t0, $0)) }
    }()

    var body: some View {
        GeometryReader { g in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(keys, id: \.self) { k in
                        item(k)
                            .frame(width: 50, height: 78)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Feedback.tap()
                                if k != sel { sel = k }
                                withAnimation(.easeOut(duration: 0.23)) { pos = k }
                            }
                            .id(k)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max(0, (g.size.width - 50) / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $pos, anchor: .center)
            .scrollIndicators(.hidden)
            .onAppear { pos = sel }
            .onChange(of: pos) { _, p in
                settle?.cancel()
                guard let p, p != sel else { return }
                settle = Task {
                    try? await Task.sleep(nanoseconds: 140_000_000)
                    guard !Task.isCancelled, pos == p, p != sel else { return }
                    sel = p
                    Feedback.tap()
                }
            }
            .onChange(of: sel) { _, s in if pos != s { withAnimation(.easeOut(duration: 0.23)) { pos = s } } }
        }
    }

    private var tint: (bg: Color, ring: Color, classic: Bool) {
        let c = Theme.dateColors.first { $0.id == dateColor } ?? Theme.dateColors[0]
        if c.id == "classic" { return (scheme == .dark ? Color(hex: "#F2F2F7") : Color(hex: "#1C1C1E"), Color(hex: "#6E6E73"), true) }
        let h = HexColor(c.hex)
        return (h.color, h.mix(HexColor("#000000"), 0.39).color, false)
    }

    @ViewBuilder private func item(_ k: String) -> some View {
        let d = DK.date(k)
        let isSel = k == sel, isToday = k == DK.today
        let t = tint
        let first = DK.day(d) == 1
        VStack(spacing: 5) {
            Text(first ? "\(DK.month(d))月" : "周" + DK.wdName[DK.weekday(d)])
                .font(.app(size: 10.5, weight: first ? .semibold : .regular))
                .foregroundStyle(isSel ? (t.classic ? Color.white.opacity(0.7) : Color(hex: "#1C1C1E").opacity(0.6)) : (first ? Color(hex: "#007AFF") : PT.faint))
            Text("\(DK.day(d))")
                .font(.app(size: 17.5, weight: isSel ? .bold : .semibold))
                .foregroundStyle(isSel ? (t.classic ? (scheme == .dark ? Color(hex: "#1C1C1E") : .white) : Color(hex: "#1C1C1E")) : PT.ink)
        }
        .frame(width: 42, height: 62)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isSel ? t.bg : PT.stripItem))
        .overlay {
            if isSel && isToday {
                RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(PT.bg, lineWidth: 2).padding(-1)
                RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(t.ring, lineWidth: 1.5).padding(-2.75)
            } else if isToday {
                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(PT.ink, lineWidth: 1.5)
            }
        }
        .compositingGroup()
        .shadow(color: isSel && !isToday ? t.ring.opacity(0.55) : .clear, radius: 5, y: 5)
    }
}

// MARK: - 顶部快捷栏（笔记 / 回忆 / 心情）

struct QuickRow: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var toaster: Toaster
    let day: String
    @State private var moodFrame: CGRect = .zero

    static let ids = ["jr", "time", "mood"]

    var body: some View {
        let ids = Self.ids.filter { store.s.prefs.quickOn($0) }
        if !ids.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(ids.enumerated()), id: \.element) { i, id in
                    if i > 0 { Rectangle().fill(PT.chipLine).frame(width: 1, height: 18) }
                    button(id)
                }
            }
            .frame(height: 42)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(PT.chip))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(PT.chipLine, lineWidth: 1))
        }
    }

    @ViewBuilder private func button(_ id: String) -> some View {
        let b = Button {
            Feedback.tap()
            switch id {
            case "jr": router.journal = JournalTarget(day: day)
            case "time": router.memory = true
            default: openMood()
            }
        } label: {
            HStack(spacing: 4) {
                switch id {
                case "jr": icon("q_note"); Text("笔记")
                case "time": icon("q_memory"); Text("回忆")
                default:
                    if let m = store.s.moodOf(day) { icon(m.asset); Text(m.name) } else { icon("q_mood"); Text("心情") }
                }
            }
            .font(.app(size: 13, weight: .medium)).tracking(0.2)
            .foregroundStyle(PT.quickInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if id == "mood" {
            b.readFrame($moodFrame)
                .onAppear {
                    // 截图测试用：-shotMood 1 打开心情菜单
                    if UserDefaults.standard.bool(forKey: "shotMood") { DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { openMood() } }
                }
        } else { b }
    }

    /// 网页版 openMood：按钮下面弹出小菜单，再点一次当前心情就是清除
    private func openMood() {
        let cur = store.s.moodOf(day)?.id
        let d = DK.date(day)
        router.pop = PopMenuState(anchor: moodFrame, title: "\(DK.month(d))月\(DK.day(d))日 心情怎么样", width: 200,
                                  items: Mood.all.map { m in
            PopItem(label: m.name, icon: .asset(m.asset), on: cur == m.id) { [store, toaster] in
                store.setMood(cur == m.id ? nil : m.id, on: day)
                Feedback.tap()
                toaster.show(cur == m.id ? "已清除这天的心情" : "记下了：\(m.name)", gray: true)
            }
        })
    }

    private func icon(_ name: String) -> some View { Image(name).resizable().scaledToFit().frame(width: 21, height: 21) }
}

// MARK: - 当天的笔记卡片

struct JournalStrip: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @EnvironmentObject var toaster: Toaster
    let day: String

    var body: some View {
        let list = store.s.journalList(day)
        if !list.isEmpty {
            let folded = store.s.prefs.jrFold
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    Feedback.tap()
                    withAnimation(.easeInOut(duration: 0.3)) { store.updatePrefs { $0.jrFold.toggle() } }
                } label: {
                    HStack(spacing: 6) {
                        Text("笔记").font(.app(size: 16.5, weight: .semibold)).tracking(0.2).foregroundStyle(PT.ink)
                        Image(systemName: "chevron.down").font(.app(size: 8, weight: .heavy)).foregroundStyle(.white)
                            .rotationEffect(.degrees(folded ? -90 : 0))
                            .frame(width: 18, height: 18).background(Circle().fill(PT.cvBg))
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 14)
                if !folded {
                    VStack(spacing: 8) {
                        ForEach(list) { e in
                            JournalCardView(day: day, entry: e) {
                                router.journal = JournalTarget(day: day, entryId: e.id)
                            } onMore: { f in
                                router.pop = store.journalMenu(day: day, entry: e, anchor: f, toaster: toaster) {
                                    router.journal = JournalTarget(day: day, entryId: e.id)
                                }
                            } onDelete: {
                                withAnimation(.easeOut(duration: 0.25)) { store.deleteJournal(e.id, on: day) }
                                toaster.show("已删除", gray: true)
                            }
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.top, 2).padding(.bottom, 20)
        }
    }
}

// MARK: - 手绘风小图标（⇄ 和 +，和网页版同一条路径）

struct DoodleIcon: View {
    enum Kind { case flat, add }
    var kind: Kind
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 24
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            var path = Path()
            switch kind {
            case .flat:
                path.move(to: p(5, 9)); path.addLine(to: p(19, 9))
                path.move(to: p(16, 6)); path.addLine(to: p(19, 9)); path.addLine(to: p(16, 12))
                path.move(to: p(19, 15)); path.addLine(to: p(5, 15))
                path.move(to: p(8, 12)); path.addLine(to: p(5, 15)); path.addLine(to: p(8, 18))
            case .add:
                path.move(to: p(12, 5.5)); path.addLine(to: p(12, 18.5))
                path.move(to: p(5.5, 12)); path.addLine(to: p(18.5, 12))
            }
            ctx.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - 全部完成时：椰树周围一圈暖光，细小的光点和星星往下缓缓飘（和网页版 sparkBurst 一样）

struct SparkleBurst: View {
    var trigger: Int
    @State private var start: Date?
    @State private var parts: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x0: CGFloat, y0: CGFloat, sway: CGFloat, fall: CGFloat, size: CGFloat, color: Color, star: Bool, delay: Double, dur: Double

        /// 网页版的四个关键帧：出现 → 10% 变亮 → 65% → 消失
        func state(_ t: Double) -> (x: CGFloat, y: CGFloat, s: CGFloat, o: Double)? {
            guard t >= 0 else { return nil }
            let u = min(1, t / dur)
            let e = 1 - pow(1 - u, 2.2)   // 先快后慢，接近 cubic-bezier(.3,.6,.4,1)
            let k: [(Double, CGFloat, CGFloat, CGFloat, Double)] = [
                (0, x0, y0, 0.6, 0.6),
                (0.1, x0 + sway * 0.3, y0 + fall * 0.2, 1, 1),
                (0.65, x0 + sway, y0 + fall * 0.7, 0.9, 0.85),
                (1, x0 + sway * 0.6, y0 + fall, 0.4, 0)
            ]
            var i = 0
            while i < k.count - 2 && e > k[i + 1].0 { i += 1 }
            let a = k[i], b = k[i + 1], f = CGFloat((e - a.0) / (b.0 - a.0))
            return (a.1 + (b.1 - a.1) * f, a.2 + (b.2 - a.2) * f, a.3 + (b.3 - a.3) * f, a.4 + (b.4 - a.4) * Double(f))
        }
    }

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { tl in
            let t = start.map { tl.date.timeIntervalSince($0) } ?? 99
            ZStack {
                if t < 1.4 {
                    let u = t / 1.4
                    let o = u < 0.15 ? 0.35 + (0.6 - 0.35) * u / 0.15 : 0.6 * (1 - (u - 0.15) / 0.85)
                    Circle()
                        .fill(RadialGradient(colors: [Color(red: 1, green: 226/255, blue: 120/255).opacity(0.55), Color(red: 1, green: 226/255, blue: 120/255).opacity(0)],
                                             center: .center, startRadius: 0, endRadius: 17 * 0.7 * 1.43))
                        .frame(width: 34, height: 34)
                        .scaleEffect(0.8 + 0.7 * (1 - pow(1 - u, 2)))
                        .opacity(o)
                }
                ForEach(parts) { p in
                    if let st = p.state(t - p.delay) {
                        Group {
                            if p.star { StarShape().fill(p.color) } else { Circle().fill(p.color) }
                        }
                        .frame(width: p.size, height: p.size)
                        .shadow(color: p.color, radius: 1.5)
                        .scaleEffect(st.s)
                        .opacity(st.o)
                        .offset(x: st.x, y: st.y)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in fire() }
    }

    private func fire() {
        let C: [Color] = ["#FFD45C", "#F7C948", "#8FD27A", "#FF9DB5", "#9BD0F5", "#FFC27A"].map { Color(hex: $0) }
        let w: CGFloat = 22, h: CGFloat = 22
        parts = (0..<22).map { i in
            let star = Double.random(in: 0...1) < 0.4
            return Particle(x0: CGFloat.random(in: -0.5...0.5) * w * 1.1, y0: CGFloat.random(in: -0.6...0.4) * h * 0.8,
                            sway: CGFloat.random(in: -5...5), fall: CGFloat.random(in: 16...32),
                            size: star ? CGFloat.random(in: 3...5) : CGFloat.random(in: 1.4...3), color: C[i % C.count], star: star,
                            delay: i < 12 ? Double.random(in: 0...0.12) : Double.random(in: 0.15...0.8), dur: Double.random(in: 1.7...2.6))
        }
        start = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) { start = nil; parts = [] }
    }
}

/// 网页版 .spark.star 的四角星
struct StarShape: Shape {
    func path(in r: CGRect) -> Path {
        let pts: [(CGFloat, CGFloat)] = [(0.5, 0), (0.62, 0.38), (1, 0.5), (0.62, 0.62), (0.5, 1), (0.38, 0.62), (0, 0.5), (0.38, 0.38)]
        var p = Path()
        p.move(to: CGPoint(x: r.minX + pts[0].0 * r.width, y: r.minY + pts[0].1 * r.height))
        for q in pts.dropFirst() { p.addLine(to: CGPoint(x: r.minX + q.0 * r.width, y: r.minY + q.1 * r.height)) }
        p.closeSubpath()
        return p
    }
}
