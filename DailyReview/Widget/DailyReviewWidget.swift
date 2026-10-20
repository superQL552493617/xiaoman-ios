import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 数据

struct HabitEntry: TimelineEntry {
    let date: Date
    let cards: [Card]
    let done: Set<String>
    let shape: String
    let line: String
    let opts: WidgetPrefs
    let journal: [JournalEntry]

    var total: Int { cards.count }
    var doneCount: Int { cards.filter { done.contains($0.id) }.count }
    var allDone: Bool { total > 0 && doneCount == total }
    /// 还没打卡的（打完的自动消失）
    var left: [Card] { cards.filter { !done.contains($0.id) } }

    static func load(_ date: Date = Date()) -> HabitEntry {
        let s = Persistence.load() ?? AppState.seeded()
        let k = DK.key(date)
        let cs = s.checkCards.filter { s.scheduled($0, k) }
        let done = Set(cs.filter { s.isChecked(k, $0.id) }.map { $0.id })
        return HabitEntry(date: date, cards: cs, done: done, shape: CardShapes.normalize(s.prefs.shape), line: s.prefs.line,
                          opts: s.prefs.widget ?? WidgetPrefs(), journal: s.journalList(k))
    }

    static var sample: HabitEntry {
        let s = AppState.seeded()
        return HabitEntry(date: Date(), cards: s.cards, done: Set(s.cards.prefix(2).map { $0.id }), shape: "circle", line: "solid",
                          opts: WidgetPrefs(), journal: [])
    }
}

struct HabitProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) {
        completion(context.isPreview ? .sample : .load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
        let now = Date()
        // 过了零点要刷新成新的一天
        let midnight = DK.add(DK.calendar.startOfDay(for: now), 1).addingTimeInterval(5)
        completion(Timeline(entries: [.load(now), .load(midnight)], policy: .after(midnight)))
    }
}

