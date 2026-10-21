import SwiftUI

// MARK: - 网页版暖色系（弹窗、编辑页共用）

enum WT {
    static let ink = Theme.adaptive("#2E2A27", "#F2EDE4")
    static let ink2 = Theme.adaptive("#5B4F45", "#CFC6BA")
    static let brown = Theme.adaptive("#8A7F6E", "#A39888")
    static let line = Theme.adaptive("#EEE7DA", "#3A3732")
    static let tabsBg = Theme.adaptive("#EFE9DD", "#2F2D2A")
    static let card = Theme.adaptive("#FFFFFF", "#262624")
    static let stroke = Theme.adaptive("#4A3F45", "#8C8178")
    static let yellow = Color(hex: "#FFE7A3")
    static let yellowInk = Color(hex: "#4A3F45")
    static let red = Color(hex: "#C9463D")
    static let gray = Theme.adaptive("#5E5E66", "#A1A1A6")
    static let chipOff = Theme.adaptive("#7676801A", "#FFFFFF1F")
    static let orange = Color(hex: "#F4B63F")
    static let pzBg = Theme.adaptive("#F4F1FA", "#2C2933")
    static let pzInk = Theme.adaptive("#5E5470", "#C9C0DA")
    static let pzDeep = Theme.adaptive("#3E3460", "#E3DCF5")
    static let cream = Theme.adaptive("#FBF8F2", "#2A2925")
}

