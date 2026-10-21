import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

/// 网页版 .sec-h：灰底小图标 + 小标题（右侧可放说明）
struct SecHead<R: View>: View {
    var icon: String
    var title: String
    @ViewBuilder var right: R
    var body: some View {
        HStack(spacing: 8) {
            Image(icon).renderingMode(.template).resizable().frame(width: 18, height: 18).foregroundStyle(PT.body)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.12)))
            Text(title).font(.app(size: 15, weight: .semibold)).foregroundStyle(PT.body)
            Spacer(minLength: 0)
            right
        }
        .padding(.horizontal, 4).padding(.top, 20).padding(.bottom, 10)
    }
}

extension SecHead where R == EmptyView {
    init(icon: String, title: String) { self.icon = icon; self.title = title; self.right = EmptyView() }
}

// MARK: - 备份

struct BackupPage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @State private var share: ShareItem?
    @State private var importing = false
    @State private var snapshots: [URL] = []
    @State private var restoreURL: URL?
    @State private var resultText: String?
    @State private var notifOK = true
    @State private var open: Set<Int> = []

    private var days: Int { store.s.records.filter { $0.key <= DK.today && $0.value.values.contains { $0.checked } }.count }
    private var needsNotif: Bool { store.s.prefs.daily.on || store.s.cards.contains { !($0.reminders ?? []).isEmpty } }
    private var issues: [(tag: String, title: String, sub: String)] {
        var out: [(String, String, String)] = []
        if needsNotif && !notifOK { out.append(("提醒", "推送通知", "还没有开启通知，设好的提醒不会弹出来。点这里去打开")) }
        return out
    }

    var body: some View {
        NavPage("备份") {
            VStack(spacing: 12) {
                hero
                flow
                if !issues.isEmpty {
                    h("需要你看一下")
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, x in
                        Button { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(x.tag).font(.app(size: 11, weight: .bold)).foregroundStyle(Color(hex: "#8A6416"))
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(hex: "#FBEBC6")))
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(x.title).font(.app(size: 15, weight: .semibold)).foregroundStyle(ink)
                                    Text(x.sub).font(.app(size: 12.5)).foregroundStyle(Color(hex: "#7D7366")).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(PT.chip))
                        }
                        .buttonStyle(.plain)
                    }
                }
                h("手动备份")
                HStack(spacing: 10) {
                    act("sf_export", "导出到文件", "\(store.s.journalTotal) 篇笔记一起带走") { exportJSON() }
                    act("sf_import", "从文件恢复", "换手机、换平台时用") { importing = true }
                }
                if !snapshots.isEmpty {
                    h("自动备份（最近 7 天）")
                    VStack(spacing: 0) {
                        ForEach(Array(snapshots.enumerated()), id: \.offset) { i, u in
                            if i > 0 { Rectangle().fill(PT.chipLine).frame(height: 1) }
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(snapName(u)).font(.app(size: 14.5, weight: .semibold)).foregroundStyle(ink)
                                    Text(sizeText(u)).font(.app(size: 12)).foregroundStyle(Color(hex: "#8F857A"))
                                }
                                Spacer()
                                Button("恢复") { restoreURL = u }.font(.app(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "#5E9E52"))
                                Button { share = ShareItem(url: u) } label: {
                                    Image("sf_export").renderingMode(.template).resizable().frame(width: 18, height: 18).foregroundStyle(PT.sub)
                                }
                                .padding(.leading, 12)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PT.chip))
                    Text("每天第一次打开或离开 App 时，会自动在本机留一份，也能在「文件」App →「我的 iPhone」→「小满」里找到。删除 App 时这些文件也会一起删除，换手机前请先导出。")
                        .font(.app(size: 12)).foregroundStyle(PT.faint).padding(.horizontal, 4)
                }
                h("常见疑问")
                VStack(spacing: 0) {
                    ForEach(Array(faq.enumerated()), id: \.offset) { i, q in
                        if i > 0 { Rectangle().fill(PT.chipLine).frame(height: 1) }
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) { if open.contains(i) { open.remove(i) } else { open.insert(i) } }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(open.contains(i) ? "−" : "+").font(.app(size: 15, weight: .bold)).foregroundStyle(Color(hex: "#5E9E52")).frame(width: 10)
                                    Text(q.0).font(.app(size: 14.5, weight: .semibold)).foregroundStyle(ink)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if open.contains(i) {
                                Text(q.1).font(.app(size: 13.5)).foregroundStyle(Color(hex: "#6F665C")).lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true).padding(.leading, 18)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PT.chip))
                Button {
                    Feedback.tap(); check(); loadSnapshots(); toaster.show("检查完成")
                } label: {
                    Text("再检查一次").font(.app(size: 14, weight: .semibold)).foregroundStyle(Color(hex: "#5E9E52"))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "#EAF5E5")))
                }
                .buttonStyle(PressScale())
                .padding(.top, 4)
            }
        }
        .onAppear { check(); loadSnapshots() }
        .sheet(item: $share) { s in ShareSheet(items: [s.url]).presentationDetents([.medium, .large]) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .data]) { r in
            if case .success(let u) = r { restore(from: u, scoped: true) }
        }
        .confirmationDialog("从这份自动备份恢复？", isPresented: Binding(get: { restoreURL != nil }, set: { if !$0 { restoreURL = nil } }), titleVisibility: .visible) {
            Button("恢复") { if let u = restoreURL { restore(from: u, scoped: false) }; restoreURL = nil }
        } message: { Text("只会补上缺少的习惯和记录，不会覆盖现有数据。") }
        .alert("恢复完成", isPresented: Binding(get: { resultText != nil }, set: { if !$0 { resultText = nil } })) {
            Button("好的") { resultText = nil }
        } message: { Text(resultText ?? "") }
    }

    private var ink: Color { Theme.adaptive("#3E3532", "#F2EDE4") }

    private let faq: [(String, String)] = [
        ("关掉 iCloud，记录会不见吗？", "不会。记录先写在这台手机上；手机的 iCloud 整机备份只是另存一份。"),
        ("换新手机要做什么？", "用 iCloud 备份或「快速开始」迁移到新手机时，小满的记录会一起过去。也可以先在旧手机「导出到文件」，再到新手机「从文件恢复」。"),
        ("两台设备看到的不一样？", "目前记录保存在各自的手机上，两台设备之间不会自动同步。可以在一台上「导出到文件」，再到另一台「从文件恢复」，缺少的内容会补上。")
    ]

    private var hero: some View {
        let n = issues.count
        return HStack(spacing: 14) {
            Image("sf_hero").resizable().frame(width: 78, height: 78)
            VStack(alignment: .leading, spacing: 4) {
                Text(n == 0 ? "一切正常" : "有 \(n) 处可以更好").font(.app(size: 19, weight: .heavy)).foregroundStyle(Color(hex: "#3E3532"))
                Text(n == 0 ? "记录保存在手机上，也会随 iCloud 整机备份" : "不影响使用，处理后会更安心").font(.app(size: 13.5)).foregroundStyle(Color(hex: "#7D7366"))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: n == 0 ? "#EAF5E5" : "#FBF2DF")))
    }

    private var flow: some View {
        let last = store.s.lastBackup
        return HStack(alignment: .top, spacing: 0) {
            node("sf_phone", "手机本地", "\(days) 天记录", ok: true)
            link
            node("sf_cloud", "iCloud", "随整机备份", ok: true)
            link
            node("sf_file", "备份文件", last.map { "\(DK.md($0))导出" } ?? "还没导出过", ok: last != nil)
        }
        .padding(.horizontal, 8).padding(.top, 14).padding(.bottom, 12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(PT.chip))
    }

    private var link: some View {
        Line2().stroke(Color(hex: "#C9C1B4"), style: StrokeStyle(lineWidth: 2, dash: [5, 4])).frame(width: 18, height: 2).padding(.top, 22)
    }

    private func node(_ icon: String, _ t: String, _ sub: String, ok: Bool) -> some View {
        VStack(spacing: 5) {
            Image(icon).renderingMode(.template).resizable().frame(width: 22, height: 22).foregroundStyle(Color(hex: "#4A3F45"))
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(hex: ok ? "#E3F2DC" : "#FFFFFF")))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color(hex: ok ? "#B9DAAC" : "#E5DED2"), lineWidth: 1.5))
            Text(t).font(.app(size: 13.5, weight: .semibold)).foregroundStyle(ink)
            Text(sub).font(.app(size: 11.5)).foregroundStyle(Color(hex: "#8F857A")).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func h(_ t: String) -> some View {
        Text(t).font(.app(size: 14, weight: .bold)).foregroundStyle(Color(hex: "#8F857A"))
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.top, 10)
    }

    private func act(_ icon: String, _ t: String, _ sub: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(alignment: .leading, spacing: 6) {
                Image(icon).renderingMode(.template).resizable().frame(width: 24, height: 24).foregroundStyle(Color(hex: "#4A3F45"))
                Text(t).font(.app(size: 15, weight: .semibold)).foregroundStyle(ink).padding(.top, 8)
                Text(sub).font(.app(size: 12)).foregroundStyle(Color(hex: "#8F857A"))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PT.chip))
        }
        .buttonStyle(PressScale(scale: 0.97))
    }

    private func check() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let ok = s.authorizationStatus == .authorized || s.authorizationStatus == .provisional || s.authorizationStatus == .ephemeral
            DispatchQueue.main.async { notifOK = ok }
        }
    }

    private func exportJSON() {
        guard let d = try? Backup.encode(store.s), let u = Backup.tempFile(name: "小满-备份-\(DK.today).json", data: d) else {
            toaster.show("导出失败，请重试"); return
        }
        store.s.lastBackup = DK.today
        store.save()
        share = ShareItem(url: u)
    }

    private func restore(from u: URL, scoped: Bool) {
        let ok = scoped ? u.startAccessingSecurityScopedResource() : false
        defer { if ok { u.stopAccessingSecurityScopedResource() } }
        do {
            let d = try Data(contentsOf: u)
            let r = try store.importBackup(d)
            resultText = "新增 \(r.cards) 个习惯、\(r.records) 条打卡记录、\(r.notes) 篇笔记。"
            Feedback.success()
        } catch {
            toaster.show(error.localizedDescription)
        }
    }

    private func loadSnapshots() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("自动备份", isDirectory: true)
        snapshots = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func snapName(_ u: URL) -> String {
        let n = u.deletingPathExtension().lastPathComponent
        let k = String(n.suffix(10))
        return Backup.isKey(k) ? "\(DK.year(DK.date(k)))年\(DK.md(k))" : n
    }

    private func sizeText(_ u: URL) -> String {
        let b = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return b > 1_000_000 ? String(format: "%.1f MB", Double(b) / 1_000_000) : "\(max(1, b / 1000)) KB"
    }
}