/// 小组件上的一个习惯圆点（未打卡的样子：白底 + 灰边 + 图标）
struct WidgetDot: View {
    let card: Card
    var shape: String
    var size: CGFloat
    var body: some View {
        let cs = CardShape(id: shape)
        ZStack {
            cs.fill(Theme.adaptive("#FFFFFF", "#1E1E21"))
            cs.stroke(Theme.adaptive("#E2E2E6", "#3A3A3E"), lineWidth: 1.3)
            if card.ic == "text" {
                Text(card.text.isEmpty ? String(card.name.prefix(1)) : card.text)
                    .font(.system(size: size * 0.31, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: card.hex))
                    .lineLimit(1).minimumScaleFactor(0.5)
            } else {
                Image(IconCatalog.assetName(card.icon)).resizable().scaledToFit().frame(width: size * 0.62, height: size * 0.62)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 打卡小组件（和网页版预览一样：小号 4 个 / 中号 8 个 / 大号 16 个，打完的自动消失）

struct HabitWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitEntry

    private var n: Int { family == .systemSmall ? 4 : family == .systemMedium ? 8 : 16 }
    private var cols: Int { family == .systemSmall ? 2 : 4 }
    private var dot: CGFloat { family == .systemLarge ? 44 : 40 }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日打卡").font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Text("\(entry.doneCount)/\(entry.total)").font(.system(size: 12.5)).monospacedDigit().opacity(0.6)
            }
            .foregroundStyle(Theme.adaptive("#1C1C1E", "#F2F2F7"))
            if entry.cards.isEmpty || entry.allDone {
                VStack(spacing: 6) {
                    Image("prog_palm").resizable().scaledToFit().frame(width: family == .systemSmall ? 44 : 52)
                        .saturation(entry.allDone ? 1 : 0).opacity(entry.allDone ? 1 : 0.6)
                    Text(entry.allDone ? "今天都完成啦" : "今天没有需要打卡的习惯").font(.system(size: 12)).foregroundStyle(Theme.adaptive("#6E6E73", "#A1A1A6"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let items = Array(entry.left.prefix(n))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: cols), spacing: 4) {
                    ForEach(items) { c in item(c) }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder private func item(_ c: Card) -> some View {
        let v = VStack(spacing: 2) {
            WidgetDot(card: c, shape: entry.shape, size: dot)
            if family != .systemSmall {
                Text(c.name).font(.system(size: 10)).foregroundStyle(Theme.adaptive("#1C1C1E", "#F2F2F7")).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        if entry.opts.tap {
            Button(intent: ToggleHabitIntent(cardId: c.id)) { v }.buttonStyle(.plain)
        } else {
            Link(destination: URL(string: "xiaoman://today")!) { v }
        }
    }
}

struct DailyReviewWidget: Widget {
    let kind = "DailyReviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            HabitWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBG(hex: entry.opts.bgHex) }
                .widgetURL(URL(string: "xiaoman://today"))
        }
        .configurationDisplayName("今日打卡")
        .description("显示今天还没打卡的习惯，点图标直接打卡，打完的自动消失。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct WidgetBG: View {
    var hex: String?
    var body: some View {
        if let hex { Color(hex: hex) } else { Theme.adaptive("#FFFFFF", "#262624") }
    }
}

// MARK: - 笔记小组件（点一下直接写当天的笔记）

struct JournalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitEntry
    private var ink: Color { Theme.adaptive("#1C1C1E", "#F2F2F7") }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("笔记").font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Text("今天 \(entry.journal.count) 篇").font(.system(size: 12.5)).opacity(0.6)
            }
            .foregroundStyle(ink)
            switch family {
            case .systemSmall:
                VStack(spacing: 6) {
                    bubble.frame(width: 62, height: 55)
                    Text("写一篇").font(.system(size: 12.5)).foregroundStyle(ink.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .systemMedium:
                HStack(spacing: 10) {
                    bubble.frame(width: 38, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        if let last = entry.journal.last {
                            Text(last.displayTitle).font(.system(size: 14, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                            Text(String(last.text.prefix(24))).font(.system(size: 12)).foregroundStyle(ink.opacity(0.6)).lineLimit(1)
                        } else {
                            Text("今天想记点什么？").font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
                            Text("点这里开始写").font(.system(size: 12)).foregroundStyle(ink.opacity(0.6))
                        }
                    }
                }
                lines(2)
            default:
                VStack(alignment: .leading, spacing: 8) {
                    if entry.journal.isEmpty {
                        Text("今天还没有笔记").font(.system(size: 13)).foregroundStyle(ink.opacity(0.6))
                    }
                    ForEach(entry.journal.suffix(3).reversed()) { e in
                        VStack(alignment: .leading, spacing: 1) {
                            HStack {
                                Text(e.displayTitle).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(ink).lineLimit(1)
                                Spacer()
                                Text(DK.hm(e.c)).font(.system(size: 11.5)).foregroundStyle(ink.opacity(0.5))
                            }
                            Text(String(e.text.prefix(30))).font(.system(size: 12)).foregroundStyle(ink.opacity(0.6)).lineLimit(1)
                        }
                    }
                }
                lines(4)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    bubble.frame(width: 20, height: 18)
                    Text("点这里写一篇").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "#4FAE78"))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var bubble: some View {
        Image("evb_jr").renderingMode(.template).resizable().scaledToFit().foregroundStyle(Color(hex: "#4FAE78"))
    }

    private func lines(_ n: Int) -> some View {
        VStack(spacing: 10) {
            ForEach(0..<n, id: \.self) { _ in Rectangle().fill(ink.opacity(0.08)).frame(height: 1) }
        }
        .padding(.top, 4)
    }
}

struct JournalWidget: Widget {
    let kind = "XiaomanJournalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            JournalWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBG(hex: entry.opts.bgHex) }
                .widgetURL(URL(string: "xiaoman://journal"))
        }
        .configurationDisplayName("笔记")
        .description("点一下直接写今天的笔记。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - 控制中心按钮（iOS 18 起：下拉控制中心 → 添加控制 → 搜「小满」）

@available(iOS 18.0, *)
struct XiaomanControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "site.xiaomanhabit.app.control.open") {
            ControlWidgetButton(action: OpenXiaomanIntent()) {
                Label("小满打卡", systemImage: "leaf.fill")
            }
        }
        .displayName("小满打卡")
        .description("打开小满，记录今天的打卡")
    }
}

@main
struct DailyReviewWidgets: WidgetBundle {
    var body: some Widget {
        DailyReviewWidget()
        JournalWidget()
        if #available(iOS 18.0, *) {
            XiaomanControl()
        }
    }
}