/// 黄色主按钮（确认 / 保存 / 创建打卡）
struct WarmButtonStyle: ButtonStyle {
    var height: CGFloat = 46
    var radius: CGFloat = 18
    var size: CGFloat = 15
    var weight: Font.Weight = .semibold
    var disabled = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(size: size, weight: weight))
            .foregroundStyle(disabled ? Color(hex: "#9A9AA3") : WT.yellowInk)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(disabled ? Color(hex: "#EEEEF0") : WT.yellow))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(disabled ? Color(hex: "#D6D6DA") : WT.yellowInk, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

// MARK: - 点已完成的卡片：居中的打卡弹窗（完成打卡 / 取消打卡 / 暂停习惯）

struct CheckDialogOverlay: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var router: Router
    @Environment(\.colorScheme) private var scheme

    let cardId: String
    let day: String
    var top: CGFloat
    var onClose: () -> Void

    @State private var mode = "done"
    @State private var note = ""
    @State private var range: (from: String, to: String?)?
    @State private var shown = false
    @State private var opened = Date()
    @State private var confirmDelete = false
    @State private var fullEditor = false
    @State private var shake = 0
    @FocusState private var focused: Bool

    private var card: Card? { store.s.cardAny(cardId) }
    private var archived: Bool { store.s.card(cardId) == nil }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.16, green: 0.13, blue: 0.08).opacity(shown ? 0.28 : 0)
                .ignoresSafeArea()
                .onTapGesture { if Date().timeIntervalSince(opened) > 0.45 { close(apply: true) } }
            if let c = card {
                ScrollView {
                    dialog(c)
                        .padding(.horizontal, 21)
                        .padding(.top, top)
                        .padding(.bottom, 20)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .scaleEffect(shown ? 1 : 0.96)
                .opacity(shown ? 1 : 0)
            }
        }
        .onAppear {
            note = store.s.rec(day, cardId)?.note ?? ""
            if let m = UserDefaults.standard.string(forKey: "shotDlg"), ["done", "undo", "pause"].contains(m) { mode = m }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { shown = true }
        }
        .sheet(isPresented: $confirmDelete) {
            DeleteHabitSheet(name: card?.name ?? "") {
                confirmDelete = false
                close(apply: false) {
                    store.archive(cardId)
                    toaster.show("习惯已删除")
                }
            } onCancel: { confirmDelete = false }
            .presentationDetents([.height(290)])
            .presentationCornerRadius(30)
        }
        .fullScreenCover(isPresented: $fullEditor) {
            FullLogEditor(title: card?.name ?? "", text: $note) {
                fullEditor = false
                store.setNote(cardId, on: day, note)
            }
        }
    }

    private func dialog(_ c: Card) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            head(c).padding(.leading, 2).padding(.bottom, 14)
            tabs.padding(.horizontal, 2)
            if mode == "pause" {
                pauseBox.padding(.horizontal, 2).padding(.top, 10)
            } else {
                Text("打卡日志").font(.app(size: 14, weight: .bold)).foregroundStyle(WT.brown)
                    .padding(.leading, 6).padding(.top, 16).padding(.bottom, 6)
                ZStack(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("添加打卡日志…").font(.app(size: 16.4)).foregroundStyle(Color(hex: "#B5AEA4"))
                            .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    TextEditor(text: $note)
                        .font(PT.cardFont(c.font, size: 16.4, weight: .regular))
                        .foregroundStyle(Theme.adaptive("#2A2A28", "#F2EDE4"))
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .onChange(of: note) { _, v in
                            if v.count > 5000 { note = String(v.prefix(5000)) }
                            store.setNote(cardId, on: day, note)
                        }
                }
                .frame(height: 174)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(WT.card))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(WT.line, lineWidth: 1))
                .padding(.horizontal, 2)
                HStack {
                    if note.count >= 4000 { Text("\(note.count) / 5000").font(.app(size: 9)).foregroundStyle(PT.muted) }
                    Spacer()
                    Button { fullEditor = true } label: {
                        HStack(spacing: 4) {
                            Image("dg_full").renderingMode(.template).resizable().frame(width: 12, height: 12)
                            Text("全屏").font(.app(size: 14, weight: .medium))
                        }
                        .foregroundStyle(WT.brown).padding(.horizontal, 4).frame(height: 30)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4).padding(.horizontal, 6)
            }
            foot.padding(.top, 12).padding(.horizontal, 2)
        }
        .padding(.top, 16).padding(.horizontal, 16).padding(.bottom, 14)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(WT.card))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(WT.line, lineWidth: 1))
        .compositingGroup()
        .shadow(color: Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.35), radius: 20, y: 18)
    }

    private func head(_ c: Card) -> some View {
        let rec = store.s.rec(day, cardId)
        let t = (rec?.t).flatMap { $0 > 1e12 ? Date(timeIntervalSince1970: $0 / 1000) : nil } ?? Date()
        let comps = DK.calendar.dateComponents([.hour, .minute], from: t)
        let d = DK.date(day)
        return HStack(spacing: 10) {
            ProtoDot(card: c, on: true, shape: "circle", line: "solid", size: 46)
            Text(c.name).font(PT.cardFont(c.font, size: 19, weight: .bold)).foregroundStyle(WT.ink).lineLimit(1)
                .overlay(alignment: .trailing) {
                    if archived {
                        Text("已删除").font(.app(size: 11, weight: .semibold)).foregroundStyle(WT.brown).offset(x: 46)
                    }
                }
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                Image("dg_cal").resizable().frame(width: 20, height: 20)
                Text("\(DK.month(d))月\(DK.day(d))日  \(String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0))")
                    .font(.app(size: 13.5, weight: .semibold)).foregroundStyle(Color(hex: "#1C1C1E"))
            }
            .padding(.leading, 8).padding(.trailing, 12).frame(height: 34)
            .background(Capsule().fill(Color(hex: "#D3EFD9")))
            .overlay(Capsule().strokeBorder(Color(hex: "#4A3F45"), lineWidth: 1))
        }
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            tab("done", "dg_done", "完成打卡")
            tab("undo", "dg_undo", "取消打卡")
            if !archived { tab("pause", "dg_pause", "暂停习惯") }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(WT.tabsBg))
    }

    private func tab(_ id: String, _ icon: String, _ title: String) -> some View {
        let on = mode == id
        return Button {
            Feedback.tap()
            focused = false
            withAnimation(.easeOut(duration: 0.2)) { mode = id }
        } label: {
            HStack(spacing: 4) {
                Image(icon).resizable().frame(width: 19, height: 19)
                Text(title).font(.app(size: 14, weight: .semibold))
            }
            .foregroundStyle(on ? WT.ink : WT.brown)
            .frame(maxWidth: .infinity).frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? WT.card : .clear))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? WT.stroke : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var pauseBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("暂停期间，该习惯不出现在打卡主页，也不计入应打卡次数和完成率，可自定义恢复时间或在「我的习惯」中手动恢复。")
                .font(.app(size: 13)).foregroundStyle(WT.pzInk).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            RangeCalendar(from: DK.today) { r in range = r }
                .modifier(Shake(trigger: shake))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(WT.pzBg))
    }

    private var foot: some View {
        let needRange = mode == "pause" && range == nil
        return HStack(spacing: 8) {
            if !archived {
                Button { confirmDelete = true } label: {
                    footAct("dg_trash", "删除习惯", WT.red)
                }
                .buttonStyle(.plain)
                Button {
                    close(apply: true) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { router.designer = DesignerTarget(cardId: cardId) }
                    }
                } label: {
                    footAct("dg_edit", "编辑习惯", WT.ink2)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Button {
                if needRange {
                    Feedback.warn()
                    toaster.show("请选择结束日期，或打开「手动恢复」", gray: true)
                    shake += 1
                    return
                }
                close(apply: true)
            } label: {
                Text("确认").padding(.horizontal, 16)
            }
            .buttonStyle(WarmButtonStyle(height: 46, radius: 15, size: 16, weight: .bold, disabled: needRange))
        }
    }

    private func footAct(_ icon: String, _ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(icon).renderingMode(.template).resizable().frame(width: 17, height: 17)
            Text(title).font(.app(size: 13.5, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).frame(height: 42)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(WT.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(WT.line, lineWidth: 1))
    }

    private func close(apply: Bool, then: (() -> Void)? = nil) {
        focused = false
        if apply {
            if mode == "pause", let r = range {
                store.pause(cardId, from: r.from, to: r.to)
                let msg = r.to == nil ? "已暂停，可在「我的习惯」里手动恢复" : "已暂停到 \(DK.md(r.to!))，之后自动恢复"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { toaster.show(msg) }
            } else if mode == "undo" {
                store.setChecked(cardId, on: day, false)
                Feedback.uncheck()
                if store.s.rec(day, cardId)?.hasNote == true { toaster.show("已取消，备注会保留到你重新打卡") }
            }
        }
        withAnimation(.easeIn(duration: 0.2)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onClose()
            then?()
        }
    }
}

/// 轻轻抖一下（提醒还没选结束日期）
struct Shake: ViewModifier {
    var trigger: Int
    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { v, s in v.scaleEffect(s) } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.04, duration: 0.18)
                CubicKeyframe(1.0, duration: 0.18)
            }
        }
    }
}