private struct Line2: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.width, y: r.midY)); return p }
}

// MARK: - 新事件（新增、删除、首次打卡、笔记）

struct EventsPage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @State private var filter = "全部"
    @State private var edit: JournalTarget?

    struct Ev: Identifiable { let id: String; let type: String; let cid: String; let name: String; let date: String; let ts: Double; var jk: String? }

    private func kind(_ t: String) -> String {
        switch t { case "add", "restore": return "新增"; case "del": return "删除"; case "first": return "首次打卡"; default: return "笔记" }
    }

    private var all: [Ev] {
        let s = store.s, T = DK.today, N = s.noteIds
        var out: [Ev] = []
        var have = Set<String>()
        for (i, e) in s.events.enumerated() where !N.contains(e.id) {
            out.append(Ev(id: "e\(i)", type: e.type, cid: e.id, name: e.name, date: e.date, ts: e.ts ?? 0))
            have.insert(e.type + "|" + e.id)
        }
        let keys = s.records.keys.sorted()
        for c in (s.cards + s.archived) where !c.isNote {
            var first: String?
            for k in keys where k <= T { if s.records[k]?[c.id]?.checked == true { first = k; break } }
            if !have.contains("add|" + c.id), let d = c.createdAt ?? first ?? keys.first {
                out.append(Ev(id: "a" + c.id, type: "add", cid: c.id, name: c.name, date: d, ts: 0))
            }
            if let f = first { out.append(Ev(id: "f" + c.id, type: "first", cid: c.id, name: c.name, date: f, ts: 1)) }
        }
        for (k, list) in s.journal where k <= T {
            for e in list { out.append(Ev(id: "j" + e.id, type: "jr", cid: e.id, name: e.displayTitle, date: k, ts: 3, jk: k)) }
        }
        return out.sorted { $0.date != $1.date ? $0.date > $1.date : $0.ts > $1.ts }
    }

    var body: some View {
        let A = all
        let list = A.filter { filter == "全部" || kind($0.type) == filter }
        let months = Dictionary(grouping: list) { String($0.date.prefix(7)) }
        let mkeys = months.keys.sorted(by: >)
        NavPage("新事件") {
            HStack(spacing: 0) {
                ForEach(Array(["全部", "新增", "删除", "首次打卡", "笔记"].enumerated()), id: \.offset) { i, f in
                    if i > 0 { Rectangle().fill(Theme.adaptive("#D8D0C1", "#4A453D")).frame(width: 1, height: 16).opacity(filter == f || filter == ["全部", "新增", "删除", "首次打卡", "笔记"][i - 1] ? 0 : 1) }
                    let on = filter == f
                    let n = f == "全部" ? 0 : A.filter { kind($0.type) == f }.count
                    Button { Feedback.tap(); filter = f } label: {
                        HStack(spacing: 3) {
                            Text(f).font(.app(size: 13.5, weight: on ? .bold : .medium)).foregroundStyle(on ? Color(hex: "#2E2A27") : Theme.adaptive("#5B4F45", "#CFC6B8"))
                            if n > 0 { Text("\(n)").font(.app(size: 11, weight: .medium)).foregroundStyle(Color(hex: "#9C9186")) }
                        }
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background { if on { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.adaptive("#FFFFFF", "#F2EDE4")).shadow(color: Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.12), radius: 3, y: 2) } }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.adaptive("#EFE9DD", "#2C2A26")))
            .padding(.top, 4).padding(.bottom, 14)
            if list.isEmpty {
                VStack(spacing: 10) {
                    Image("mt_events").resizable().frame(width: 40, height: 40).opacity(0.6)
                    Text("还没有这类事件").font(.app(size: 14)).foregroundStyle(PT.faint)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 50)
            }
            ForEach(mkeys, id: \.self) { mk in
                let d = DK.date(mk + "-01")
                Text(verbatim: "\(DK.year(d))年\(DK.month(d))月").font(.app(size: 13, weight: .bold)).foregroundStyle(Color(hex: "#8A7F6E"))
                    .padding(.horizontal, 6).padding(.top, 16).padding(.bottom, 8)
                VStack(spacing: 0) {
                    ForEach(Array((months[mk] ?? []).enumerated()), id: \.element.id) { i, e in
                        if i > 0 { Rectangle().fill(Theme.adaptive("#F0EAE0", "#3A3732")).frame(height: 1.5) }
                        row(e)
                    }
                }
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.adaptive("#FFFDF8", "#2A2825")))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.adaptive("#EAE3D6", "#3A3732"), lineWidth: 1.5))
            }
        }
        .fullScreenCover(item: $edit) { t in
            JournalEditor(day: t.day, entryId: t.entryId).environmentObject(store).environmentObject(toaster)
        }
    }

    @ViewBuilder private func row(_ e: Ev) -> some View {
        let badge: String = ["add": "evb_add", "del": "evb_del", "restore": "evb_res", "first": "evb_first"][e.type] ?? "evb_note"
        let text: String = {
            switch e.type {
            case "add": return "新增了习惯「\(e.name)」"
            case "del": return "删除了习惯「\(e.name)」"
            case "restore": return "恢复了习惯「\(e.name)」"
            case "first": return "第一次完成「\(e.name)」"
            case "note": return "第一次给「\(e.name)」写备注"
            default: return "写了笔记「\(e.name)」"
            }
        }()
        let d = DK.date(e.date)
        let content = HStack(spacing: 10) {
            Image(badge).resizable().frame(width: 34, height: 34)
            Group {
                if e.type == "jr" {
                    Image("evb_jr").renderingMode(.template).resizable().scaledToFit().frame(width: 22, height: 20).foregroundStyle(Color(hex: "#6C6A62"))
                } else if let c = store.s.cardAny(e.cid) {
                    if c.ic == "text" {
                        Text(c.text.isEmpty ? String(c.name.prefix(1)) : c.text).font(.app(size: 14, weight: .bold)).foregroundStyle(Color(hex: c.hex))
                    } else {
                        Image(IconCatalog.assetName(c.icon)).resizable().scaledToFit().frame(width: 28, height: 28)
                    }
                }
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(text).font(.app(size: 14.5, weight: .semibold)).foregroundStyle(PT.body).lineLimit(1)
                Text("\(DK.month(d))月\(DK.day(d))日 周\(DK.wdName[DK.weekday(d)])").font(.app(size: 12)).foregroundStyle(Color(hex: "#9A9AA3"))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
        if let jk = e.jk {
            Button { edit = JournalTarget(day: jk, entryId: String(e.id.dropFirst())) } label: { content }.buttonStyle(.plain)
        } else { content }
    }
}

// MARK: - 小组件

struct WidgetPage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @Environment(\.colorScheme) private var scheme
    @State private var kind = "check"
    @State private var page = 0
    @State private var popped: Set<String> = []
    @State private var custom = Color(hex: "#E8F0FF")

    static let sample: [(String, String, String)] = [
        ("C-WATER", "喝水", "#50A8B0"), ("1F4DA", "读书", "#F29D38"), ("C-DUMBBELL", "健身", "#3D8FE0"), ("1F9E0", "冥想", "#A58BD6"),
        ("C-CUP", "咖啡", "#C89B6D"), ("1F96C", "吃蔬菜", "#7DBF8A"), ("1FAA5", "刷牙", "#F3A6B8"), ("1F3B9", "练琴", "#F5C542"),
        ("1F48A", "吃药", "#EC6F6B"), ("1F3A8", "画画", "#E57BA0"), ("C-POOL", "游泳", "#00B0FF"), ("1F4F7", "拍照", "#8A63D2"),
        ("1F6B2", "骑行", "#32D74B"), ("270F", "写字", "#FF9F0A"), ("1F436", "遛狗", "#D9653B"), ("1F34E", "吃水果", "#E66A5E")
    ]

    private var o: WidgetPrefs { store.s.prefs.widget ?? WidgetPrefs() }
    /// 和桌面上一样：默认跟随页面主题
    private var bg: LinearGradient {
        if let h = o.bgHex { return LinearGradient(colors: [Color(hex: h)], startPoint: .top, endPoint: .bottom) }
        if scheme == .dark { return LinearGradient(colors: [Color(hex: "#262624")], startPoint: .top, endPoint: .bottom) }
        let c = ThemeFill.colors(store.s.prefs.pageBg)
        return LinearGradient(colors: [Color(hex: c.top), Color(hex: c.base)], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        NavPage("小组件") {
            SecHead(icon: "sec_widget", title: "小组件预览") { Text("左右滑动查看").font(.app(size: 12)).foregroundStyle(PT.muted) }
            HStack(spacing: 0) {
                ForEach([("check", "打卡小组件"), ("jr", "笔记小组件")], id: \.0) { k in
                    let on = kind == k.0
                    Button { Feedback.tap(); kind = k.0; page = 0 } label: {
                        Text(k.1).font(.app(size: 14, weight: on ? .semibold : .medium)).foregroundStyle(on ? PT.ink : PT.sub)
                            .frame(maxWidth: .infinity).frame(height: 34)
                            .background { if on { Capsule().fill(Theme.adaptive("#FFFFFF", "#636366")).shadow(color: .black.opacity(0.08), radius: 4, y: 2) } }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(Theme.adaptive("#EDEDF0", "#2F2E2B")))
            .padding(.top, 2).padding(.bottom, 12)
            TabView(selection: $page) {
                ForEach(0..<3, id: \.self) { i in
                    VStack(spacing: 10) {
                        Spacer(minLength: 0)
                        preview(i)
                        VStack(spacing: 2) {
                            Text(["小号", "中号", "大号"][i]).font(.app(size: 14, weight: .bold)).foregroundStyle(PT.body)
                            Text(caption(i)).font(.app(size: 12)).foregroundStyle(PT.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 420)
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i == page ? PT.ink : Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.3))
                        .frame(width: i == page ? 18 : 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity).padding(.top, 6)
            .animation(.easeOut(duration: 0.2), value: page)

            SecHead(icon: "sec_gear", title: "显示设置")
            SheetRow {
                TileIcon(icon: "wg_hand", bg: Pastel.at(0), size: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("直接打卡").font(.app(size: 16, weight: .medium)).foregroundStyle(PT.body)
                    Text("点小组件上的习惯直接完成打卡，不用打开 App").font(.app(size: 12.5)).foregroundStyle(PT.faint).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                ProtoSwitch(on: o.tap) { set { $0.tap.toggle() } }
            }
            SecHead(icon: "sec_palette", title: "背景颜色")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 12) {
                ForEach(WidgetPrefs.bgs, id: \.id) { b in
                    let on = o.bg == b.id
                    Button { Feedback.tap(); set { $0.bg = b.id } } label: {
                        VStack(spacing: 5) {
                            Circle().fill(b.hex.isEmpty ? (scheme == .dark ? Color(hex: "#262624") : Color(hex: ThemeFill.colors(store.s.prefs.pageBg).top)) : Color(hex: b.hex))
                                .frame(width: 40, height: 40)
                                .overlay(Circle().strokeBorder(Color.black.opacity(0.1), lineWidth: 1))
                                .overlay { if on { Circle().stroke(PT.ink, lineWidth: 2).padding(-3) } }
                            Text(b.id == "default" ? "跟随主题" : b.name).font(.app(size: 11.5, weight: on ? .semibold : .regular)).foregroundStyle(on ? PT.ink : PT.sub)
                        }
                    }
                    .buttonStyle(.plain)
                }
                VStack(spacing: 5) {
                    ColorPicker("", selection: $custom, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 40, height: 40)
                        .overlay { if o.bg == "custom" { Circle().stroke(PT.ink, lineWidth: 2).padding(-3).allowsHitTesting(false) } }
                    Text("自定义").font(.app(size: 11.5, weight: o.bg == "custom" ? .semibold : .regular)).foregroundStyle(o.bg == "custom" ? PT.ink : PT.sub)
                }
            }
            SecHead(icon: "sec_guide", title: "添加到桌面")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(["长按主屏幕空白处，直到图标开始晃动", "点击左上角的「编辑」→「添加小组件」", "搜索「小满」，选择尺寸后添加"].enumerated()), id: \.offset) { i, t in
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(.app(size: 13, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 26, height: 26).background(Circle().fill(Theme.adaptive("#5E5CE6", "#8E8CFF")))
                        Text(t).font(.app(size: 14.5)).foregroundStyle(PT.body)
                    }
                }
            }
            Text(kind == "check" ? "预览里是示例图标。放到桌面后，小组件会显示你当天还没打卡的习惯，打完的自动消失；一页放不下时，点右上角的「›」翻到下一组。\(o.tap ? "可以点一下图标，看看打卡效果。" : "")" : "放到桌面后，点小组件就能直接写当天的笔记。")
                .font(.app(size: 12.5)).foregroundStyle(PT.sub).lineSpacing(3).padding(.horizontal, 6).padding(.top, 12)
        }
        .onAppear { custom = Color(hex: o.custom) }
        .onChange(of: custom) { _, c in
            let h = c.hexString
            if h.uppercased() != o.custom.uppercased() || o.bg != "custom" { set { $0.custom = h; $0.bg = "custom" } }
        }
    }

    private func set(_ f: (inout WidgetPrefs) -> Void) {
        var w = o
        f(&w)
        store.updatePrefs { $0.widget = w }
    }

    private func caption(_ i: Int) -> String {
        if kind == "jr" { return ["点一下直接写，不进入 App", "写下的内容自动存为当天笔记", "显示今天写过的笔记"][i] }
        return ["4 个习惯，打完的自动消失", "8 个习惯", "16 个习惯"][i]
    }

    @ViewBuilder private func preview(_ i: Int) -> some View {
        let w: CGFloat = i == 0 ? 158 : 338
        let h: CGFloat = i == 2 ? 338 : 158
        Group {
            if kind == "check" { checkWidget(i) } else { jrWidget(i) }
        }
        .padding(i == 0 ? 12 : 14)
        .frame(width: w, height: h, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(bg))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.black.opacity(0.05), lineWidth: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(scheme == .dark ? 0.6 : 0.2), radius: 13, y: 10)
    }

    private func checkWidget(_ i: Int) -> some View {
        let n = [4, 8, 16][i], cols = i == 0 ? 2 : 4
        let ink = scheme == .dark ? Color(hex: "#F2F2F7") : Color(hex: "#1C1C1E")
        return VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日打卡").font(.app(size: 12.5, weight: .semibold))
                Spacer()
                Text("3/\(n + 3)").font(.app(size: 12.5)).monospacedDigit().opacity(0.6)
            }
            .foregroundStyle(ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: cols), spacing: 4) {
                ForEach(0..<n, id: \.self) { j in
                    let it = Self.sample[j]
                    let key = "\(i)-\(j)"
                    Button {
                        guard o.tap else { toaster.show("开启“直接打卡”后，点这里就能完成打卡"); return }
                        guard !popped.contains(key) else { return }
                        if store.s.prefs.sound { SFX.play(SFX.inSound) }
                        Feedback.tap()
                        popped.insert(key)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { popped.remove(key) }
                    } label: {
                        VStack(spacing: 2) {
                            ProtoDot(card: Card(id: "wg\(j)", name: it.1, icon: it.0, hex: it.2), on: popped.contains(key),
                                     shape: CardShapes.normalize(store.s.prefs.shape), line: store.s.prefs.line, size: [40, 36, 38][i])
                            if i > 0 { Text(it.1).font(.app(size: 10)).foregroundStyle(ink).lineLimit(1) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func jrWidget(_ i: Int) -> some View {
        let ink = scheme == .dark ? Color(hex: "#F2F2F7") : Color(hex: "#1C1C1E")
        let jl = store.s.journalList(DK.today)
        let bubble = Image("evb_jr").renderingMode(.template).resizable().scaledToFit().foregroundStyle(Color(hex: "#4FAE78"))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("笔记").font(.app(size: 12.5, weight: .semibold))
                Spacer()
                Text("今天 \(jl.count) 篇").font(.app(size: 12.5)).opacity(0.6)
            }
            .foregroundStyle(ink)
            if i == 0 {
                VStack(spacing: 6) {
                    bubble.frame(width: 62, height: 55)
                    Text("写一篇").font(.app(size: 12.5)).foregroundStyle(ink.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if i == 1 {
                HStack(spacing: 10) {
                    bubble.frame(width: 38, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(jl.last?.displayTitle ?? "今天想记点什么？").font(.app(size: 14, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                        Text(jl.last.map { String($0.text.prefix(24)) } ?? "点这里开始写").font(.app(size: 12)).foregroundStyle(ink.opacity(0.6)).lineLimit(1)
                    }
                }
                VStack(spacing: 10) { ForEach(0..<2, id: \.self) { _ in Rectangle().fill(ink.opacity(0.08)).frame(height: 1) } }.padding(.top, 4)
            } else {
                if jl.isEmpty { Text("今天还没有笔记").font(.app(size: 13)).foregroundStyle(ink.opacity(0.6)) }
                ForEach(jl.suffix(3).reversed()) { e in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text(e.displayTitle).font(.app(size: 13.5, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                            Spacer()
                            Text(DK.hm(e.c)).font(.app(size: 11.5)).foregroundStyle(ink.opacity(0.5))
                        }
                        Text(String(e.text.prefix(30))).font(.app(size: 12)).foregroundStyle(ink.opacity(0.6)).lineLimit(1)
                    }
                }
                VStack(spacing: 10) { ForEach(0..<4, id: \.self) { _ in Rectangle().fill(ink.opacity(0.08)).frame(height: 1) } }.padding(.top, 4)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    bubble.frame(width: 20, height: 18)
                    Text("点这里写一篇").font(.app(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "#4FAE78"))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 导出数据

struct ExportPage: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @State private var type = "records"
    @State private var range = "all"
    @State private var from = DK.add(DK.todayDate, -29)
    @State private var to = DK.todayDate
    @State private var share: ShareItem?
    @State private var showBackup = false

    private let types: [(String, String, String, String)] = [
        ("records", "ex_rec", "打卡记录", "日期、习惯、状态、打卡时间和日志（CSV）"),
        ("journal", "ex_jr", "笔记", "日期、时间、标题、内容和当天心情（CSV）"),
        ("cards", "ex_cards", "习惯列表", "每个习惯的重复规则、提醒和累计次数（CSV）"),
        ("json", "ex_json", "完整备份", "全部卡片、打卡、笔记、分组和心情，可以用来恢复数据（JSON）")
    ]
    private let ranges: [(String, String)] = [("all", "全部数据"), ("7", "最近 7 天"), ("30", "最近 30 天"), ("90", "最近 3 个月"), ("365", "最近一年"), ("custom", "自定义")]

    private var span: (String, String) {
        switch range {
        case "all": return ("0000-00-00", "9999-99-99")
        case "custom": return (DK.key(min(from, to)), DK.key(max(from, to)))
        default: return (DK.key(DK.add(DK.todayDate, -(Int(range) ?? 30) + 1)), DK.today)
        }
    }

    private var rows: [[String]] {
        switch type {
        case "records": return Backup.recordRows(store.s, from: span.0, to: span.1)
        case "journal": return Backup.noteRows(store.s, from: span.0, to: span.1)
        case "cards": return Backup.cardRows(store.s)
        default: return []
        }
    }

    var body: some View {
        let R = rows
        NavPage("导出数据") {
            VStack(spacing: 4) {
                Image("ex_hero").renderingMode(.template).resizable().frame(width: 30, height: 30).foregroundStyle(.white)
                    .frame(width: 60, height: 60).background(Circle().fill(Color(hex: "#1C1C1E")))
                    .padding(.bottom, 6)
                Text("导出你的数据").font(.app(size: 18, weight: .semibold)).foregroundStyle(PT.body)
                Text("保存到手机的“文件”或 iCloud 云盘，导出永久免费").font(.app(size: 12.5)).foregroundStyle(PT.muted)
            }
            .frame(maxWidth: .infinity).padding(.top, 6).padding(.bottom, 4)
            SecHead(icon: "sec_table", title: "选择数据类型")
            VStack(spacing: 8) {
                ForEach(Array(types.enumerated()), id: \.offset) { i, t in
                    let on = type == t.0
                    Button { Feedback.tap(); type = t.0 } label: {
                        SheetRow {
                            TileIcon(icon: t.1, bg: Pastel.at(i), size: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.2).font(.app(size: 16)).foregroundStyle(PT.body)
                                Text(t.3).font(.app(size: 12)).foregroundStyle(PT.sub).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Circle().strokeBorder(on ? Color(hex: "#007AFF") : PT.muted, lineWidth: on ? 7 : 1.6).frame(width: 22, height: 22)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            if type != "cards" {
                SecHead(icon: "sec_cal", title: "选择时间范围")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(ranges, id: \.0) { r in
                        let on = range == r.0
                        Button { Feedback.tap(); range = r.0 } label: {
                            Text(r.1).font(.app(size: 13.5, weight: on ? .semibold : .regular))
                                .foregroundStyle(on ? Theme.adaptive("#FFFFFF", "#1B1B1A") : PT.body)
                                .frame(maxWidth: .infinity).frame(height: 38)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? PT.body : Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if range == "custom" {
                    VStack(spacing: 0) {
                        DatePicker("开始", selection: $from, in: ...Date(), displayedComponents: .date)
                        DatePicker("结束", selection: $to, in: ...Date(), displayedComponents: .date)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(PT.chip))
                    .padding(.top, 10)
                }
            }
            if type != "json" {
                SecHead(icon: "sec_eye", title: "数据预览") { Text("共 \(max(0, R.count - 1)) 行").font(.app(size: 12)).foregroundStyle(PT.muted) }
                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(Array(R.prefix(6).enumerated()), id: \.offset) { i, row in
                            GridRow {
                                ForEach(Array(row.prefix(6).enumerated()), id: \.offset) { _, cell in
                                    Text(cell.isEmpty ? " " : String(cell.prefix(14))).font(.app(size: 12, weight: i == 0 ? .semibold : .regular))
                                        .foregroundStyle(i == 0 ? PT.sub : PT.body).lineLimit(1)
                                        .padding(.horizontal, 10).padding(.vertical, 8)
                                }
                            }
                            if i < min(R.count, 6) - 1 { Divider().gridCellUnsizedAxes(.horizontal) }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.07)))
            }
            Button { export(R) } label: {
                HStack(spacing: 8) {
                    Image("ex_go").renderingMode(.template).resizable().frame(width: 18, height: 18)
                    Text(type == "json" ? "导出 JSON" : "导出 CSV").font(.app(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "#007AFF")))
            }
            .buttonStyle(PressScale(scale: 0.98))
            .padding(.top, 16)
            Button { showBackup = true } label: {
                HStack(spacing: 6) {
                    Image("ex_cloud").renderingMode(.template).resizable().frame(width: 18, height: 18)
                    Text("备份与恢复（导入）›").font(.app(size: 14))
                }
                .foregroundStyle(PT.sub).frame(maxWidth: .infinity).frame(height: 40)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .sheet(item: $share) { s in ShareSheet(items: [s.url]).presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showBackup) {
            NavigationStack { BackupPage() }.environmentObject(store).environmentObject(toaster)
                .presentationCornerRadius(30).presentationDragIndicator(.visible)
        }
    }

    private func export(_ R: [[String]]) {
        if type == "json" {
            guard let d = try? Backup.encode(store.s), let u = Backup.tempFile(name: "小满-备份-\(DK.today).json", data: d) else { toaster.show("导出失败，请重试"); return }
            store.s.lastBackup = DK.today
            store.save()
            share = ShareItem(url: u)
            return
        }
        guard R.count > 1 else { toaster.show("这段时间没有可以导出的内容", gray: true); return }
        let name = types.first { $0.0 == type }?.2 ?? "数据"
        let suffix = range == "all" || type == "cards" ? DK.today : "\(span.0)至\(span.1)"
        guard let d = Backup.csv(R).data(using: .utf8), let u = Backup.tempFile(name: "小满-\(name)-\(suffix).csv", data: d) else {
            toaster.show("导出失败，请重试"); return
        }
        share = ShareItem(url: u)
    }
}

// MARK: - 意见反馈

struct FeedbackSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var showTxc = false

    var body: some View {
        FitSheet {
            VStack(alignment: .leading, spacing: 0) {
                ProtoSheetHead(title: "意见反馈", closeLeft: true) { dismiss() }
                HStack(spacing: 10) {
                    Image("fb_msg").renderingMode(.template).resizable().frame(width: 24, height: 24).foregroundStyle(Color(hex: "#5E5CE6"))
                    Text("你的每一条反馈，开发者都会认真看").font(.app(size: 13.5)).foregroundStyle(PT.body)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(red: 94/255, green: 92/255, blue: 230/255).opacity(0.14)))
                .padding(.bottom, 14)
                Button { Feedback.tap(); showTxc = true } label: {
                    HStack(spacing: 12) {
                        Image("fb_bubble").renderingMode(.template).resizable().frame(width: 22, height: 22).foregroundStyle(Color(hex: "#5E4306"))
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.75)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("去反馈社区提建议").font(.app(size: 15.5, weight: .semibold)).foregroundStyle(Color(hex: "#3E3532"))
                            Text("可以发文字和截图，也能看到开发者的回复和其他人的建议").font(.app(size: 12)).foregroundStyle(Color(hex: "#7D7266"))
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Text("›").font(.app(size: 20)).foregroundStyle(Color(hex: "#B5AA9C"))
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LinearGradient(colors: [Color(hex: "#FFF1C9"), Color(hex: "#FFE39A")], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(red: 160/255, green: 120/255, blue: 30/255).opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(PressScale(scale: 0.98))
                .padding(.bottom, 14)
                VStack(alignment: .leading, spacing: 4) {
                    Text("反馈小提示").font(.app(size: 13, weight: .semibold)).foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4"))
                    Text("遇到问题时，写清楚在哪个页面、做了什么、看到了什么，最好附一张截图，我们能更快找到原因。")
                        .font(.app(size: 12.5)).foregroundStyle(Theme.adaptive("#6F665C", "#B5ADA2")).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.adaptive("#F7F4EE", "#2A2825")))
                Text("会自动附带：V\(DeviceInfo.appVersion)（\(DeviceInfo.build)），\(DeviceInfo.model)，iOS \(DeviceInfo.osVersion)。不会附带你的打卡、日志和笔记内容。")
                    .font(.app(size: 12)).foregroundStyle(PT.sub).lineSpacing(3).padding(.horizontal, 6).padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showTxc) {
            NavigationStack {
                FeedbackView()
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { showTxc = false } } }
            }
            .environmentObject(store)
        }
    }
}

// MARK: - 会员

struct VipSheet: View {
    @EnvironmentObject var purchases: Purchases
    @Environment(\.dismiss) private var dismissEnv
    /// 从 UIKit 弹出时用它关闭
    var onClose: (() -> Void)? = nil
    private func dismiss() { if let onClose { onClose() } else { dismissEnv() } }
    @State private var pick = "year"
    @State private var msg: String?
    @State private var doc: VipDoc?

    struct VipDoc: Identifiable { let id: String }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.app(size: 15, weight: .bold)).foregroundStyle(PT.sub)
                        .frame(width: 34, height: 34).background(Circle().fill(PT.chip))
                }
                .buttonStyle(.plain).accessibilityLabel("关闭")
                Spacer()
                Button("恢复购买") { Task { await purchases.restore() } }
                    .font(.app(size: 15, weight: .semibold)).foregroundStyle(PT.sub)
                    .disabled(purchases.busy)
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 0) {
                    Image("prog_palm").resizable().scaledToFit().frame(width: 62, height: 62)
                    Text("小满会员").font(.app(size: 25, weight: .heavy)).foregroundStyle(PT.ink).padding(.top, 8)
                    Text("一点点支持，让好习惯陪你更久").font(.app(size: 14)).foregroundStyle(PT.sub).padding(.top, 4)
                    if purchases.isVIP {
                        HStack(spacing: 6) {
                            Image("vp_crown").renderingMode(.template).resizable().frame(width: 15, height: 15)
                            Text(statusLine).font(.app(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: "#8A6200"))
                        .padding(.horizontal, 14).frame(height: 32)
                        .background(Capsule().fill(Color(hex: "#FFEDB5")))
                        .padding(.top, 12)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(VipPerks.list.enumerated()), id: \.offset) { i, p in
                            HStack(spacing: 14) {
                                perkIcon(p.asset, i)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(p.title).font(.app(size: 16, weight: .semibold)).foregroundStyle(PT.ink)
                                    Text(p.sub).font(.app(size: 12.5)).foregroundStyle(PT.sub).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 13)
                            if i < VipPerks.list.count - 1 { Rectangle().fill(PT.chipLine).frame(height: 1).padding(.leading, 52) }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.adaptive("#FAF6EC", "#21201E")))
                    .padding(.top, 20)
                    Text(VipPerks.free).font(.app(size: 12.5)).foregroundStyle(PT.faint).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 18)
                }
                .padding(.horizontal, 18)
            }

            // 底部：三档方案 + 开通按钮
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Purchases.kinds, id: \.self) { k in planCard(purchases.offer(k)) }
                    }
                    .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 4)
                }
                let cta = purchases.cta(pick)
                Button {
                    Feedback.tap()
                    Task { await purchases.buy(kind: pick) }
                } label: {
                    HStack(spacing: 8) {
                        if cta.enabled { Image("vp_crown").renderingMode(.template).resizable().frame(width: 18, height: 18) }
                        Text(cta.title).font(.app(size: 18, weight: .heavy))
                    }
                    .foregroundStyle(Color(hex: "#3E3532").opacity(cta.enabled ? 1 : 0.55))
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Capsule().fill(Color(hex: cta.enabled ? "#F7CB57" : "#EFE6CF")))
                }
                .buttonStyle(.plain)
                .disabled(!cta.enabled || purchases.busy)
                .padding(.horizontal, 24).padding(.top, 12)
                Text(cta.sub).font(.app(size: 12.5)).foregroundStyle(PT.sub).padding(.top, 8)
                HStack(spacing: 4) {
                    Text("开通即表示同意").foregroundStyle(PT.faint)
                    Button("《用户协议》") { doc = VipDoc(id: "terms") }.foregroundStyle(PT.sub)
                    Text("和").foregroundStyle(PT.faint)
                    Button("《隐私政策》") { doc = VipDoc(id: "privacy") }.foregroundStyle(PT.sub)
                }
                .font(.app(size: 11)).buttonStyle(.plain)
                .padding(.top, 6).padding(.bottom, 10)
            }
            .background(PT.bg.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -2)).ignoresSafeArea(edges: .bottom))
        }
        .background(PT.bg.ignoresSafeArea())
        .overlay { if purchases.busy { ProgressView().controlSize(.large) } }
        .presentationDetents([.large])
        .onAppear {
            if purchases.plan == "year" || purchases.plan == "month" { pick = "life" }
            Task { if purchases.products.isEmpty { await purchases.loadProducts() } }
        }
        .onChange(of: purchases.message) { _, m in if let m { msg = m; purchases.message = nil } }
        .alert(msg ?? "", isPresented: Binding(get: { msg != nil }, set: { if !$0 { msg = nil } })) { Button("好的") { msg = nil } }
        .sheet(item: $doc) { d in
            NavigationStack {
                DocView(title: d.id == "terms" ? "用户协议" : "隐私政策", text: d.id == "terms" ? LegalText.terms : LegalText.privacy)
                    .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { doc = nil } } }
            }
        }
    }

    private var statusLine: String {
        var s = "你是\(purchases.planName)"
        if let e = purchases.expires { s += " · \(DK.year(e))年\(DK.month(e))月\(DK.day(e))日续费" }
        else if purchases.plan == "life" { s += " · 谢谢支持" }
        return s
    }

    @ViewBuilder private func perkIcon(_ name: String, _ i: Int) -> some View {
        Group {
            if name.hasPrefix("sf:") {
                Image(systemName: String(name.dropFirst(3))).font(.system(size: 16, weight: .semibold))
            } else {
                Image(name).renderingMode(.template).resizable().scaledToFit().frame(width: 20, height: 20)
            }
        }
        .foregroundStyle(Color(hex: "#4A3F45"))
        .frame(width: 38, height: 38)
        .background(Circle().fill(Color(hex: Pastel.at(i))))
    }

    private func planCard(_ o: Purchases.Offer) -> some View {
        let on = pick == o.kind
        let current = purchases.plan == o.kind
        return Button { Feedback.tap(); withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { pick = o.kind } } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(o.title).font(.app(size: 15, weight: .bold)).foregroundStyle(PT.ink)
                    Spacer(minLength: 4)
                    ZStack {
                        Circle().strokeBorder(on ? Color.clear : PT.chipLine, lineWidth: 1.5)
                        if on {
                            Circle().fill(Color(hex: "#F2C14E"))
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 22, height: 22)
                }
                Text(o.price).font(.app(size: 23, weight: .heavy)).foregroundStyle(PT.ink).padding(.top, 8)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(current ? "当前方案" : o.note).font(.app(size: 11.5)).foregroundStyle(PT.sub).padding(.top, 4)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(width: 158, height: 116, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(on ? Theme.adaptive("#FFF4D2", "#3A3221") : Theme.adaptive("#F7F3EA", "#262523")))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(on ? Color(hex: "#F2C14E") : .clear, lineWidth: 2))
            .overlay(alignment: .top) {
                if let b = o.badge {
                    Text(b).font(.app(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: b == "推荐" ? "#6B4E00" : "#2F6F6A"))
                        .padding(.horizontal, 10).frame(height: 20)
                        .background(Capsule().fill(Color(hex: b == "推荐" ? "#FFE08A" : "#CBE7E4")))
                        .offset(y: -10)
                }
            }
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }
}
