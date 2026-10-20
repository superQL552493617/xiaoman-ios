import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 系统分享面板（存储到「文件」、AirDrop、微信等）
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - 备份恢复

struct BackupView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @State private var share: ShareItem?
    @State private var importing = false
    @State private var snapshots: [URL] = []
    @State private var restoreURL: URL?
    @State private var resultText: String?

    var body: some View {
        List {
            Section {
                Button { exportJSON() } label: { RowLabel(icon: "square.and.arrow.up", title: "导出完整备份", sub: lastText) }
                Button { importing = true } label: { RowLabel(icon: "square.and.arrow.down", title: "从备份文件恢复", sub: "选择之前导出的 .json 备份") }
            } footer: {
                Text("备份包含全部习惯、打卡记录、日志、笔记和设置。恢复时只会补上缺少的内容，不会覆盖现有数据。")
            }

            Section {
                if snapshots.isEmpty { Text("还没有自动备份").foregroundStyle(Theme.text3) }
                ForEach(snapshots, id: \.self) { u in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snapName(u)).foregroundStyle(Theme.text)
                            Text(sizeText(u)).font(.system(size: 12)).foregroundStyle(Theme.text3)
                        }
                        Spacer()
                        Button("恢复") { restoreURL = u }.buttonStyle(.borderless).foregroundStyle(Theme.text)
                        Button { share = ShareItem(url: u) } label: { Image(systemName: "square.and.arrow.up") }
                            .buttonStyle(.borderless).foregroundStyle(Theme.text2)
                    }
                }
            } header: { Text("自动备份（最近 7 天）") } footer: {
                Text("每天第一次打开或离开 App 时，会自动在本机留一份备份。也可以在「文件」App →「我的 iPhone」→「小满」→「自动备份」里找到。删除 App 时这些文件也会被删除，换手机前请手动导出。")
            }
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("备份恢复")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear(perform: loadSnapshots)
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

    private var lastText: String {
        if let l = store.s.lastBackup { return "上次导出：\(l)" }
        return "还没有导出过"
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

// MARK: - 导出数据（表格）

struct ExportView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @State private var range = "all"
    @State private var from = DK.add(DK.todayDate, -29)
    @State private var to = DK.todayDate
    @State private var share: ShareItem?

    private var span: (String, String) {
        switch range {
        case "month": return (DK.key(DK.monthStart(DK.todayDate)), DK.today)
        case "year": return (DK.key(DK.calendar.date(from: DateComponents(year: DK.year(DK.todayDate), month: 1, day: 1)) ?? DK.todayDate), DK.today)
        case "custom": return (DK.key(min(from, to)), DK.key(max(from, to)))
        default: return ("0000-00-00", "9999-99-99")
        }
    }

    var body: some View {
        List {
            Section {
                Picker("时间范围", selection: $range) {
                    Text("全部").tag("all"); Text("本月").tag("month"); Text("今年").tag("year"); Text("自定义").tag("custom")
                }
                if range == "custom" {
                    DatePicker("开始", selection: $from, in: ...Date(), displayedComponents: .date)
                    DatePicker("结束", selection: $to, in: ...Date(), displayedComponents: .date)
                }
            } header: { Text("范围") }

            Section {
                Button { export("打卡记录", Backup.recordRows(store.s, from: span.0, to: span.1)) } label: {
                    RowLabel(icon: "checklist", title: "打卡记录", sub: "\(count(Backup.recordRows(store.s, from: span.0, to: span.1))) 条，含打卡时间和日志")
                }
                Button { export("笔记", Backup.noteRows(store.s, from: span.0, to: span.1)) } label: {
                    RowLabel(icon: "book.closed", title: "笔记", sub: "\(count(Backup.noteRows(store.s, from: span.0, to: span.1))) 篇")
                }
                Button { export("习惯列表", Backup.cardRows(store.s)) } label: {
                    RowLabel(icon: "square.grid.2x2", title: "习惯列表", sub: "\(store.s.cards.count + store.s.archived.count) 个（不受时间范围影响）")
                }
            } header: { Text("导出为表格（CSV）") } footer: {
                Text("CSV 可以用 Numbers、Excel、WPS 打开。点了之后选「存储到文件」，或者直接发给自己。")
            }
        }
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("导出数据")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $share) { s in ShareSheet(items: [s.url]).presentationDetents([.medium, .large]) }
    }

    private func count(_ rows: [[String]]) -> Int { max(0, rows.count - 1) }

    private func export(_ name: String, _ rows: [[String]]) {
        guard rows.count > 1 else { toaster.show("这段时间没有可以导出的内容", gray: true); return }
        let suffix = range == "all" ? DK.today : "\(span.0)至\(span.1)"
        guard let d = Backup.csv(rows).data(using: .utf8), let u = Backup.tempFile(name: "小满-\(name)-\(suffix).csv", data: d) else {
            toaster.show("导出失败，请重试"); return
        }
        share = ShareItem(url: u)
    }
}