// MARK: - 选择暂停的结束日期：月历 + 手动恢复

struct RangeCalendar: View {
    let from: String
    var onChange: ((from: String, to: String?)?) -> Void

    @State private var month = DK.monthStart(DK.todayDate)
    @State private var end: String?
    @State private var manual = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            (Text("从 ") + Text(from == DK.today ? "今天" : DK.md(from)).fontWeight(.semibold).foregroundColor(WT.pzDeep)
             + Text(" 开始暂停。再点一个结束日期，或者不选结束日期、点「手动恢复」"))
                .font(.app(size: 12.5)).foregroundStyle(Theme.adaptive("#5E554C", "#CFC6BA")).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
            HStack(spacing: 6) {
                legend(Color(hex: "#FCE7A6"), Color(hex: "#E9C25A"), "开始")
                legend(Color(hex: "#CDEBC6"), Color(hex: "#8DC283"), "结束").padding(.leading, 8)
            }
            .padding(.bottom, 10)
            HStack {
                navBtn("‹", enabled: month > DK.monthStart(DK.date(from))) { shift(-1) }
                Spacer()
                Text(verbatim: "\(DK.year(month))年\(DK.month(month))月").font(.app(size: 15.5, weight: .bold)).foregroundStyle(WT.pzDeep)
                Spacer()
                navBtn("›", enabled: true) { shift(1) }
            }
            .padding(.horizontal, 4).padding(.bottom, 4)
            HStack(spacing: 0) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                    Text(w).font(.app(size: 11.5)).foregroundStyle(Color(hex: "#A39888")).frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 2).padding(.bottom, 6)
            let lead = (DK.weekday(month) + 6) % 7
            let n = DK.daysInMonth(month)
            let cells: [String?] = Array(repeating: nil, count: lead) + (0..<n).map { DK.key(DK.add(month, $0)) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(cells.indices, id: \.self) { i in
                    if let k = cells[i] { dayCell(k) } else { Color.clear.frame(height: 32) }
                }
            }
            Rectangle().fill(WT.line).frame(height: 1).padding(.top, 8).padding(.horizontal, 6)
            Button {
                Feedback.tap()
                manual.toggle()
                if manual { end = nil }
                emit()
            } label: {
                Text("手动恢复").font(.app(size: 13, weight: .semibold))
                    .foregroundStyle(manual ? .white : WT.pzInk)
                    .padding(.horizontal, 14).frame(height: 30)
                    .background(Capsule().fill(manual ? Color(hex: "#7C6FA8") : Theme.adaptive("#EFEDF3", "#3A3644")))
                    .overlay(Capsule().strokeBorder(manual ? .clear : Theme.adaptive("#DCD6E6", "#4A4556"), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .padding(.top, 10).padding(.horizontal, 8).padding(.bottom, 8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(WT.card))
    }

    private func legend(_ fill: Color, _ ring: Color, _ t: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(fill).frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(ring, lineWidth: 1))
            Text(t).font(.app(size: 11.5)).foregroundStyle(Color(hex: "#A39888"))
        }
    }

    private func navBtn(_ t: String, enabled: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.app(size: 22)).foregroundStyle(Color(hex: "#5E544A")).frame(width: 34, height: 34)
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.25)
    }

    private func shift(_ d: Int) {
        if let m = DK.calendar.date(byAdding: .month, value: d, to: month) { withAnimation(.easeOut(duration: 0.2)) { month = m } }
    }

    @ViewBuilder private func dayCell(_ k: String) -> some View {
        let isStart = k == from, isEnd = k == end
        let inside = end.map { k > from && k < $0 } ?? false
        let past = k < from
        Button {
            guard !past, k != from else { return }
            Feedback.tap()
            end = (end == k) ? nil : k
            if end != nil { manual = false }
            emit()
        } label: {
            Text("\(DK.day(DK.date(k)))")
                .font(.app(size: 14, weight: isStart ? .heavy : (isEnd ? .bold : .regular)))
                .foregroundStyle(past ? Color(hex: "#D6CEC0") : isStart ? Color(hex: "#5A4410") : isEnd ? Color(hex: "#2F5A27") : Theme.adaptive("#3E3532", "#F2EDE4"))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isStart ? Color(hex: "#FCE7A6") : isEnd ? Color(hex: "#CDEBC6") : inside ? Color(hex: "#EEF7EA") : .clear))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isStart ? Color(hex: "#E9C25A") : isEnd ? Color(hex: "#8DC283") : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 1)
    }

    private func emit() {
        if let e = end { onChange((from, e)) }
        else if manual { onChange((from, nil)) }
        else { onChange(nil) }
    }
}

