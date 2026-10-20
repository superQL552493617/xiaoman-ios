import SwiftUI
import PhotosUI
import UIKit

// MARK: - 编辑卡片（新建 / 编辑，按网页版复刻）

struct DesignerView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var purchases: Purchases
    @Environment(\.dismiss) private var dismiss

    let target: DesignerTarget

    @State private var c = Card(name: "")
    @State private var isNew = true
    @State private var loaded = false
    @State private var showIcons = false
    @State private var reminderEdit: ReminderEdit?
    @State private var newGroup = false
    @State private var newGroupName = ""
    @State private var showPause = false
    @FocusState private var nameFocused: Bool

    struct ReminderEdit: Identifiable { let id = UUID(); var index: Int? }

    private var saveLabel: String { isNew ? "创建打卡" : "保存" }

    var body: some View {
        VStack(spacing: 0) {
            bar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topCard.padding(.bottom, 22)
                    groupSection.padding(.bottom, 22)
                    reminderBox.padding(.bottom, 22)
                    daysSection.padding(.bottom, 22)
                    if !isNew { pauseButton.padding(.top, 6) }
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            Button { save() } label: { Text(saveLabel).frame(maxWidth: .infinity) }
                .buttonStyle(WarmButtonStyle())
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
        }
        .background(PT.bg.ignoresSafeArea())
        .onAppear(perform: load)
        .sheet(isPresented: $showIcons) {
            IconPickerSheet(card: $c)
                .environmentObject(purchases)
                .presentationDetents([.large])
                .presentationCornerRadius(30)
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $reminderEdit) { e in
            ReminderSheet(initial: e.index.flatMap { i in (c.reminders ?? []).indices.contains(i) ? c.reminders![i] : nil }) { r in
                var R = c.reminders ?? []
                if let i = e.index, R.indices.contains(i) { R[i] = r } else { R.append(r) }
                c.reminders = R
            } onDelete: {
                if let i = e.index { c.reminders?.remove(at: i) }
            }
            .presentationDetents([.large])
            .presentationCornerRadius(30)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPause) {
            PauseSheet(card: c) { from, to in
                store.pause(c.id, from: from, to: to)
                showPause = false
                toaster.show(to == nil ? "已暂停，可在「我的习惯」里手动恢复" : "已暂停到 \(DK.md(to!))，之后自动恢复")
            }
            .presentationDetents([.large])
            .presentationCornerRadius(30)
        }
        .alert("新建分组", isPresented: $newGroup) {
            TextField("分组名称", text: $newGroupName)
            Button("取消", role: .cancel) { newGroupName = "" }
            Button("添加") {
                let n = newGroupName.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { c.group = store.addGroup(n).id }
                newGroupName = ""
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let id = target.cardId, let old = store.s.card(id) {
            c = old; isNew = false
        } else {
            let pal = Theme.palette
            c = Card(name: "", hex: pal[(store.s.cards.count * 7) % pal.count], group: target.group)
        }
        // 截图测试用：-shotSub icons / reminder
        switch UserDefaults.standard.string(forKey: "shotSub") {
        case "icons": DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showIcons = true }
        case "reminder": DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { reminderEdit = ReminderEdit(index: nil) }
        default: break
        }
    }

    // MARK: 顶栏：放弃 · 编辑卡片 · 保存（下拉可关闭）

    private var bar: some View {
        ZStack {
            Text("编辑卡片").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body).padding(.bottom, 6)
            HStack {
                Button("放弃") { dismiss() }
                    .font(.system(size: 16)).foregroundStyle(WT.gray).padding(.horizontal, 4).frame(height: 38)
                Spacer()
                Button(saveLabel) { save() }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(WT.yellowInk)
                    .padding(.horizontal, 16).frame(height: 36)
                    .background(Capsule().fill(WT.yellow))
                    .overlay(Capsule().strokeBorder(WT.yellowInk, lineWidth: 1))
                    .compositingGroup()
                    .shadow(color: Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.4), radius: 8, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(height: 54)
    }

    // MARK: 图标 + 名称

    private var topCard: some View {
        HStack(spacing: 14) {
            Button { showIcons = true } label: {
                ProtoDot(card: c, on: true, shape: "circle", line: "solid", size: 58)
                    .overlay(alignment: .bottomTrailing) {
                        Image("ep_pen").renderingMode(.template).resizable().frame(width: 10, height: 10)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color(hex: "#1C1C1E")))
                            .overlay(Circle().stroke(Color(hex: "#F4F4F6"), lineWidth: 2))
                            .offset(x: 2, y: 2)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更换图标和颜色")
            VStack(alignment: .leading, spacing: 2) {
                Text(c.isNote ? "记录名称" : "打卡名称").font(.system(size: 12)).foregroundStyle(WT.gray)
                TextField(c.isNote ? "比如：今天的心得" : "输入打卡名称…", text: $c.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PT.body)
                    .focused($nameFocused)
                    .padding(.top, 5).padding(.bottom, 7)
                    .overlay(alignment: .bottom) { Rectangle().fill(WT.line).frame(height: 1) }
                    .onChange(of: c.name) { _, v in if v.count > 12 { c.name = String(v.prefix(12)) } }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(WT.card))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(WT.line, lineWidth: 1))
    }

    private func secHead(_ icon: String, _ bg: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Image(icon).renderingMode(.template).resizable().scaledToFit().frame(width: 16, height: 16)
                .foregroundStyle(Color(hex: "#4A3F45"))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: bg)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(hex: "#4A3F45"), lineWidth: 1))
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(WT.ink2)
        }
        .padding(.horizontal, 2).padding(.bottom, 10)
    }

    private func epCard<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        v().padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(WT.card))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(WT.line, lineWidth: 1))
    }

    // MARK: 所属分组

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            secHead("ep_group", "#FFE7A3", "所属分组")
            epCard {
                FlowLayout(spacing: 8) {
                    chip(store.s.ungroupedName, nil)
                    ForEach(store.s.groups) { g in chip(g.name, g.id) }
                    Button { newGroup = true } label: {
                        Text("＋ 新建分组").font(.system(size: 14)).foregroundStyle(WT.gray)
                            .padding(.horizontal, 14).frame(height: 34)
                            .overlay(Capsule().strokeBorder(Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.12), lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chip(_ name: String, _ id: String?) -> some View {
        let known = store.s.groups.contains { $0.id == c.group }
        let on = id == nil ? !known : c.group == id
        return Button { Feedback.tap(); c.group = id } label: {
            Text(name).font(.system(size: 14, weight: on ? .semibold : .regular)).foregroundStyle(Color(hex: "#1C1C1E"))
                .padding(.horizontal, 14).frame(height: 34)
                .background(Capsule().fill(on ? WT.orange : WT.chipOff))
        }
        .buttonStyle(.plain)
    }

    // MARK: 提醒

    @ViewBuilder private var reminderBox: some View {
        let list = c.reminders ?? []
        if list.isEmpty {
            Button { reminderEdit = ReminderEdit(index: nil) } label: {
                HStack(spacing: 12) {
                    Image("ep_alarm").renderingMode(.template).resizable().scaledToFit().frame(width: 17, height: 17)
                        .foregroundStyle(Color(hex: "#4A3F45"))
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: "#CFE6FA")))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(hex: "#4A3F45"), lineWidth: 1))
                    Text("添加提醒").font(.system(size: 15, weight: .semibold)).foregroundStyle(PT.body)
                    Spacer()
                    Text("›").font(.system(size: 22)).foregroundStyle(PT.muted)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(WT.card))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(WT.line, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.offset) { i, r in
                    HStack(spacing: 10) {
                        Image("ep_alarm").renderingMode(.template).resizable().frame(width: 17, height: 17)
                            .foregroundStyle(Color(hex: "#4A3F45"))
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: "#CFE6FA")))
                        Text(String(format: "%02d:%02d", r.h, r.m)).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(PT.body)
                        remChip(r.repShort)
                        remChip("闹钟")
                        Spacer()
                        Button {
                            Feedback.tap()
                            withAnimation(.easeOut(duration: 0.2)) { _ = c.reminders?.remove(at: i) }
                        } label: {
                            Image("dg_trash").renderingMode(.template).resizable().frame(width: 17, height: 17)
                                .foregroundStyle(PT.muted).frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("删除这条提醒")
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .onTapGesture { reminderEdit = ReminderEdit(index: i) }
                    Rectangle().fill(WT.line).frame(height: 1).padding(.leading, 56)
                }
                Button {
                    if list.count >= 5 { toaster.show("每张卡片最多 5 个提醒"); return }
                    reminderEdit = ReminderEdit(index: nil)
                } label: {
                    HStack(spacing: 10) {
                        Text("+").font(.system(size: 20, weight: .medium)).foregroundStyle(WT.gray).frame(width: 32)
                        Text("添加更多提醒").font(.system(size: 15)).foregroundStyle(WT.gray)
                        Spacer()
                        Text("›").font(.system(size: 22)).foregroundStyle(PT.muted)
                    }
                    .padding(.horizontal, 14).frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(WT.card))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(WT.line, lineWidth: 1))
        }
    }

    private func remChip(_ t: String) -> some View {
        Text(t).font(.system(size: 11.5, weight: .medium)).foregroundStyle(WT.ink2)
            .padding(.horizontal, 8).frame(height: 22)
            .background(Capsule().fill(Theme.adaptive("#F3EEE4", "#34322D")))
    }

    // MARK: 循环模式

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            secHead("ep_cal", "#FBD3D3", "循环模式")
            epCard {
                VStack(alignment: .leading, spacing: 10) {
                    weekGroup("工作日", [1, 2, 3, 4, 5])
                    weekGroup("周末", [6, 0])
                    Text("没有打勾的日子，打卡页不会显示这张卡片。").font(.system(size: 12)).foregroundStyle(WT.gray)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    private func weekGroup(_ title: String, _ days: [Int]) -> some View {
        let all = days.allSatisfy { c.days.contains($0) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.system(size: 13)).foregroundStyle(WT.gray)
                Spacer()
                Button(all ? "取消全选" : "全选") {
                    Feedback.tap()
                    if all { c.days.removeAll { days.contains($0) } } else { c.days = Array(Set(c.days + days)) }
                }
                .font(.system(size: 13, weight: .medium)).foregroundStyle(PT.ink)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { d in dayButton(d) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(WT.cream))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(WT.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private func dayButton(_ d: Int) -> some View {
        let on = c.days.contains(d)
        return Button {
            Feedback.tap()
            if on { c.days.removeAll { $0 == d } } else { c.days.append(d) }
        } label: {
            VStack(spacing: 6) {
                Text("周" + DK.wdName[d]).font(.system(size: 13, weight: .semibold))
                ZStack {
                    Circle().fill(on ? Color.white : Color.clear)
                    Circle().strokeBorder(on ? Color(hex: "#4A3F45") : Color(hex: "#C9C2B6"), lineWidth: 1.4)
                    if on {
                        Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(Color(hex: "#4A3F45"))
                    }
                }
                .frame(width: 17, height: 17)
            }
            .foregroundStyle(on ? Color(hex: "#2F4A36") : WT.gray)
            .frame(width: 48, height: 56)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Color(hex: "#D3EFD9") : WT.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Color(hex: "#4A3F45") : WT.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("周\(DK.wdName[d])，\(on ? "已选" : "未选")")
    }

    // MARK: 暂停习惯

    private var pauseButton: some View {
        let cur = store.s.card(c.id)
        let paused = cur.flatMap { store.s.activePause($0) } != nil
        let now = cur.map { store.s.pausedOn($0, DK.today) } ?? false
        return Button {
            Feedback.tap()
            if paused {
                store.resume(c.id)
                toaster.show(now ? "已恢复，今天起回到打卡主页" : "已取消计划中的暂停")
            } else {
                showPause = true
            }
        } label: {
            Text(paused ? (now ? "恢复习惯" : "取消暂停") : "暂停习惯")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(WT.pzInk)
                .frame(width: 180, height: 46)
                .background(Capsule().fill(Theme.adaptive("#F1EEF8", "#2C2933")))
        }
        .buttonStyle(.plain)
    }

    // MARK: 保存

    private func save() {
        let name = c.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { toaster.show("先写一个打卡名称吧"); nameFocused = true; return }
        guard c.isNote || !c.days.isEmpty else { toaster.show("循环模式里至少选择一天"); return }
        var x = c
        x.name = name
        if x.ic == "img" && x.icImg == nil { x.ic = "icon" }
        let offToday = !x.isNote && !x.days.contains(DK.weekday(DK.todayDate))
        let gName = store.s.groups.first { $0.id == x.group }?.name
        store.upsert(x)
        if !(x.reminders ?? []).isEmpty {
            Task { _ = await Notifier.shared.requestPermission(); Notifier.shared.rescheduleAll(store) }
        }
        Feedback.success()
        if isNew {
            toaster.show(offToday ? "已创建。今天不在循环日里，打卡页今天不会显示它" : gName.map { "已添加到“\($0)”" } ?? "打卡已创建")
        } else {
            toaster.show(offToday ? "已保存。今天不在循环日里，打卡页今天不会显示它" : "已保存")
        }
        dismiss()
    }
}

// MARK: - 图标与颜色

struct IconPickerSheet: View {
    @Binding var card: Card
    @EnvironmentObject var purchases: Purchases
    @Environment(\.dismiss) private var dismiss
    @State private var cat = 0
    @State private var custom = Color.orange
    @State private var photo: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Text("图标与颜色").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body).padding(.bottom, 6)
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Text("✓").font(.system(size: 15, weight: .bold)).foregroundStyle(WT.yellowInk)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(WT.yellow))
                                .overlay(Circle().strokeBorder(WT.yellowInk, lineWidth: 1))
                                .compositingGroup()
                                .shadow(color: Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.4), radius: 8, y: 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("完成")
                    }
                }
                .frame(height: 36).padding(.bottom, 14)

                ProtoDot(card: card, on: true, shape: "circle", line: "solid", size: 58)
                    .frame(maxWidth: .infinity).padding(.bottom, 18)

                label("图标风格")
                seg.padding(.bottom, 16)

                if card.ic == "text" { textBox.padding(.bottom, 16) }
                if card.ic == "img" { photoBox.padding(.bottom, 16) }

                HStack(spacing: 8) {
                    Text("颜色").font(.system(size: 13)).foregroundStyle(WT.gray)
                    Text("左右滑动查看更多").font(.system(size: 11)).foregroundStyle(PT.muted)
                }
                .padding(.horizontal, 6).padding(.bottom, 6)
                palette.padding(.bottom, 16)

                if card.ic == "icon" {
                    label("选择图标")
                    iconGrid
                }
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 24)
        }
        .background(PT.bg.ignoresSafeArea())
        .onAppear { custom = Color(hex: card.hex) }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: d) {
                    card.icImg = ImageData.base64(ui, maxSide: 240)
                    card.ic = "img"
                }
                photo = nil
            }
        }
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 13)).foregroundStyle(WT.gray).padding(.horizontal, 6).padding(.bottom, 6)
    }

    private var seg: some View {
        HStack(spacing: 0) {
            segBtn("icon", "图形")
            segBtn("text", "文字")
            segBtn("img", "相册", vip: true)
        }
        .padding(3)
        .background(Capsule().fill(Theme.adaptive("#F0F0F2", "#2A2A28")))
    }

    private func segBtn(_ id: String, _ t: String, vip: Bool = false) -> some View {
        let on = card.ic == id
        return Button {
            Feedback.tap()
            withAnimation(.easeOut(duration: 0.2)) { card.ic = id }
        } label: {
            HStack(spacing: 4) {
                Text(t).font(.system(size: 14, weight: on ? .semibold : .medium)).foregroundStyle(PT.body)
                if vip {
                    Text("VIP").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "#4A3000"))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.vipGold))
                }
            }
            .frame(maxWidth: .infinity).frame(height: 34)
            .background { if on { Capsule().fill(Theme.adaptive("#FFFFFF", "#3A3936")).shadow(color: .black.opacity(0.1), radius: 5, y: 3) } }
        }
        .buttonStyle(.plain)
    }

    private var textBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("1–2 个字", text: $card.text)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 14).frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.adaptive("#F4F4F6", "#2A2A28")))
                .onChange(of: card.text) { _, v in if v.count > 3 { card.text = String(v.prefix(3)) } }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach([("sys", "默认"), ("round", "圆体"), ("song", "宋体"), ("kai", "楷体"), ("mono", "等宽")], id: \.0) { f in
                        let on = (card.font ?? "sys") == f.0
                        Button { card.font = f.0 } label: {
                            Text(f.1).font(PT.cardFont(f.0, size: 14, weight: on ? .semibold : .regular))
                                .foregroundStyle(on ? .white : PT.body)
                                .padding(.horizontal, 14).frame(height: 32)
                                .background(Capsule().fill(on ? Color(hex: "#1C1C1E") : Theme.adaptive("#F0F0F2", "#2A2A28")))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var photoBox: some View {
        PhotosPicker(selection: $photo, matching: .images) {
            HStack {
                Image(systemName: "photo").font(.system(size: 16))
                Text(card.icImg == nil ? "从相册选一张照片" : "换一张照片").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(PT.body)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.adaptive("#F4F4F6", "#2A2A28")))
        }
    }

    /// 两行横向滑动的色块，第一个是自由取色
    private var palette: some View {
        let cols = stride(from: 0, to: Theme.palette.count, by: 2).map { i in Array(Theme.palette[i..<min(i + 2, Theme.palette.count)]) }
        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    VStack(spacing: 10) {
                        ColorPicker("", selection: $custom, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 38, height: 38)
                            .background(RoundedRectangle(cornerRadius: 11.4).fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center)))
                            .clipShape(RoundedRectangle(cornerRadius: 11.4))
                            .onChange(of: custom) { _, v in
                                let h = v.hexString
                                if h.uppercased() != card.hex.uppercased() { card.hex = h }
                            }
                        Color.clear.frame(width: 38, height: 38)
                    }
                    ForEach(cols.indices, id: \.self) { i in
                        VStack(spacing: 10) {
                            ForEach(cols[i], id: \.self) { h in swatch(h) }
                        }
                        .id(i)
                    }
                }
                .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -6)
            .onAppear {
                if let i = Theme.palette.firstIndex(where: { $0.uppercased() == card.hex.uppercased() }) { proxy.scrollTo(i / 2, anchor: .center) }
            }
        }
    }

    private func swatch(_ h: String) -> some View {
        let on = card.hex.uppercased() == h.uppercased()
        return Button { Feedback.tap(); card.hex = h; custom = Color(hex: h) } label: {
            RoundedRectangle(cornerRadius: 11.4, style: .continuous).fill(PT.vivid(h))
                .frame(width: 38, height: 38)
                .overlay(RoundedRectangle(cornerRadius: 11.4, style: .continuous).strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
                .overlay {
                    if on {
                        RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(PT.bg, lineWidth: 2.5).padding(-1.25)
                        RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color(hex: "#1C1C1E"), lineWidth: 2).padding(-3.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var iconGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(IconCatalog.categories.indices, id: \.self) { i in
                    Button { Feedback.tap(); cat = i } label: {
                        Text(IconCatalog.categories[i].name).font(.system(size: 15, weight: cat == i ? .bold : .medium))
                            .foregroundStyle(cat == i ? .white : PT.body)
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(cat == i ? Color(hex: "#1C1C1E") : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) { Rectangle().fill(WT.line).frame(height: 1).offset(y: 8) }
            let items = IconCatalog.categories[min(cat, IconCatalog.categories.count - 1)].items
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 14) {
                ForEach(items.indices, id: \.self) { j in
                    let it = items[j]
                    let on = card.icon == it.key
                    Button { Feedback.tap(); card.icon = it.key } label: {
                        Image(IconCatalog.assetName(it.key)).resizable().scaledToFit()
                            .frame(width: 52, height: 52)
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(on ? Color(hex: card.hex).opacity(0.22) : .clear))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? Color(hex: "#1C1C1E") : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(it.name)
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 添加 / 编辑提醒

struct ReminderSheet: View {
    var initial: Reminder?
    var onSave: (Reminder) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var r = Reminder(h: 21, m: 30)
    @State private var loaded = false

    private static let reps: [(id: String, name: String, days: [Int]?)] = [
        ("daily", "每天", [0, 1, 2, 3, 4, 5, 6]), ("work", "工作日", [1, 2, 3, 4, 5]), ("weekend", "周末", [6, 0]), ("custom", "自定义", nil)
    ]
    private static let tones: [(Int, String, String)] = [
        (1, "晨光", "四个音缓缓向上，像天慢慢亮起来"), (2, "水晶铃", "两声清亮的铃，余音很长"), (3, "八音盒", "一小段轻快的八音盒旋律"),
        (4, "竹林风", "几声随机的木质轻响，像风吹过竹林"), (5, "柔和马林巴", "三个圆润的音，最后轻轻一点"), (6, "呼吸", "和弦慢慢浮起再淡去，最安静"),
        (7, "竖琴", "一串轻快上行的竖琴音"), (8, "暖钢琴", "两个温暖的钢琴和弦"), (9, "颂钵", "一声低沉的颂钵，余音微微起伏"), (10, "萤火", "几点高音闪烁，带轻轻的回声")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(initial == nil ? "添加提醒" : "编辑提醒").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body).padding(.bottom, 6)
                HStack {
                    Button("取消") { dismiss() }.font(.system(size: 16)).foregroundStyle(WT.gray)
                    Spacer()
                    Button("完成") {
                        guard !(r.days ?? []).isEmpty else { return }
                        onSave(r); dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(hex: "#007AFF"))
                }
                .buttonStyle(.plain)
            }
            .frame(height: 38).padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Image("ep_alarm").renderingMode(.template).resizable().frame(width: 17, height: 17)
                            .foregroundStyle(PT.body)
                            .frame(width: 31, height: 36)
                            .background(Circle().fill(Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.14)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("闹钟提醒").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(hex: "#3E3532"))
                            Text("时间一到就响铃，手动关掉才会停，手机调成静音也能听到").font(.system(size: 12.5)).foregroundStyle(Color(hex: "#7D7366"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#FFF4D6")))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(hex: "#F2D58A"), lineWidth: 1.5))
                    Text("需要 iOS 26 及以上；更早的系统会改为普通通知提醒。").font(.system(size: 12)).foregroundStyle(WT.gray)
                        .padding(.horizontal, 6).padding(.top, 8)

                    lbl("提醒时间")
                    wheels

                    lbl("重复周期")
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            ForEach(Self.reps, id: \.id) { rep in
                                let on = (r.repeatMode ?? "daily") == rep.id
                                Button {
                                    Feedback.tap()
                                    r.repeatMode = rep.id
                                    if let d = rep.days { r.days = d }
                                } label: {
                                    Text(rep.name).font(.system(size: 14, weight: on ? .semibold : .medium))
                                        .foregroundStyle(on ? .white : PT.body)
                                        .frame(maxWidth: .infinity).frame(height: 40)
                                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? Color(hex: "#1C1C1E") : .clear))
                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? .clear : Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.12), lineWidth: 1.2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 14)
                        Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1)
                        Text("具体周几").font(.system(size: 13)).foregroundStyle(WT.gray).padding(.top, 12).padding(.bottom, 10).padding(.horizontal, 2)
                        HStack(spacing: 4) {
                            ForEach([1, 2, 3, 4, 5, 6, 0], id: \.self) { d in
                                let on = (r.days ?? []).contains(d)
                                Button {
                                    Feedback.tap()
                                    var D = r.days ?? []
                                    if on { D.removeAll { $0 == d } } else { D.append(d) }
                                    r.days = D
                                    let hit = Self.reps.first { rep in rep.days.map { Set($0) == Set(D) } ?? false }
                                    r.repeatMode = hit?.id ?? "custom"
                                } label: {
                                    Text("周" + DK.wdName[d]).font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(Color(hex: "#1C1C1E"))
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(on ? WT.orange : Theme.adaptive("#E8E8EC", "#3A3A3C")))
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.adaptive("#F4F4F6", "#262624")))

                    lbl("提示音")
                    VStack(spacing: 8) {
                        ForEach(Self.tones, id: \.0) { t in toneRow(t) }
                    }
                    if initial != nil {
                        Button("删除提醒") { onDelete(); dismiss() }
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(hex: "#E0525A"))
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "#E0525A").opacity(0.1)))
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 24)
            }
        }
        .background(PT.bg.ignoresSafeArea())
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if var i = initial {
                if i.days == nil { i.days = [0, 1, 2, 3, 4, 5, 6] }
                if i.repeatMode == nil { i.repeatMode = "daily" }
                if i.tone == nil { i.tone = 1 }
                r = i
            }
        }
    }

    private func lbl(_ t: String) -> some View {
        Text(t).font(.system(size: 14, weight: .semibold)).foregroundStyle(WT.gray).padding(.horizontal, 6).padding(.top, 20).padding(.bottom, 8)
    }

    private var wheels: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.adaptive("#F7F4EE", "#262624"))
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#33322F"))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.adaptive("#E8E0D2", "#45433E"), lineWidth: 1.5))
                .frame(width: 212, height: 48)
            HStack(spacing: 6) {
                WheelColumn(count: 24, value: $r.h)
                Text(":").font(.system(size: 28, weight: .bold)).foregroundStyle(Color(hex: "#3E3532")).offset(y: -2)
                WheelColumn(count: 60, value: $r.m)
            }
        }
        .frame(height: 200)
    }

    private func toneRow(_ t: (Int, String, String)) -> some View {
        let on = (r.tone ?? 1) == t.0
        return Button { Feedback.tap(); r.tone = t.0 } label: {
            HStack(spacing: 12) {
                Image(systemName: "music.note").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(on ? Color(hex: "#1C1C1E") : WT.gray)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(on ? WT.orange : Theme.adaptive("#F0F0F2", "#2F2E2B")))
                VStack(alignment: .leading, spacing: 0) {
                    Text(t.1).font(.system(size: 16)).foregroundStyle(PT.body)
                    Text(t.2).font(.system(size: 12)).foregroundStyle(WT.gray)
                }
                Spacer()
                Circle().strokeBorder(on ? WT.orange : PT.muted, lineWidth: on ? 7 : 1.6).frame(width: 22, height: 22)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(WT.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(WT.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// 网页版样式的滚轮：选中的数字大而深，其它淡色
struct WheelColumn: View {
    let count: Int
    @Binding var value: Int
    @State private var pos: Int?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    Text(String(format: "%02d", i))
                        .font(.system(size: i == value ? 30 : 19, weight: i == value ? .bold : .medium))
                        .foregroundStyle(i == value ? Color(hex: "#3E3532") : Color(hex: "#CBC3B6"))
                        .frame(width: 86, height: 40)
                        .id(i)
                        .onTapGesture { withAnimation { pos = i } }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.vertical, 80, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $pos, anchor: .center)
        .scrollIndicators(.hidden)
        .frame(width: 86, height: 200)
        .onAppear { pos = value }
        .onChange(of: pos) { _, p in if let p, p != value { value = p; Feedback.tap() } }
    }
}

extension Color {
    /// Color → "#RRGGBB"
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let cl = { (v: CGFloat) in Int((min(1, max(0, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", cl(r), cl(g), cl(b))
    }
}
