import WidgetKit
import SwiftUI
import AppIntents
import UIKit

// MARK: - 数据

struct HabitEntry: TimelineEntry {
    let date: Date
    let cards: [Card]
    let done: Set<String>
    let shape: String
    let line: String
    let opts: WidgetPrefs
    let journal: [JournalEntry]
    var pageBg = "white"
    var page = 0

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
        let page = UserDefaults(suiteName: Persistence.appGroup)?.integer(forKey: "widgetPage") ?? 0
        return HabitEntry(date: date, cards: cs, done: done, shape: CardShapes.normalize(s.prefs.shape), line: s.prefs.line,
                          opts: s.prefs.widget ?? WidgetPrefs(), journal: s.journalList(k), pageBg: s.prefs.pageBg, page: page)
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
            if card.ic == "img", let ui = WidgetImages.icon(card) {
                // 自己上传的照片图标：「铺满」盖满整个形状，「一样大」放在中间，都按图标形状裁切
                let side = card.imgFit == "fill" ? size : size * 0.62
                Image(uiImage: ui).resizable().scaledToFill().frame(width: side, height: side).clipShape(cs)
            } else if card.ic == "text" {
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

/// 小组件里解码照片图标：先缩成小图，省内存（小组件内存很紧）
enum WidgetImages {
    static func icon(_ c: Card) -> UIImage? {
        guard let ui = ImageData.image(c.icImg) else { return nil }
        return ui.preparingThumbnail(of: CGSize(width: 132, height: 132)) ?? ui
    }
}

/// 插画式小组件：左上角一句话，右下角一幅小插画（笔记小组件、打卡全部完成时共用）
struct IllustratedCard: View {
    @Environment(\.widgetFamily) private var family
    let title: String
    let sub: String
    let art: String
    var artWidth: CGFloat
    private var ink: Color { Theme.adaptive("#1C1C1E", "#F2F2F7") }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(art).resizable().scaledToFit().frame(width: artWidth)
                .padding(.trailing, -6).padding(.bottom, -8)
            VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 6) {
                Text(title)
                    .font(.system(size: family == .systemSmall ? 16 : family == .systemMedium ? 20 : 23, weight: .bold))
                    .foregroundStyle(ink).lineLimit(family == .systemSmall ? 3 : 2).minimumScaleFactor(0.8)
                Text(sub)
                    .font(.system(size: family == .systemSmall ? 11.5 : 13.5))
                    .foregroundStyle(ink.opacity(0.5)).lineLimit(2)
            }
            .frame(maxWidth: family == .systemMedium ? 190 : .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 打卡小组件（和网页版预览一样：小号 4 个 / 中号 8 个 / 大号 16 个，打完的自动消失）

struct HabitWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitEntry

    private var n: Int { family == .systemSmall ? 4 : family == .systemMedium ? 8 : 16 }
    private var cols: Int { family == .systemSmall ? 2 : 4 }
    private var dot: CGFloat { family == .systemLarge ? 38 : 36 }
    /// 放不下时分页：右上角「›」翻到下一组
    private var pages: Int { max(1, Int(ceil(Double(entry.left.count) / Double(n)))) }
    private var page: Int { entry.page % pages }

    var body: some View {
        if entry.allDone {
            // 全部打完：左上角一句话，右下角盆栽（小号 1 盆、中号 3 盆、大号一排 5 盆）
            IllustratedCard(title: "今天都完成啦", sub: "一点一点，都在慢慢长大。",
                            art: family == .systemSmall ? "wg_pot1" : family == .systemMedium ? "wg_pots3" : "wg_pots5",
                            artWidth: family == .systemSmall ? 62 : family == .systemMedium ? 132 : 300)
        } else {
            list
        }
    }

    private var list: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text("今日打卡").font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Text("\(entry.doneCount)/\(entry.total)").font(.system(size: 12.5)).monospacedDigit().opacity(0.6)
                if pages > 1 && !entry.allDone {
                    Button(intent: WidgetNextPageIntent()) {
                        HStack(spacing: 1) {
                            Text("\(page + 1)/\(pages)").font(.system(size: 10, weight: .semibold)).monospacedDigit()
                            Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 6).frame(height: 20)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(Theme.adaptive("#1C1C1E", "#F2F2F7"))
            if entry.allDone {
                EmptyView()
            } else if entry.cards.isEmpty {
                VStack(spacing: 6) {
                    Image("prog_palm").resizable().scaledToFit().frame(width: family == .systemSmall ? 44 : 52)
                        .saturation(entry.allDone ? 1 : 0).opacity(entry.allDone ? 1 : 0.6)
                    Text(entry.allDone ? "今天都完成啦" : "今天没有需要打卡的习惯").font(.system(size: 12)).foregroundStyle(Theme.adaptive("#6E6E73", "#A1A1A6"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let items = Array(entry.left.dropFirst(page * n).prefix(n))
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
                .containerBackground(for: .widget) { WidgetBG(hex: entry.opts.bgHex, theme: entry.pageBg) }
                .widgetURL(URL(string: "xiaoman://today"))
        }
        .configurationDisplayName("今日打卡")
        .description("显示今天还没打卡的习惯，点图标直接打卡，打完的自动消失。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// 默认背景跟随 App 的页面主题；在「小组件」页选了颜色就用选的颜色
struct WidgetBG: View {
    var hex: String?
    var theme: String = "white"
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        if let hex { Color(hex: hex) }
        else if scheme == .dark { Color(hex: "#262624") }
        else {
            let c = ThemeFill.colors(theme)
            LinearGradient(colors: [Color(hex: c.top), Color(hex: c.base)], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - 笔记小组件（点一下直接写当天的笔记）

struct JournalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitEntry

    /// 不显示笔记内容（放在桌面上容易被别人看到），只放一句温柔的提示，每天换一句
    static let prompts: [(String, String)] = [
        ("今天有什么值得记下的小事？", "写下来，日子会更清楚。"),
        ("今天过得好吗？", "随手记两句，留给以后的自己。"),
        ("有什么想留住的瞬间？", "点一下，把它写进今天。"),
        ("今天有让你开心的事吗？", "哪怕很小，也值得记一笔。"),
        ("累了的话，就写几句吧。", "说给自己听，也很好。"),
        ("今天的你，辛苦啦。", "想说的话，都可以放在这里。"),
        ("今天学到了什么新东西？", "记下来，它就是你的了。")
    ]

    /// 按日期每天换一句（和 App 里「小组件」页的预览用同一个算法）
    private var prompt: (String, String) {
        let dc = DK.calendar.dateComponents([.year, .month, .day], from: entry.date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let day = Int(((utc.date(from: dc) ?? entry.date).timeIntervalSince1970 / 86400).rounded())
        return Self.prompts[((day % Self.prompts.count) + Self.prompts.count) % Self.prompts.count]
    }

    var body: some View {
        let p = prompt
        IllustratedCard(title: p.0, sub: p.1, art: "wg_bubble",
                        artWidth: family == .systemSmall ? 64 : family == .systemMedium ? 96 : 150)
    }
}

struct JournalWidget: Widget {
    let kind = "XiaomanJournalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitProvider()) { entry in
            JournalWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBG(hex: entry.opts.bgHex, theme: entry.pageBg) }
                .widgetURL(URL(string: "xiaoman://journal"))
        }
        .configurationDisplayName("笔记")
        .description("点一下直接写今天的笔记，桌面上不会显示笔记内容。")
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
        .description("打开小满记，记录今天的打卡")
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
