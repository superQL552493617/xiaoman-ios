import SwiftUI
import UniformTypeIdentifiers

/// color-mix(in srgb, a p, b)
func cmix(_ a: String, _ p: Double, _ b: String) -> Color { HexColor(a).mix(HexColor(b), 1 - p).color }

// MARK: - 我的习惯（按网页版复刻：两列彩色卡片、分组标签、整理批量删除、按住拖动换位置）

struct HabitsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var router: Router
    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject var purchases: Purchases
    @State private var grp = "all"
    @State private var pick: Set<String>?
    /// 编辑页由这里自己弹出：在「我的 → 习惯管理」里也能正常打开，关掉后不会再弹
    @State private var designer: DesignerTarget?
    @State private var confirmBatch = false
    @State private var dragging: String?

    private struct Sec: Identifiable { let id: String; let name: String; let cards: [Card] }

    private var all: [Card] { store.s.cards.filter { !$0.isNote } }

    private var secs: [Sec] {
        let known = Set(store.s.groups.map(\.id))
        let gid: (Card) -> String = { c in c.group.map { known.contains($0) ? $0 : "" } ?? "" }
        let list = store.s.groups.map { (id: $0.id, name: $0.name) } + [(id: "", name: store.s.ungroupedName)]
        return list.map { g in Sec(id: g.id, name: g.name, cards: all.filter { gid($0) == g.id }) }.filter { !$0.cards.isEmpty }
    }

    var body: some View {
        let S = secs
        let cur = grp == "all" || !S.contains { $0.id == grp } ? "all" : grp
        let shown = cur == "all" ? S : S.filter { $0.id == cur }
        let showHead = !store.s.groups.isEmpty
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    head
                    if !all.isEmpty && showHead { tabs(S, cur).padding(.bottom, 6) }
                    ForEach(shown) { g in
                        VStack(alignment: .leading, spacing: 0) {
                            if showHead && cur == "all" { secHead(g.name) }
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(g.cards) { c in tile(c) }
                            }
                        }
                    }
                    if store.s.cards.isEmpty {
                        Text("还没有习惯，点右上角的 + 新建一个吧。").font(.app(size: 14)).foregroundStyle(PT.faint)
                            .padding(.horizontal, 6).padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, pick == nil ? 130 : 200)
            }
            .scrollIndicators(.hidden)
            .background(PageBG().ignoresSafeArea())
            .onDrop(of: [UTType.text], isTargeted: nil) { _ in dragging = nil; store.save(); return true }

            if let P = pick { batchBar(P).padding(.bottom, 96).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: pick == nil)
        .onAppear {
            // 截图测试用：-shotHab menu / pick
            switch UserDefaults.standard.string(forKey: "shotHab") {
            case "edit": DispatchQueue.main.asyncAfter(deadline: .now() + 1) { designer = DesignerTarget(cardId: all.first?.id) }
            case "pick": pick = Set(all.prefix(1).map(\.id))
            default: break
            }
        }
        .sheet(item: $designer) { t in
            DesignerView(target: t)
                .environmentObject(store).environmentObject(toaster).environmentObject(router).environmentObject(purchases)
                .presentationDragIndicator(.visible)
        }
        .alert("删除 \(pick?.count ?? 0) 张卡片？", isPresented: $confirmBatch) {
            Button("删除", role: .destructive) {
                let ids = Array(pick ?? [])
                ids.forEach { store.deleteForever($0) }
                pick = nil
                toaster.show("已删除 \(ids.count) 张卡片")
            }
            Button("取消", role: .cancel) {}
        } message: {
            let names = (pick ?? []).compactMap { id in store.s.card(id)?.name }
            Text("\(names.prefix(3).joined(separator: "、"))\(names.count > 3 ? " 等" : "")会从所有日期里删除，打卡记录和日志也一起删除，不能恢复。")
        }
    }

    // MARK: 顶部：标题、整理、新建

    private var head: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(pick.map { "已选 \($0.count) 个" } ?? "我的习惯")
                    .font(.app(size: 26, weight: .heavy)).foregroundStyle(Theme.adaptive("#232326", "#F2EDE4"))
                    .contentTransition(.numericText())
                Text(pick == nil ? "\(all.count) 个习惯 · 按住可以拖动换位置" : "点一下选中，再点取消")
                    .font(.app(size: 12.5)).foregroundStyle(PT.faint)
            }
            Spacer(minLength: 0)
            Button {
                Feedback.tap()
                pick = pick == nil ? [] : nil
            } label: {
                Text(pick == nil ? "整理" : "完成").font(.app(size: 14, weight: .semibold))
                    .foregroundStyle(pick == nil ? Theme.adaptive("#5E544A", "#E5E0D6") : Theme.adaptive("#FFFFFF", "#1B1B1A"))
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(Capsule().fill(pick == nil ? Theme.adaptive("#F2EDE3", "#2F2E2B") : Theme.adaptive("#4A3F45", "#F2EDE4")))
            }
            .buttonStyle(PressScale())
            Button {
                pick = nil
                designer = DesignerTarget(group: ["all", ""].contains(grp) ? nil : grp)
            } label: {
                Image(systemName: "plus").font(.app(size: 17, weight: .medium)).foregroundStyle(Color(hex: "#4A3F45"))
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: "#FFE7A3")))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(hex: "#4A3F45"), lineWidth: 1.5))
            }
            .buttonStyle(PressScale())
            .accessibilityLabel("新建习惯")
        }
        .padding(.horizontal, 4).padding(.top, 14).padding(.bottom, 10)
    }

    // MARK: 分组标签（选中的下面有一条绿色短线）

    private func tabs(_ S: [Sec], _ cur: String) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 18) {
                tabChip("全部", "all", nil, cur)
                ForEach(S) { g in tabChip(g.name, g.id, g.cards.count, cur) }
            }
            .padding(.horizontal, 4).padding(.top, 2).padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) {
            Line().stroke(Theme.adaptive("#E8E0D2", "#3A3732"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])).frame(height: 1.5)
        }
    }

    private func tabChip(_ name: String, _ id: String, _ n: Int?, _ cur: String) -> some View {
        let on = cur == id
        return Button {
            Feedback.tap()
            withAnimation(.easeOut(duration: 0.2)) { grp = id }
        } label: {
            HStack(alignment: .top, spacing: 2) {
                Text(name).font(.app(size: 15, weight: .semibold))
                if let n { Text("\(n)").font(.app(size: 10, weight: .semibold)).opacity(0.8).offset(y: -1) }
            }
            .foregroundStyle(on ? Theme.adaptive("#3E3532", "#F2EDE4") : Color(hex: "#A39888"))
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) {
                if on {
                    GeometryReader { geo in
                        Capsule().fill(Theme.adaptive("#BFE3C9", "#4A6640"))
                            .frame(width: geo.size.width * 0.8, height: 4)
                            .position(x: geo.size.width / 2, y: geo.size.height + 1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func secHead(_ t: String) -> some View {
        HStack(spacing: 8) {
            Text(t).font(.app(size: 13, weight: .bold)).foregroundStyle(Color(hex: "#8F857A"))
            Rectangle().fill(Theme.adaptive("#EDE6DA", "#33312D")).frame(height: 1)
        }
        .padding(.horizontal, 4).padding(.top, 14).padding(.bottom, 8)
    }

    // MARK: 一张习惯卡

    private func tile(_ c: Card) -> some View {
        let picked = pick?.contains(c.id) == true
        return HabitTileProto(card: c, picking: pick != nil, picked: picked) {
            store.resume(c.id)
            Feedback.tap()
            toaster.show("已恢复，今天起回到打卡主页")
        }
        .onTapGesture {
            if var P = pick {
                if P.contains(c.id) { P.remove(c.id) } else { P.insert(c.id) }
                pick = P
                Feedback.tap()
            } else {
                designer = DesignerTarget(cardId: c.id)
            }
        }
        .onDrag {
            dragging = c.id
            Feedback.tap()
            return NSItemProvider(object: c.id as NSString)
        } preview: {
            HabitTileProto(card: c, picking: false, picked: false, onResume: {})
                .frame(width: 179).environmentObject(store)
        }
        .onDrop(of: [UTType.text], delegate: TileDrop(target: c, store: store, dragging: $dragging, enabled: pick == nil))
    }

    // MARK: 整理时底部的「全选 / 删除」

    private func batchBar(_ P: Set<String>) -> some View {
        let allIds = Set(all.map(\.id))
        return HStack {
            Button(P.count == allIds.count && !allIds.isEmpty ? "取消全选" : "全选") {
                Feedback.tap()
                pick = P.count == allIds.count ? [] : allIds
            }
            .font(.app(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "#007AFF"))
            Spacer()
            Button { if !P.isEmpty { confirmBatch = true } } label: {
                Text(P.isEmpty ? "删除" : "删除 (\(P.count))").font(.app(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).frame(height: 38)
                    .background(Capsule().fill(Color(hex: "#FF3B30")))
            }
            .opacity(P.isEmpty ? 0.4 : 1)
            .disabled(P.isEmpty)
        }
        .buttonStyle(.plain)
        .padding(.leading, 16).padding(.trailing, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .padding(.horizontal, 16)
    }
}

private struct Line: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.width, y: r.midY)); return p }
}

/// 按下时缩一点
struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? scale : 1).animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 按住拖动换位置
private struct TileDrop: DropDelegate {
    let target: Card
    let store: Store
    @Binding var dragging: String?
    var enabled: Bool

    func validateDrop(info: DropInfo) -> Bool { enabled && dragging != nil }
    func dropEntered(info: DropInfo) {
        guard enabled, let d = dragging, d != target.id,
              let from = store.s.cards.firstIndex(where: { $0.id == d }),
              let to = store.s.cards.firstIndex(where: { $0.id == target.id }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            var c = store.s.cards.remove(at: from)
            c.group = target.group
            store.s.cards.insert(c, at: from < to ? min(to, store.s.cards.count) : to)
        }
        Feedback.tap()
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        store.save()
        return true
    }
}

// MARK: - 习惯卡片本体

struct HabitTileProto: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var scheme
    let card: Card
    var picking: Bool
    var picked: Bool
    var onResume: () -> Void

    private var dark: Bool { scheme == .dark }

    var body: some View {
        let c = card
        let b = c.hex
        let hs = store.s.habitStats(c)
        let ap = store.s.activePause(c)
        let apNow = store.s.pausedOn(c, DK.today)
        let dots = store.s.last7(c)
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top) {
                ProtoDot(card: c, on: true, shape: "circle", line: "solid", size: 42)
                    .shadow(color: Color(hex: b).opacity(0.4), radius: 3, y: 4)
                Spacer(minLength: 0)
                if picking {
                    ZStack {
                        Circle().strokeBorder(Color(hex: "#CFC6B8"), lineWidth: 2).opacity(picked ? 0 : 1)
                        if picked {
                            Circle().fill(Color(hex: "#4A3F45"))
                            Image(systemName: "checkmark").font(.app(size: 10, weight: .heavy)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .padding(3)
                } else if ap != nil {
                    // 暂停中的卡片：右上角一个小小的「恢复」，卡片高度和其它卡片一样
                    Button(action: onResume) {
                        Text(apNow ? "恢复" : "取消暂停").font(.app(size: 12, weight: .bold))
                            .foregroundStyle(Theme.adaptive("#4A453F", "#E5E0D6"))
                            .padding(.horizontal, 10).frame(height: 26)
                            .background(Capsule().fill(Theme.adaptive("#FFFFFF", "#2F2E2B")))
                            .overlay(Capsule().strokeBorder(Theme.adaptive("#CFC9BF", "#4A4741"), lineWidth: 1.2))
                    }
                    .buttonStyle(PressScale())
                    .grayscale(0)
                }
            }
            .padding(.bottom, 6)
            Text(c.name).font(PT.cardFont(c.font, size: 16, weight: .bold))
                .foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4")).lineLimit(1)
                .padding(.top, 2)
            Text(sub(c, ap, apNow)).font(.app(size: 11.5, weight: ap != nil ? .semibold : .regular))
                .foregroundStyle(ap != nil ? Color(hex: "#8C877F") : Color(hex: "#A39888")).lineLimit(1)
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        Circle()
                            .fill(dots[i] ? PT.vivid(b) : (dark ? Color.white.opacity(0.12) : Color.white.opacity(0.75)))
                            .overlay { if !dots[i] && !dark { Circle().strokeBorder(Color(hex: b).opacity(0.25), lineWidth: 1) } }
                            .overlay { if dots[i] { Circle().fill(LinearGradient(colors: [.clear, .black.opacity(0.12)], startPoint: UnitPoint(x: 0.5, y: 0.8), endPoint: .bottom)) } }
                            .frame(width: 12, height: 12)
                    }
                }
                Spacer(minLength: 0)
                Text("\(hs.w7)/7").font(.app(size: 11, weight: .bold)).monospacedDigit()
                    .foregroundStyle(cmix(b, 0.55, "#5E554C"))
            }
            .padding(.top, 10)
            stats(hs, b).padding(.top, 12)
            Text("\(hs.best > 1 ? "最长连续 \(hs.best) 天 · " : "")上次 \(hs.last)")
                .font(.app(size: 10.5)).foregroundStyle(cmix(b, 0.35, "#8F857A")).lineLimit(1)
                .padding(.top, 8)
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { bg(b, paused: apNow) }
        .grayscale(apNow ? 1 : 0)
        .opacity(apNow ? (dark ? 0.7 : 0.85) : 1)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func sub(_ c: Card, _ ap: Pause?, _ apNow: Bool) -> String {
        let T = DK.today
        if let ap {
            if apNow {
                let end = ap.until.map { DK.md(DK.addKey($0, -1)) }
                let lbl = ap.from > T ? "\(DK.md(ap.from))起暂停\(end.map { "，至" + $0 } ?? "")" : (end.map { "暂停至" + $0 } ?? "手动恢复")
                return "已暂停 · " + lbl
            }
            if let u = ap.until {
                let to = DK.addKey(u, -1)
                return "计划暂停 · " + (ap.from == to ? DK.md(ap.from) : "\(DK.md(ap.from)) – \(DK.md(to))")
            }
            return "计划暂停 · \(DK.md(ap.from))起"
        }
        if let r = c.reminders?.first { return "\(r.repShort) " + String(format: "%02d:%02d", r.h, r.m) }
        return store.s.daysLabel(c)
    }

    private func stats(_ hs: HabitStats, _ b: String) -> some View {
        let sep = dark ? Color(hex: "#34322E") : cmix(b, 0.18, "#EFE8DC")
        return HStack(spacing: 0) {
            stat(Text("\(hs.cur)"), "连续天", color: dark ? cmix(b, 0.7, "#F2EDE4") : cmix(b, 0.7, "#3E3532"))
            sep.frame(width: 1, height: 34)
            stat(hs.rate.map { Text("\($0)") + Text("%").font(.app(size: 10.5, weight: .heavy)) } ?? Text("—"), "本月",
                 color: Theme.adaptive("#3E3532", "#F2EDE4"))
            sep.frame(width: 1, height: 34)
            stat(Text("\(hs.total)"), "累计天", color: Theme.adaptive("#3E3532", "#F2EDE4"))
        }
        .padding(.vertical, 8).padding(.horizontal, 2)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(dark ? Color.white.opacity(0.05) : Color.white.opacity(0.62)))
        .overlay { if !dark { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.8), lineWidth: 1) } }
    }

    private func stat(_ v: Text, _ l: String, color: Color) -> some View {
        VStack(spacing: 1) {
            v.font(.app(size: 16, weight: .heavy)).monospacedDigit().foregroundStyle(color)
            Text(l).font(.app(size: 10.5)).foregroundStyle(Color(hex: "#A39888"))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func bg(_ b: String, paused: Bool) -> some View {
        let r = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let vb = HexColor(b).vivid.hex
        if dark {
            r.fill(Color(hex: "#0C0C0C")).overlay(r.strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        } else if paused {
            r.fill(LinearGradient(colors: [Color(hex: "#F1EFEB"), Color(hex: "#E9E6E0")], startPoint: UnitPoint(x: 0.37, y: 0), endPoint: UnitPoint(x: 0.63, y: 1)))
                .overlay(r.strokeBorder(Color(hex: "#E4E0D8"), lineWidth: 1))
        } else {
            ZStack {
                // 0 16px 30px -20px 的彩色阴影：缩小的同形状 + 模糊
                r.fill(cmix(b, 0.8, "#28200A").opacity(0.85))
                    .padding(.horizontal, 20).padding(.vertical, 20)
                    .offset(y: 16)
                    .blur(radius: 15)
                // 最浓的地方接近图标本身的颜色，往下慢慢变淡
                r.fill(LinearGradient(stops: [
                    .init(color: cmix(vb, 0.66, "#FFFFFF"), location: 0),
                    .init(color: cmix(vb, 0.40, "#FFFFFF"), location: 0.38),
                    .init(color: cmix(vb, 0.16, "#FFFFFF"), location: 1)
                ], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(red: 60/255, green: 40/255, blue: 10/255).opacity(0.12), radius: 3, y: 2)
                r.strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
            }
        }
    }
}

// MARK: - 整理：拖动排序、分组管理（「我的」里的习惯管理用）

struct OrganizeSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @Environment(\.dismiss) private var dismiss
    @State private var newGroup = ""
    @State private var renaming: HabitGroup?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.s.groups) { g in
                        HStack {
                            Text(g.name).foregroundStyle(Theme.text)
                            Spacer()
                            Text("\(store.s.cards.filter { $0.group == g.id }.count) 个").font(.app(size: 13)).foregroundStyle(Theme.text3)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { renaming = g; renameText = g.name }
                    }
                    .onDelete { idx in
                        for i in idx { store.deleteGroup(store.s.groups[i].id) }
                    }
                    .onMove { from, to in store.s.groups.move(fromOffsets: from, toOffset: to); store.save() }
                    HStack {
                        TextField("新分组名称", text: $newGroup)
                        Button("添加") {
                            let n = newGroup.trimmingCharacters(in: .whitespaces)
                            guard !n.isEmpty else { return }
                            _ = store.addGroup(n)
                            newGroup = ""
                            Feedback.tap()
                        }
                        .disabled(newGroup.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: { Text("分组（点名称可改名，左滑删除）") }

                Section {
                    ForEach(store.s.cards) { c in
                        HStack(spacing: 10) {
                            HabitCircle(card: c, checked: true, size: 30)
                            Text(c.name).foregroundStyle(Theme.text)
                            Spacer()
                            Text(groupName(c)).font(.app(size: 12.5)).foregroundStyle(Theme.text3)
                        }
                    }
                    .onMove { from, to in store.s.cards.move(fromOffsets: from, toOffset: to); store.save() }
                } header: { Text("习惯顺序（按住右侧拖动）") }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("整理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.fontWeight(.bold) }
            }
            .alert("修改分组名称", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("名称", text: $renameText)
                Button("取消", role: .cancel) { renaming = nil }
                Button("保存") {
                    let n = renameText.trimmingCharacters(in: .whitespaces)
                    if let g = renaming, !n.isEmpty { store.renameGroup(g.id, n) }
                    renaming = nil
                }
            }
        }
    }

    private func groupName(_ c: Card) -> String {
        store.s.groups.first { $0.id == c.group }?.name ?? store.s.ungroupedName
    }
}
