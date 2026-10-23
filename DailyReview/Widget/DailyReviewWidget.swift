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

/// 小组件上的一个习惯圆点：用打卡后的样子（卡片颜色填满）更好看，外圈统一一圈虚线
struct WidgetDot: View {
    let card: Card
    var shape: String
    var size: CGFloat
    var body: some View {
        let cs = CardShape(id: shape)
        let col = card.colors
        ZStack {
            cs.fill(col.b)
            cs.stroke(style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [2.6, 2.6]))
                .foregroundStyle(col.base.mix(HexColor("#2A2A2A"), 0.35).color)
                .padding(-2.5)
            if card.ic == "img", let ui = WidgetImages.icon(card) {
                // 自己上传的照片图标：「铺满」盖满整个形状，「一样大」放在中间，都按图标形状裁切
                let side = card.imgFit == "fill" ? size : size * 0.62
                Image(uiImage: ui).resizable().scaledToFill().frame(width: side, height: side).clipShape(cs)
            } else if card.ic == "text" {
                Text(card.text.isEmpty ? String(card.name.prefix(1)) : card.text)
                    .font(.system(size: size * 0.31, weight: .bold, design: .rounded)).foregroundStyle(col.fg)
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
    private var dot: CGFloat { family == .systemLarge ? 38 : family == .systemSmall ? 34 : 36 }
    /// 放不下时分页：右上角「›」翻到下一组
    private var pages: Int { max(1, Int(ceil(Double(entry.left.count) / Double(n)))) }
    private var famKey: String { family == .systemSmall ? "s" : family == .systemMedium ? "m" : "l" }
    /// 每种尺寸各记各的页码，一页一页往后翻，翻到最后一页再回到第一页
    private var page: Int { (UserDefaults(suiteName: Persistence.appGroup)?.integer(forKey: "widgetPage_" + famKey) ?? 0) % pages }

    var body: some View {
        if entry.allDone {
            // 全部打完：左上角一句话，右下角盆栽（小号 1 盆、中号 3 盆、大号一排 5 盆）
            let t = WidgetDay.pick(WidgetDay.done, entry.date)
            IllustratedCard(title: t.0, sub: t.1,
                            art: family == .systemSmall ? "wg_pot1" : family == .systemMedium ? "wg_pots3" : "wg_pots5",
                            artWidth: family == .systemSmall ? 54 : family == .systemMedium ? 132 : 300)
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
                    Button(intent: WidgetNextPageIntent(family: famKey, pages: pages)) {
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: cols), spacing: family == .systemSmall ? 14 : 8) {   // 上下留开一点，不挨在一起
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
        else { Color(hex: "#FBF7EE") }   // 默认米白色
    }
}

// MARK: - 笔记小组件（点一下直接写当天的笔记）

/// 按日期每天换一句（和 App 里「小组件」页的预览用同一个算法）
enum WidgetDay {
    static let prompts: [(String, String)] = [
        ("记录一下今天的自己", "不管好坏，都是生活的一部分。")
    ]
    static let done: [(String, String)] = [
        ("全部打卡完成", "今天的你，很棒。"),
        ("今日份坚持，已收下", "一点一点，都在长大。"),
        ("今天的小目标，都达成了", "好好休息一下吧。"),
        ("完美收工", "明天也一起加油。")
    ]
    static func pick(_ list: [(String, String)], _ date: Date) -> (String, String) {
        let dc = DK.calendar.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let day = Int(((utc.date(from: dc) ?? date).timeIntervalSince1970 / 86400).rounded())
        return list[((day % list.count) + list.count) % list.count]
    }
}

struct JournalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitEntry

    /// 不显示笔记内容（放在桌面上容易被别人看到），只放一句温柔的提示，每天换一句
    private var prompt: (String, String) { WidgetDay.pick(WidgetDay.prompts, entry.date) }

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