// MARK: - 删除确认（底部弹出）

struct DeleteHabitSheet: View {
    let name: String
    var onDelete: () -> Void
    var onCancel: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Text("删除习惯「\(name)」？").font(.app(size: 17, weight: .bold)).foregroundStyle(WT.ink)
                .multilineTextAlignment(.center).padding(.top, 26).padding(.bottom, 8)
            Text("删除后这张卡片不再出现在打卡页，以前的打卡记录和日志会保留在统计里。")
                .font(.app(size: 14)).foregroundStyle(WT.gray).lineSpacing(4).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6).padding(.bottom, 18)
            Button { onDelete() } label: {
                Text("删除").font(.app(size: 16.5, weight: .semibold)).foregroundStyle(Color(hex: "#C9463D"))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "#FBD3D3")))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(hex: "#C9463D"), lineWidth: 1.5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScale(scale: 0.98))
            Button { onCancel() } label: {
                Text("取消").font(.app(size: 16.5, weight: .semibold)).foregroundStyle(Theme.adaptive("#5B4F45", "#E8E0D2"))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#2C2A26")))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.adaptive("#EEE7DA", "#3A3732"), lineWidth: 1.5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScale(scale: 0.98))
            .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.adaptive("#FBFAF8", "#1E1E1D").ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}

// MARK: - 全屏写打卡日志

struct FullLogEditor: View {
    let title: String
    @Binding var text: String
    var onDone: () -> Void
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.app(size: 17, weight: .bold)).foregroundStyle(WT.ink)
                Spacer()
                Button("完成", action: onDone).font(.app(size: 16, weight: .semibold)).foregroundStyle(Color(hex: "#007AFF"))
            }
            .padding(.horizontal, 18).frame(height: 54)
            TextEditor(text: $text)
                .font(.app(size: 17)).lineSpacing(6)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .padding(.horizontal, 14)
        }
        .background(Theme.adaptive("#FBF8F2", "#2B2925").ignoresSafeArea())
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true } }
    }
}

// MARK: - 旧的暂停弹窗（编辑页「暂停习惯」用，内容同上）

struct PauseSheet: View {
    let card: Card
    var onConfirm: (_ from: String, _ to: String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var range: (from: String, to: String?)?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { dismiss() }.foregroundStyle(WT.gray)
                Spacer()
                Text("暂停习惯").font(.app(size: 17, weight: .bold)).foregroundStyle(WT.ink)
                Spacer()
                Button("确定") { if let r = range { onConfirm(r.from, r.to) } }
                    .font(.app(size: 16, weight: .semibold))
                    .foregroundStyle(range == nil ? PT.faint : Color(hex: "#007AFF"))
                    .disabled(range == nil)
            }
            .padding(.horizontal, 18).frame(height: 54)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("暂停期间，该习惯不出现在打卡主页，也不计入应打卡次数和完成率，可自定义恢复时间或在「我的习惯」中手动恢复。")
                        .font(.app(size: 13)).foregroundStyle(WT.pzInk).lineSpacing(3)
                    RangeCalendar(from: DK.today) { range = $0 }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(WT.pzBg))
                .padding(.horizontal, 16)
            }
        }
        .background(WT.card.ignoresSafeArea())
    }
}
