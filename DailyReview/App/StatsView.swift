import SwiftUI

// MARK: - 统计页（按网页版复刻）

struct StatsView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var router: Router
    @Environment(\.colorScheme) private var scheme

    @State private var per: Period = .week
    @State private var off = 0
    @State private var spin = 0.0
    @State private var sheet: StatSheet?
    @State private var generating = false
    @State private var streamTick = 0
    @State private var shake: [Period: Int] = [:]
    @State private var scrollBody = 0

    enum StatSheet: Identifiable {
        case heat, days, journal, sumInfo, rules, history
        var id: Int { hashValue }
    }

    private var dark: Bool { scheme == .dark }

    var body: some View {
        let st = store.s.periodStats(per, off)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    seg.padding(.top, 4)
                    nav(st).padding(.top, 12).padding(.bottom, 4)
                    kpis(st).padding(.top, 12).padding(.bottom, 4)
                    card { completion(st) }
                    card { barCard }
                    card { events(st) }
                    card { summaryCard(proxy) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
            .background(PageBG().ignoresSafeArea())
            .onChange(of: scrollBody) { _, _ in withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo("aiBody", anchor: .center) } }
        }
        .onAppear {
            // 截图测试用：-shotStat heat / days / info / gen / bottom
            let a = UserDefaults.standard.string(forKey: "shotStat")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                switch a {
                case "heat": sheet = .heat
                case "days": sheet = .days
                case "info": sheet = .sumInfo
                case "gen": gen(store.s.sumTarget(.week, -1))
                case "bottom": scrollBody += 1
                default: break
                }
            }
        }
        .onChange(of: per) { _, _ in syncLast() }
        .onChange(of: off) { _, _ in syncLast() }
        .sheet(item: $sheet) { s in
            Group {
                switch s {
                case .heat: HeatSheet(per: per, off: off)
                case .days: DaysSheet(st: st) { k in
                    sheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { router.goDay = k }
                }
                case .journal: JournalRangeSheet(from: DK.key(st.start), to: DK.key(st.until), label: st.label)
                case .sumInfo: SumInfoSheet(t: store.s.sumTarget(.week, sumOff(.week))) {
                    sheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { gen(store.s.sumTarget(.week, sumOff(.week))) }
                }
                case .rules: SumRulesSheet()
                case .history: SumHistorySheet { key in
                    sheet = nil
                    openHistory(key)
                }
                }
            }
            .environmentObject(store).environmentObject(toaster).environmentObject(router)
            .presentationCornerRadius(30)
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: 顶栏：统计 · 刷新

    private var topBar: some View {
        ZStack {
            Text("统计").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body)
            HStack {
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.5)) { spin -= 360 }
                    store.objectWillChange.send()
                    toaster.show("统计已刷新")
                } label: {
                    Image("st_undo").renderingMode(.template).resizable().frame(width: 19, height: 19)
                        .foregroundStyle(PT.body)
                        .rotationEffect(.degrees(spin))
                        .frame(width: 40, height: 40).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("刷新统计")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(scheme == .dark ? Color(hex: "#1E1E1D").opacity(0.9) : Color(hex: PageTheme.base(store.s.prefs.pageBg)).opacity(0.88))
        .background(.ultraThinMaterial)
    }

    // MARK: 周 / 月 / 年

    private func perColors(_ p: Period) -> (txt: String, onBg: String, onTxt: String, sh: Color) {
        switch p {
        case .week: return dark ? ("#8FA9C9", "#2C4260", "#D8E7FA", .clear) : ("#5C7EA6", "#D6E6F8", "#1F4570", Color(red: 50/255, green: 100/255, blue: 170/255).opacity(0.35))
        case .month: return dark ? ("#C9AE6A", "#5A4815", "#FBE3A0", .clear) : ("#A07A1E", "#FFE39A", "#5E4006", Color(red: 190/255, green: 140/255, blue: 20/255).opacity(0.4))
        case .year: return dark ? ("#93B386", "#2F4A26", "#CDEBBE", .clear) : ("#5E8A55", "#D3EDC6", "#2E5A28", Color(red: 70/255, green: 130/255, blue: 50/255).opacity(0.4))
        }
    }

    private var seg: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases) { p in
                let on = p == per, c = perColors(p)
                Button {
                    Feedback.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { per = p; off = 0 }
                } label: {
                    Text(p.name).font(.system(size: 14, weight: on ? .heavy : .semibold))
                        .foregroundStyle(Color(hex: on ? c.onTxt : c.txt))
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background {
                            if on { Capsule().fill(Color(hex: c.onBg)).shadow(color: c.sh, radius: 3, y: 2) }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(LinearGradient(colors: dark ? [Color(hex: "#1E2733"), Color(hex: "#2E2918"), Color(hex: "#1F2A1C")]
                                                         : [Color(hex: "#EEF4FC"), Color(hex: "#FFF6DC"), Color(hex: "#EDF6E8")], startPoint: .leading, endPoint: .trailing)))
        .overlay(Capsule().strokeBorder(Color(red: 120/255, green: 100/255, blue: 60/255).opacity(0.06), lineWidth: 1))
    }

    private func nav(_ st: PeriodStats) -> some View {
        HStack(spacing: 18) {
            Button { Feedback.tap(); withAnimation { off -= 1 } } label: {
                Text("‹").font(.system(size: 22)).foregroundStyle(Theme.adaptive("#5E5E66", "#AEAEB2")).frame(width: 34, height: 34)
            }
            .accessibilityLabel("上一段")
            Button { Feedback.tap(); sheet = .heat } label: {
                HStack(spacing: 6) {
                    Text(st.label).font(.system(size: 15, weight: .bold)).foregroundStyle(PT.body)
                    Image("st_percal").renderingMode(.template).resizable().frame(width: 15, height: 15)
                        .foregroundStyle(Color(hex: dark ? "#8E8CFF" : "#5E5CE6"))
                }
                .padding(.horizontal, 12).frame(minWidth: 120).frame(height: 34)
                .background(Capsule().fill(Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.1)))
            }
            .accessibilityLabel("查看\(st.label)的打卡日历")
            Button { Feedback.tap(); withAnimation { off = min(0, off + 1) } } label: {
                Text("›").font(.system(size: 22)).foregroundStyle(Theme.adaptive("#5E5E66", "#AEAEB2")).frame(width: 34, height: 34)
            }
            .disabled(off >= 0).opacity(off >= 0 ? 0.25 : 1)
            .accessibilityLabel("下一段")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: 四个彩色数字

    private struct KC { let k1, k2, kt, ks: String; let sh: Color; let dk1, dk2, dkt, dks: String }
    private let kcs: [KC] = [
        KC(k1: "#E9F6E2", k2: "#C6E6B6", kt: "#2E5A28", ks: "#5E8455", sh: Color(red: 70/255, green: 130/255, blue: 50/255).opacity(0.45), dk1: "#26361F", dk2: "#1B2716", dkt: "#CDEBBE", dks: "#93B386"),
        KC(k1: "#FFF4D2", k2: "#FADB86", kt: "#6A4705", ks: "#8E6D2A", sh: Color(red: 190/255, green: 140/255, blue: 20/255).opacity(0.45), dk1: "#3A3016", dk2: "#2A220F", dkt: "#FBE3A0", dks: "#C2A866"),
        KC(k1: "#E7F0FC", k2: "#BFD7F3", kt: "#1F4570", ks: "#4D6E92", sh: Color(red: 50/255, green: 100/255, blue: 170/255).opacity(0.42), dk1: "#1E2C3E", dk2: "#16202E", dkt: "#C8DCF6", dks: "#8BA4C2"),
        KC(k1: "#FCEAF2", k2: "#F2C3D7", kt: "#6E2846", ks: "#946079", sh: Color(red: 190/255, green: 80/255, blue: 130/255).opacity(0.4), dk1: "#3A2230", dk2: "#2A1922", dkt: "#F5CDDF", dks: "#BD8DA3")
    ]

    private func kpis(_ st: PeriodStats) -> some View {
        HStack(spacing: 8) {
            kpi(kcs[0], "st_check", Text("\(st.checks)"), "打卡次数", action: nil)
            kpi(kcs[1], "st_ring", Text("\(st.rate)") + Text("%").font(.system(size: 13, weight: .heavy)), "完成率", action: nil)
            kpi(kcs[2], "st_cal", Text("\(st.days)"), "打卡天数 ›") { sheet = .days }
            kpi(kcs[3], "st_pen", Text("\(st.jn)"), "笔记 ›") { sheet = .journal }
        }
    }

    private func kpi(_ k: KC, _ icon: String, _ v: Text, _ label: String, action: (() -> Void)?) -> some View {
        let kt = Color(hex: dark ? k.dkt : k.kt)
        let content = VStack(alignment: .leading, spacing: 6) {
            Image(icon).renderingMode(.template).resizable().frame(width: 17, height: 17)
                .foregroundStyle(kt)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(dark ? kt.opacity(0.16) : Color.white.opacity(0.62)))
            v.font(.system(size: 22, weight: .heavy)).monospacedDigit().foregroundStyle(kt).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 11.5)).foregroundStyle(Color(hex: dark ? k.dks : k.ks)).lineLimit(1).fixedSize()
        }
        .padding(.horizontal, 10).padding(.top, 12).padding(.bottom, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let r = RoundedRectangle(cornerRadius: 18, style: .continuous)
            if dark {
                r.fill(Color(hex: "#0C0C0C")).overlay(r.strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
            } else {
                ZStack {
                    r.fill(k.sh).padding(.horizontal, 16).padding(.vertical, 16).offset(y: 12).blur(radius: 11)
                    r.fill(LinearGradient(colors: [Color(hex: k.k1), Color(hex: k.k2)], startPoint: UnitPoint(x: 0.2, y: 0), endPoint: UnitPoint(x: 0.8, y: 1)))
                        .overlay(alignment: .topTrailing) {
                            Circle().fill(RadialGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)], center: .center, startRadius: 0, endRadius: 39 * 0.7))
                                .frame(width: 78, height: 78).offset(x: 26, y: -30)
                        }
                        .clipShape(r)
                }
            }
        }
        return Group {
            if let action {
                Button { Feedback.tap(); action() } label: { content }.buttonStyle(PressScale(scale: 0.97))
            } else { content }
        }
    }

    // MARK: 卡片外框

    private func card<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 0) { v() }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let r = RoundedRectangle(cornerRadius: 22, style: .continuous)
                if dark {
                    r.fill(Color(hex: "#0C0C0C")).overlay(r.strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
                } else {
                    ZStack {
                        r.fill(Color(red: 60/255, green: 40/255, blue: 10/255).opacity(0.35)).padding(.horizontal, 18).padding(.vertical, 18).offset(y: 12).blur(radius: 13)
                        r.fill(Color.white)
                        r.strokeBorder(Color(red: 70/255, green: 55/255, blue: 30/255).opacity(0.06), lineWidth: 1)
                    }
                }
            }
            .padding(.top, 12)
    }

    private func h3(_ t: String, _ sub: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(t).font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4"))
            if let sub { Text(sub).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Color(hex: "#A39888")) }
        }
        .padding(.horizontal, 2).padding(.bottom, 10)
    }

    // MARK: 完成情况

    @ViewBuilder private func completion(_ st: PeriodStats) -> some View {
        h3("完成情况", "按每个习惯的循环日计算")
        HStack(spacing: 16) {
            CompletionRing(rate: st.rate).frame(width: 132, height: 132)
            ringLegend(st)
        }
        .padding(.leading, 10).padding(.trailing, 14).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(
            dark ? AnyShapeStyle(Color.white.opacity(0.04))
                 : AnyShapeStyle(LinearGradient(stops: [.init(color: Color(hex: "#FFF8E6"), location: 0), .init(color: Color(hex: "#F1F8EA"), location: 0.6), .init(color: Color(hex: "#E6F4EE"), location: 1)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))))
        let rated = st.perCard.filter { $0.rate != nil && $0.slots > 0 }.sorted { ($0.rate ?? 0) > ($1.rate ?? 0) }
        if rated.isEmpty {
            Text("这段时间没有需要打卡的习惯").font(.system(size: 12.5)).foregroundStyle(Theme.adaptive("#5E5E66", "#A1A1A6"))
                .padding(.horizontal, 6).padding(.top, 14)
        } else {
            VStack(spacing: 14) {
                ForEach(rated) { x in habitBar(x) }
            }
            .padding(.top, 14)
        }
    }

    private func ringLegend(_ st: PeriodStats) -> some View {
        let miss = max(0, st.slots - st.done), r = st.rate
        let lv: (String, String, String, String, String) = r >= 85 ? ("状态超棒", "#D8F0DC", "#2F7A52", "#28432F", "#A9E2B8")
            : r >= 65 ? ("稳稳前进", "#E4F3D4", "#4F7D2C", "#2F3F22", "#C3E2A0")
            : r >= 40 ? ("继续加油", "#FFF0C4", "#8A6410", "#433815", "#F5D57B")
            : st.slots > 0 ? ("慢慢来", "#FBE3D6", "#A05A35", "#45291D", "#F0B590") : ("还没开始", "#FBE3D6", "#A05A35", "#45291D", "#F0B590")
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 4) {
                Image("st_star").renderingMode(.template).resizable().frame(width: 12, height: 12)
                Text(lv.0).font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Color(hex: dark ? lv.4 : lv.2))
            .padding(.horizontal, 10).frame(height: 24)
            .background(Capsule().fill(Color(hex: dark ? lv.3 : lv.1)))
            legendRow(true, "已完成", st.done)
            legendRow(false, "未完成", miss)
            GeometryReader { g in
                let total = Double(st.done + miss), w = g.size.width - (st.done > 0 && miss > 0 ? 3 : 0)
                HStack(spacing: 3) {
                    if st.done > 0 {
                        Capsule().fill(LinearGradient(colors: [Color(hex: "#FFCB57"), Color(hex: "#7FC48A")], startPoint: .leading, endPoint: .trailing))
                            .frame(width: total > 0 ? w * Double(st.done) / total : 0)
                    }
                    if miss > 0 { Capsule().fill(Theme.adaptive("#E7E0D3", "#3A3732")) }
                }
            }
            .frame(height: 6).padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(_ on: Bool, _ t: String, _ n: Int) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(on ? "st_ok" : "st_minus").renderingMode(.template).resizable().frame(width: 12, height: 12)
                .foregroundStyle(on ? Color.white : Theme.adaptive("#C2B8A8", "#7D756B"))
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(on ? Color(hex: "#7FC48A") : Theme.adaptive("#FFFFFF", "#2C2A27")))
                .overlay { if !on { RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.adaptive("#E5DED1", "#45423D"), lineWidth: 1.2) } }
            Text(t).font(.system(size: 13)).foregroundStyle(Theme.adaptive("#7A7066", "#A39A8E"))
            Spacer(minLength: 4)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(n)").font(.system(size: 19, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4"))
                Text("次").font(.system(size: 11.5)).foregroundStyle(Theme.adaptive("#A49A8E", "#7D756B"))
            }
        }
        .frame(height: 28)
    }

    private func habitBar(_ x: PerCardStat) -> some View {
        let hc = x.card.hex, rate = x.rate ?? 0
        return HStack(spacing: 11) {
            ProtoDot(card: x.card, on: true, shape: "circle", line: "solid", size: 32)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(x.card.name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4")).lineLimit(1)
                    Text("\(x.done)/\(x.slots)").font(.system(size: 11)).monospacedDigit().foregroundStyle(Theme.adaptive("#A79D90", "#8A8378"))
                    Spacer(minLength: 0)
                    (Text("\(rate)") + Text("%").font(.system(size: 10.5, weight: .heavy)).foregroundColor(dark ? cmix(hc, 0.55, "#F2EDE4").opacity(0.8) : cmix(hc, 0.7, "#2E2620").opacity(0.8)))
                        .font(.system(size: 14, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(dark ? cmix(hc, 0.55, "#F2EDE4") : cmix(hc, 0.7, "#2E2620"))
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(dark ? cmix(hc, 0.14, "#2E2C29") : cmix(hc, 0.11, "#F6F2EB"))
                        Capsule().fill(LinearGradient(colors: [dark ? cmix(hc, 0.5, "#2E2C29") : cmix(hc, 0.45, "#FFFFFF"), Color(hex: hc)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * CGFloat(max(rate, rate > 0 ? 6 : 0)) / 100)
                    }
                }
                .frame(height: 12)
            }
        }
    }

    // MARK: 每天打卡次数

    @ViewBuilder private var barCard: some View {
        h3(per == .year ? "每月打卡次数" : "每天打卡次数", "点柱子看数值")
        BarChartView(points: chartPoints)
    }

    private var chartPoints: [BarChartView.Pt] {
        let pts = store.s.series(per, off)
        let s = store.s.periodRange(per, off).s
        let pastel = ["#BFE3C9", "#FDE2A7", "#F9CDD3", "#CFE0F4", "#E2D8F3", "#FBD9BF", "#CDEBE6", "#F3E3B6", "#D8E9C5", "#F6D3E4", "#D6E3F0", "#EADFCF"]
        return pts.enumerated().map { i, p in
            if per == .year {
                return .init(v: p.value, l: p.label, tip: "\(p.label)月 · \(p.value) 次", fut: p.future, col: pastel[i % 12])
            }
            let d = DK.add(s, i)
            return .init(v: p.value, l: p.label, tip: "\(DK.month(d))月\(DK.day(d))日 · \(p.value) 次", fut: p.future, col: nil)
        }
    }

    // MARK: 新事件

    @ViewBuilder private func events(_ st: PeriodStats) -> some View {
        h3("新事件")
        if st.evs.isEmpty {
            Text("这段时间没有新增、删除或恢复习惯").font(.system(size: 12.5)).foregroundStyle(Theme.adaptive("#5E5E66", "#A1A1A6"))
                .padding(.horizontal, 4).padding(.bottom, 6)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(st.evs.enumerated()), id: \.offset) { _, e in
                    HStack(spacing: 10) {
                        Image(e.type == "del" ? "ev_del" : e.type == "restore" ? "ev_restore" : "ev_add").resizable().frame(width: 26, height: 26)
                        Group {
                            if let c = store.s.cardAny(e.id) { ProtoDot(card: c, on: true, shape: "circle", line: "solid", size: 30) } else { Color.clear }
                        }
                        .frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.type == "del" ? "删除了习惯「\(e.name)」" : e.type == "restore" ? "恢复了习惯「\(e.name)」" : "新增了习惯「\(e.name)」")
                                .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(PT.body).lineLimit(1)
                            Text(DK.md(e.date)).font(.system(size: 12)).foregroundStyle(Color(hex: "#9A9AA3"))
                        }
                    }
                }
            }
        }
    }

    // MARK: 打卡总结

    /// 统计页正在看的那一期已经结束，就总结那一期；否则总结最近结束的一期
    private func sumOff(_ p: Period) -> Int { per == p && off < 0 ? off : -1 }

    private var histCount: Int {
        store.s.aiCache.keys.filter { k in
            let a = k.split(separator: "|")
            return a.count == 2 && ["week", "month", "year"].contains(String(a[0])) && a[1].count == 10
        }.count
    }

    @ViewBuilder private func summaryCard(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 0) {
            Text("打卡总结").font(.system(size: 16, weight: .heavy)).foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4"))
            if histCount > 0 {
                Spacer(minLength: 8)
                Button { Feedback.tap(); sheet = .history } label: {
                    HStack(spacing: 4) {
                        Image("si_clock").renderingMode(.template).resizable().frame(width: 14, height: 14)
                        Text("往期总结 \(histCount)").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Theme.adaptive("#5E554C", "#E8E1D6"))
                    .padding(.horizontal, 11).frame(height: 28)
                    .background(Capsule().fill(Theme.adaptive("#F2EEE6", "#34322E")))
                }
                .buttonStyle(PressScale())
            }
            Button { sheet = .rules } label: {
                Image("st_info").renderingMode(.template).resizable().frame(width: 16, height: 16)
                    .foregroundStyle(Color(hex: "#A39888")).frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
            .accessibilityLabel("总结说明")
            if histCount == 0 { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 2).padding(.bottom, 10)

        VStack(spacing: 10) {
            sumButton(.week)
            sumButton(.month)
            sumButton(.year)
        }
        .disabled(generating)

        VStack(alignment: .leading, spacing: 0) { aiBody }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .top)
            .id("aiBody")

        Text("周总结在手机上直接统计，不联网，每周 1 次。AI 月度、年度总结升级中，敬请期待。")
            .font(.system(size: 11.5)).foregroundStyle(Color(hex: "#A39888")).lineSpacing(3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4).padding(.top, 12)
    }

    private func sumButton(_ p: Period) -> some View {
        let soon = p != .week
        let t = store.s.sumTarget(p, sumOff(p))
        let has = store.s.aiCache[t.key] != nil
        let names: [Period: String] = [.week: "生成你的周度打卡总结", .month: "生成你的月度打卡总结", .year: "生成你的年度打卡总结"]
        let bg: [Period: String] = [.week: "#E7F0FB", .month: "#FFE7A3", .year: "#E9F3E4"]
        let line: [Period: String] = dark ? [.week: "#3E5B80", .month: "#7A6224", .year: "#4C6B42"] : [.week: "#93B4DC", .month: "#4A3F45", .year: "#8DB98A"]
        let sub = soon ? "功能升级中，敬请期待" : (has ? "\(t.label) · 已生成，点击查看" : "可生成 \(t.label)")
        return Button {
            if soon {
                withAnimation(.linear(duration: 0.32)) { shake[p, default: 0] += 1 }
                return
            }
            Feedback.tap()
            sheet = .sumInfo
        } label: {
            HStack(spacing: 10) {
                Image(soon ? "st_bot" : "st_wk").resizable().scaledToFit().frame(width: soon ? 27 : 26, height: soon ? 23 : 24)
                    .rotationEffect(.degrees(-6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(names[p]!).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4"))
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: soon ? "#E9A93C" : "#5CB874")).frame(width: 6, height: 6)
                        Text(sub).font(.system(size: 11.5, weight: .medium)).foregroundStyle(Theme.adaptive("#7D7266", "#A39A8E")).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if soon {
                    Text("即将上线").font(.system(size: 10.5, weight: .heavy))
                        .foregroundStyle(Color(hex: dark ? "#D9C38A" : "#8A6410"))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(dark ? Color.white.opacity(0.08) : Color.white.opacity(0.75)))
                        .overlay { if !dark { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(red: 160/255, green: 120/255, blue: 30/255).opacity(0.25), lineWidth: 1) } }
                }
            }
            .padding(.leading, 14).padding(.trailing, 16).padding(.vertical, 9)
            .frame(minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(dark ? Color(hex: "#161615") : Color(hex: bg[p]!)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color(hex: line[p]!), lineWidth: 1.5))
            .opacity(soon ? 0.82 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale(scale: 0.98))
        .modifier(ShakeX(n: CGFloat(shake[p] ?? 0)))
    }

    @ViewBuilder private var aiBody: some View {
        if generating {
            LoadingDots(text: "正在统计 \(store.s.sumTarget(.week, sumOff(.week)).label) 的数据…")
        } else if let last = store.s.aiLast, let r = store.s.aiCache[last.key] {
            Text(last.label).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Color(hex: "#5E9E52"))
                .padding(.horizontal, 2).padding(.top, 14).padding(.bottom, 6)
            SumResultView(r: r, tick: streamTick)
        }
    }

    // MARK: 生成 / 查看

    private func syncLast() {
        let vKey = "\(per.rawValue)|\(DK.key(store.s.periodRange(per, off).s))"
        if off < 0, store.s.aiCache[vKey] != nil, store.s.aiLast?.key != vKey {
            store.s.aiLast = AILast(key: vKey, label: store.s.sumLabel(store.s.sumTarget(per, off)))
        }
    }

    private func gen(_ t: AppState.SumTarget) {
        if store.s.aiCache[t.key] != nil {
            store.s.aiLast = AILast(key: t.key, label: store.s.sumLabel(t))
            store.save()
            scrollBody += 1
            return
        }
        withAnimation { generating = true }
        scrollBody += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            store.s.aiCache[t.key] = store.s.weekText(t.off)
            store.s.aiLast = AILast(key: t.key, label: store.s.sumLabel(t))
            store.save()
            Feedback.success()
            generating = false
            streamTick += 1
        }
    }

    private func openHistory(_ key: String) {
        let a = key.split(separator: "|").map(String.init)
        guard a.count == 2, let p = Period(rawValue: a[0]) else { return }
        let s = DK.date(a[1]), t = DK.todayDate
        let o: Int
        switch p {
        case .year: o = DK.year(s) - DK.year(t)
        case .month: o = (DK.year(s) - DK.year(t)) * 12 + DK.month(s) - DK.month(t)
        case .week: o = Int((Double(DK.daysBetween(DK.weekStart(of: t, weekStart: store.s.prefs.weekStart), s)) / 7).rounded())
        }
        Feedback.tap()
        per = p; off = o
        store.s.aiLast = AILast(key: key, label: store.s.sumLabel(store.s.sumTarget(p, o)))
        store.save()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { scrollBody += 1 }
    }
}

// MARK: - 完成率圆环（刻度 + 渐变弧 + 中心数字）

struct CompletionRing: View {
    var rate: Int
    @Environment(\.colorScheme) private var scheme
    @State private var shown: Double = 0

    private static let stops: [(Double, Double, Double)] = [(255, 203, 87), (155, 211, 126), (69, 174, 126)]
    static func grad(_ t: Double) -> Color {
        let k = t < 0.5 ? 0 : 1, u = t < 0.5 ? t / 0.5 : (t - 0.5) / 0.5
        let a = stops[k], b = stops[k + 1]
        return Color(red: (a.0 + (b.0 - a.0) * u) / 255, green: (a.1 + (b.1 - a.1) * u) / 255, blue: (a.2 + (b.2 - a.2) * u) / 255)
    }

    private var dark: Bool { scheme == .dark }

    var body: some View {
        GeometryReader { g in
            let k: CGFloat = g.size.width / 100
            ZStack {
                ticks(k)
                inner(k)
                arc(k)
                center
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { shown = Double(rate) } }
        .onChange(of: rate) { _, r in withAnimation(.easeOut(duration: 0.5)) { shown = Double(r) } }
        .accessibilityElement().accessibilityLabel("完成率 \(rate)%")
    }

    /// 48 个刻度
    private func ticks(_ k: CGFloat) -> some View {
        let onC = Color(hex: "#7FC48A"), offC = Color(hex: dark ? "#4A463F" : "#D9D3C3")
        let lim = Double(rate) / 100
        return Canvas { ctx, _ in
            for i in 0..<48 {
                let a: Double = Double(i) / 48 * 2 * Double.pi - Double.pi / 2
                let on: Bool = Double(i) / 48 < lim
                let r1: Double = 46.2
                let r2: Double = on ? 49.0 : 48.2
                let p1 = CGPoint(x: CGFloat(50 + r1 * cos(a)) * k, y: CGFloat(50 + r1 * sin(a)) * k)
                let p2 = CGPoint(x: CGFloat(50 + r2 * cos(a)) * k, y: CGFloat(50 + r2 * sin(a)) * k)
                var p = Path()
                p.move(to: p1)
                p.addLine(to: p2)
                let w: CGFloat = (on ? 1.4 : 1) * k
                ctx.stroke(p, with: .color(on ? onC : offC), style: StrokeStyle(lineWidth: w, lineCap: .round))
            }
        }
    }

    private func inner(_ k: CGFloat) -> some View {
        let cols: [Color] = dark ? [Color(hex: "#151515"), Color(hex: "#0C0C0C")] : [Color.white, Color(hex: "#F3F8EC")]
        let track: Color = dark ? Color.white.opacity(0.07) : Color.white.opacity(0.95)
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: cols, center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 31 * k * 1.6))
                .frame(width: 62 * k, height: 62 * k)
            Circle().stroke(track, lineWidth: 9 * k)
                .frame(width: 76 * k, height: 76 * k)
        }
    }

    @ViewBuilder private func arc(_ k: CGFloat) -> some View {
        if rate > 0 {
            let frac: Double = shown / 100
            let grad = AngularGradient(gradient: Gradient(colors: [Self.grad(0), Self.grad(0.5), Self.grad(1)]), center: .center,
                                       startAngle: .degrees(0), endAngle: .degrees(360 * max(frac, 0.001)))
            let ea: Double = frac * 2 * Double.pi - Double.pi / 2
            let ex: CGFloat = 38 * k * CGFloat(cos(ea)), ey: CGFloat = 38 * k * CGFloat(sin(ea))
            ZStack {
                Circle().trim(from: 0, to: frac)
                    .stroke(grad, style: StrokeStyle(lineWidth: 9 * k))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 76 * k, height: 76 * k)
                Circle().fill(Self.grad(0)).frame(width: 9 * k, height: 9 * k).offset(y: -38 * k)
                ZStack {
                    Circle().fill(Self.grad(1)).frame(width: 9 * k, height: 9 * k)
                    Circle().fill(dark ? Color(hex: "#0C0C0C") : Color.white).frame(width: 3.8 * k, height: 3.8 * k)
                }
                .offset(x: ex, y: ey)
            }
        }
    }

    private var center: some View {
        VStack(spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(rate)").font(.system(size: 27, weight: .heavy)).tracking(-0.5).monospacedDigit()
                Text("%").font(.system(size: 13, weight: .heavy)).opacity(0.75)
            }
            .foregroundStyle(Color(hex: dark ? "#BFE6C8" : "#2F6B4A"))
            Text("完成率").font(.system(size: 11)).foregroundStyle(Color(hex: dark ? "#8FA897" : "#7E9A86"))
        }
    }
}

// MARK: - 柱状图（点柱子看数值）

struct BarChartView: View {
    struct Pt { var v: Int; var l: String; var tip: String; var fut: Bool; var col: String? }
    let points: [Pt]
    @State private var sel: Int?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { g in
            let W: CGFloat = 320, H: CGFloat = 150, top: CGFloat = 16, bot: CGFloat = 22
            let k = g.size.width / W
            let mx = max(1, points.map(\.v).max() ?? 1)
            let nice = mx <= 4 ? 4 : Int(ceil(Double(mx) / 4)) * 4
            let n = max(1, points.count)
            let step = W / CGFloat(n)
            let bw = max(3, min(22, step * 0.62))
            let ph = H - top - bot
            let every = n > 12 ? 5 : 1
            let ink3 = Color(hex: scheme == .dark ? "#8E8E93" : "#9A9AA3")
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    func ln(_ y: CGFloat, _ c: Color) {
                        var p = Path(); p.move(to: CGPoint(x: 0, y: y * k)); p.addLine(to: CGPoint(x: W * k, y: y * k))
                        ctx.stroke(p, with: .color(c), lineWidth: 1)
                    }
                    if let s = sel {
                        ctx.fill(Path(CGRect(x: CGFloat(s) * step * k, y: 0, width: step * k, height: (H - bot) * k)), with: .color(Color.black.opacity(scheme == .dark ? 0.12 : 0.03)))
                    }
                    let grid = Color(red: 118/255, green: 118/255, blue: 128/255)
                    ln(top, grid.opacity(0.18)); ln(top + ph / 2, grid.opacity(0.18)); ln(H - bot, grid.opacity(0.4))
                    ctx.draw(Text("\(nice)").font(.system(size: 10 * k)).foregroundColor(ink3), at: CGPoint(x: W * k, y: (top - 4) * k), anchor: .bottomTrailing)
                    ctx.draw(Text("\(nice / 2)").font(.system(size: 10 * k)).foregroundColor(ink3), at: CGPoint(x: W * k, y: (top + ph / 2 - 4) * k), anchor: .bottomTrailing)
                    for (i, x) in points.enumerated() {
                        let cx = CGFloat(i) * step + step / 2
                        let h = x.v > 0 ? max(3, CGFloat(x.v) / CGFloat(nice) * ph) : 0
                        if h > 0 {
                            let y = H - bot - h, r = min(4, bw / 2, h)
                            let rect = CGRect(x: (cx - bw / 2) * k, y: y * k, width: bw * k, height: h * k)
                            let p = Path(roundedRect: rect, cornerRadii: RectangleCornerRadii(topLeading: r * k, bottomLeading: 0, bottomTrailing: 0, topTrailing: r * k))
                            ctx.fill(p, with: .color(Color(hex: x.col ?? "#BFE3C9")))
                        }
                        if i % every == 0 || i == n - 1 {
                            ctx.draw(Text(x.l).font(.system(size: 10 * k)).foregroundColor(ink3), at: CGPoint(x: cx * k, y: (H - 6) * k), anchor: .bottom)
                        }
                    }
                }
                .frame(width: W * k, height: H * k)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { loc in
                    let i = Int(loc.x / (step * k))
                    if i >= 0 && i < points.count { sel = sel == i ? nil : i; Feedback.tap() }
                }
                if let s = sel, points.indices.contains(s) {
                    let x = points[s]
                    let cx = (CGFloat(s) * step + step / 2) * k
                    let h = x.v > 0 ? max(3, CGFloat(x.v) / CGFloat(nice) * ph) : 0
                    let y = (H - bot - h) * k
                    Text(x.tip).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.adaptive("#FFFFFF", "#1B1B1A"))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(PT.body))
                        .fixedSize()
                        .position(x: min(g.size.width - 60, max(60, cx)), y: max(12, y - 22))
                        .allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(320 / 150, contentMode: .fit)
        .onChange(of: points.count) { _, _ in sel = nil }
    }
}

// MARK: - 左右晃一下（「即将上线」）

struct ShakeX: GeometryEffect {
    var n: CGFloat
    var animatableData: CGFloat { get { n } set { n = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = n - floor(n)
        let x: CGFloat = t == 0 ? 0 : (t < 0.25 ? -16 * t : t < 0.5 ? -4 + 32 * (t - 0.25) : t < 0.75 ? 4 - 24 * (t - 0.5) : -2 + 8 * (t - 0.75))
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

struct LoadingDots: View {
    var text: String
    @State private var on = false
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color(hex: "#5E5CE6")).frame(width: 9, height: 9)
                        .scaleEffect(on ? 1 : 0.5).opacity(on ? 1 : 0.4)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: on)
                }
            }
            Text(text).font(.system(size: 13.5)).foregroundStyle(PT.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 22)
        .onAppear { on = true }
    }
}

/// 网页版存的段落里带 <b>，这里转成加粗
func richText(_ html: String) -> Text {
    var s = html
    for (a, b) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] { s = s.replacingOccurrences(of: a, with: b) }
    var out = Text("")
    var bold = false
    var rest = Substring(s)
    while !rest.isEmpty {
        if let r = rest.range(of: "<[^>]+>", options: .regularExpression) {
            let seg = String(rest[rest.startIndex..<r.lowerBound])
            if !seg.isEmpty { out = out + (bold ? Text(seg).bold() : Text(seg)) }
            let tag = rest[r].lowercased()
            if tag.hasPrefix("<b") { bold = true } else if tag.hasPrefix("</b") { bold = false }
            rest = rest[r.upperBound...]
        } else {
            let seg = String(rest)
            out = out + (bold ? Text(seg).bold() : Text(seg))
            break
        }
    }
    return out
}

struct SumResultView: View {
    let r: AISum
    var tick: Int
    @State private var shown = 99

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image("st_wk").resizable().scaledToFit().frame(width: 16, height: 15)
                Text(stamp).font(.system(size: 12)).foregroundStyle(PT.muted)
            }
            .padding(.bottom, 10)
            ForEach(Array(r.paras.enumerated()), id: \.offset) { i, p in
                richText(p).font(.system(size: 14.5)).foregroundStyle(PT.body).lineSpacing(14.5 * 0.7 - 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
                    .opacity(i < shown ? 1 : 0).offset(y: i < shown ? 0 : 6)
            }
            HStack(alignment: .top, spacing: 10) {
                Image("st_ai").renderingMode(.template).resizable().frame(width: 18, height: 18)
                    .foregroundStyle(Theme.adaptive("#5E5CE6", "#8E8CFF")).padding(.top, 3)
                Text(r.cheer).font(.system(size: 14, weight: .medium)).foregroundStyle(PT.body).lineSpacing(14 * 0.65 - 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.adaptive("#5E5CE624", "#8E8CFF33")))
            .opacity(r.paras.count < shown ? 1 : 0)
        }
        .onAppear {
            if let at = r.at, Date().timeIntervalSince1970 * 1000 - at < 2500 { stream() }
        }
        .onChange(of: tick) { _, _ in stream() }
    }

    private func stream() {
        do {
            shown = 0
            for i in 0...r.paras.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12 * Double(i)) { withAnimation(.easeOut(duration: 0.3)) { shown = i + 1 } }
            }
        }
    }

    private var stamp: String {
        guard let at = r.at else { return "本机计算，每周 1 次" }
        let d = Date(timeIntervalSince1970: at / 1000)
        return "统计于 \(DK.month(d))月\(DK.day(d))日 \(DK.hm(at)) · 本机计算，每周 1 次"
    }
}

// MARK: - 网页版样式的弹出页外框（标题居中、右上角圆形关闭）

private struct SheetH: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// 高度跟着内容走；超过屏幕时可以滚动
struct FitSheet<C: View>: View {
    @ViewBuilder var content: C
    @State private var h: CGFloat = 320
    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 20)
                .background(GeometryReader { g in Color.clear.preference(key: SheetH.self, value: g.size.height) })
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .onPreferenceChange(SheetH.self) { v in if v > 0 { h = v } }
        .presentationDetents([.height(min(h + 10, UIScreen.main.bounds.height * 0.9))])
        .background(Theme.adaptive("#FFFFFF", "#1E1E1D").ignoresSafeArea())
    }
}

struct ProtoSheetHead: View {
    var title: String
    var sub: String? = nil
    var closeLeft = false
    var back: (() -> Void)? = nil
    var onClose: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body)
                if let sub { Text(sub).font(.system(size: 12, weight: .medium)).foregroundStyle(PT.sub) }
            }
            .padding(.bottom, 6)
            HStack {
                if let back {
                    Button(action: back) {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(PT.ink)
                            .frame(width: 48, height: 48).background(Circle().fill(Theme.adaptive("#FFFFFF", "#2F2E2B")).shadow(color: .black.opacity(0.2), radius: 9, y: 6))
                    }
                    .buttonStyle(PressScale(scale: 0.92))
                    .accessibilityLabel("返回")
                } else if closeLeft { closeBtn }
                Spacer()
                if !closeLeft || back != nil { closeBtn }
            }
        }
        .frame(minHeight: 48).padding(.bottom, 14)
    }

    private var closeBtn: some View {
        Button(action: onClose) {
            Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(PT.ink)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.adaptive("#FFFFFF", "#2F2E2B")).shadow(color: .black.opacity(0.2), radius: 9, y: 6))
        }
        .buttonStyle(PressScale(scale: 0.92))
        .accessibilityLabel("关闭")
    }
}

// MARK: - 打卡日历（颜色越深打卡越多）

struct HeatSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @Environment(\.dismiss) private var dismiss
    @State private var edit: JournalTarget?
    @State private var showJr = false
    @Environment(\.colorScheme) private var scheme
    let per: Period
    let off: Int
    @State private var month: Int?
    @State private var dayK: String?

    private struct Cell: Identifiable { let k: String; let d: Date; let n: Int; let fut: Bool; var id: String { k } }

    var body: some View {
        let r = store.s.periodRange(per, off), T = DK.today
        var all: [Cell] = []
        var d = r.s
        while d <= r.e { let k = DK.key(d); all.append(Cell(k: k, d: d, n: k <= T ? store.s.dayCount(k) : 0, fut: k > T)); d = DK.add(d, 1) }
        let cells = all
        return FitSheet {
            VStack(alignment: .leading, spacing: 0) {
                if per == .year && month == nil {
                    ProtoSheetHead(title: r.label, closeLeft: true) { dismiss() }
                    sum(cells)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                        ForEach(0..<12, id: \.self) { m in
                            let list = cells.filter { DK.month($0.d) == m + 1 }
                            let fut = list.first?.fut ?? true
                            let mx = max(1, cells.map(\.n).max() ?? 1)
                            Button { Feedback.tap(); withAnimation { month = m } } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text("\(m + 1)月").font(.system(size: 12.5, weight: .bold)).foregroundStyle(PT.body)
                                        Spacer()
                                        Text("\(list.reduce(0) { $0 + $1.n }) 次").font(.system(size: 11)).monospacedDigit().foregroundStyle(PT.muted)
                                    }
                                    grid(list, big: false, max: mx, gap: 2)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(fut)
                        }
                    }
                    legend
                    Text("颜色越深，那天打卡越多。点一个月份，再点具体某一天查看。").font(.system(size: 12)).foregroundStyle(Theme.adaptive("#5E5E66", "#A1A1A6"))
                        .padding(.horizontal, 6).padding(.top, 8)
                } else {
                    let list = month.map { m in cells.filter { DK.month($0.d) == m + 1 } } ?? cells
                    let mx = max(1, list.map(\.n).max() ?? 1)
                    ProtoSheetHead(title: month.map { "\(DK.year(r.s))年\($0 + 1)月" } ?? r.label, closeLeft: month == nil,
                                   back: month == nil ? nil : { withAnimation { month = nil } }) { dismiss() }
                    sum(list)
                    let ws = store.s.prefs.weekStart == 0 ? 0 : 1
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { i in
                            Text(DK.wdName[(i + ws) % 7]).font(.system(size: 12)).foregroundStyle(PT.muted).frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 4).padding(.bottom, 6)
                    grid(list, big: true, max: mx, gap: 6)
                    legend
                    if let k = dayK {
                        // 选中的那天直接显示在下面（和「回忆」一样的数字 + 时间线），不再一层层弹窗
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(DK.md(k)) 周\(DK.wdName[DK.weekday(k)])").font(.system(size: 17, weight: .bold)).foregroundStyle(PT.body)
                                if let m = store.s.moodOf(k) {
                                    Image(m.asset).resizable().frame(width: 20, height: 20).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
                                    Text(m.name).font(.system(size: 13)).foregroundStyle(PT.muted)
                                }
                                Spacer()
                                Button { Feedback.tap(); router.goDay = k; dismiss() } label: {
                                    Text("去这一天 ›").font(.system(size: 13, weight: .semibold)).foregroundStyle(PT.sub)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)
                            DayMemoryPanel(day: k) { j in edit = JournalTarget(day: k, entryId: j.id) } onJournalList: { showJr = true }
                        }
                        .padding(.top, 18)
                        .id(k)
                        .transition(.opacity)
                    } else {
                        Text("点某一天，查看当天的打卡和笔记。").font(.system(size: 12)).foregroundStyle(Theme.adaptive("#5E5E66", "#A1A1A6"))
                            .padding(.horizontal, 6).padding(.top, 8)
                    }
                }
            }
        }
        .onChange(of: month) { _, _ in dayK = nil }
        .onAppear { if UserDefaults.standard.bool(forKey: "shotHeatDay") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dayK = DK.today } } }
        .fullScreenCover(item: $edit) { t in
            JournalEditor(day: t.day, entryId: t.entryId).environmentObject(store).environmentObject(toaster)
        }
        .sheet(isPresented: $showJr) {
            if let k = dayK {
                JournalRangeSheet(from: k, to: k, label: DK.md(k)).environmentObject(store).environmentObject(toaster)
                    .presentationCornerRadius(30).presentationDragIndicator(.visible)
            }
        }
    }

    @EnvironmentObject var router: Router

    private struct DayK: Identifiable { let k: String; var id: String { k } }

    private func sum(_ list: [Cell]) -> some View {
        let total = list.reduce(0) { $0 + $1.n }, active = list.filter { $0.n > 0 }.count, mx = list.map(\.n).max() ?? 0
        return HStack(spacing: 8) {
            ForEach([(total, "打卡次数"), (active, "打卡天数"), (total > 0 ? mx : 0, "单日最多")], id: \.1) { v in
                VStack(spacing: 0) {
                    Text("\(v.0)").font(.system(size: 20, weight: .semibold)).monospacedDigit().foregroundStyle(PT.body)
                    Text(v.1).font(.system(size: 11.5)).foregroundStyle(PT.muted)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(scheme == .dark ? Color(hex: "#2F2E2B") : Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.08)))
            }
        }
        .padding(.bottom, 14)
    }

    private var ai: Color { Color(hex: scheme == .dark ? "#8E8CFF" : "#5E5CE6") }

    private func lvColor(_ lv: Int) -> Color {
        switch lv {
        case 1: return ai.opacity(0.22)
        case 2: return ai.opacity(0.45)
        case 3: return ai.opacity(0.72)
        case 4: return ai
        default: return Color(red: 118/255, green: 118/255, blue: 128/255).opacity(0.1)
        }
    }

    private func grid(_ list: [Cell], big: Bool, max mx: Int, gap: CGFloat) -> some View {
        let ws = store.s.prefs.weekStart == 0 ? 0 : 1
        let lead = list.first.map { (DK.weekday($0.d) - ws + 7) % 7 } ?? 0
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: 7), spacing: gap) {
            ForEach(0..<lead, id: \.self) { i in Color.clear.aspectRatio(1, contentMode: .fit).id("l\(i)") }
            ForEach(list) { x in
                let lv = x.n > 0 ? min(4, Int(ceil(Double(x.n) / Double(mx) * 4))) : 0
                let today = x.k == DK.today
                RoundedRectangle(cornerRadius: big ? 9 : 3, style: .continuous).fill(lvColor(lv))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if big {
                            ZStack(alignment: .topLeading) {
                                Text("\(DK.day(x.d))").font(.system(size: 15, weight: .semibold)).monospacedDigit()
                                    .foregroundStyle(lv >= 3 ? .white : PT.body)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                if x.n > 0 {
                                    Text("\(x.n)").font(.system(size: 11, weight: .heavy)).monospacedDigit()
                                        .foregroundStyle(Color(hex: lv >= 3 ? "#FFB340" : "#FF9500"))
                                        .padding(.leading, 5).padding(.top, 3)
                                }
                            }
                        }
                    }
                    .overlay {
                        if today { RoundedRectangle(cornerRadius: big ? 9 : 3, style: .continuous).stroke(PT.body, lineWidth: big ? 2 : 1.5) }
                    }
                    .overlay {
                        if big && dayK == x.k {
                            RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color(hex: "#F5B92E"), lineWidth: 2.5).padding(-2.5)
                        }
                    }
                    .opacity(x.fut ? 0.35 : 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard big && !x.fut else { return }
                        Feedback.tap()
                        withAnimation(.easeOut(duration: 0.2)) { dayK = dayK == x.k ? nil : x.k }
                    }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("少").font(.system(size: 11.5)).foregroundStyle(PT.muted)
            ForEach(0..<5, id: \.self) { l in RoundedRectangle(cornerRadius: 4, style: .continuous).fill(lvColor(l)).frame(width: 14, height: 14) }
            Text("多").font(.system(size: 11.5)).foregroundStyle(PT.muted)
        }
        .padding(.top, 12)
    }
}

// MARK: - 某一天：哪些已打卡、哪些没打卡、当天的笔记

struct DayDetailSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let day: String

    var body: some View {
        let due = store.s.checkCards.filter { store.s.scheduled($0, day) && (store.s.cardStart($0).map { $0 <= day } ?? true) }
        let done = store.s.dayCheckins(day).filter { !$0.card.isNote }
        let doneIds = Set(done.map(\.card.id))
        let todo = due.filter { !doneIds.contains($0.id) }
        let jr = store.s.journalList(day)
        let total = Set(due.map(\.id)).union(doneIds).count
        return FitSheet {
            VStack(alignment: .leading, spacing: 0) {
                ProtoSheetHead(title: "\(DK.md(day)) 周\(DK.wdName[DK.weekday(day)])", sub: "完成 \(done.count)/\(total)") { dismiss() }
                if !done.isEmpty {
                    head("已打卡 · \(done.count)")
                    ForEach(done, id: \.card.id) { x in
                        row {
                            ZStack {
                                Circle().fill(PT.fillOn(x.card.hex, dark: false))
                                if x.card.ic == "text" {
                                    Text(x.card.text.isEmpty ? String(x.card.name.prefix(1)) : x.card.text).font(.system(size: 13, weight: .bold)).foregroundStyle(PT.ink)
                                } else {
                                    Image(IconCatalog.assetName(x.card.icon)).resizable().scaledToFit().frame(width: 24, height: 24)
                                }
                            }
                            .frame(width: 38, height: 38)
                            Text(x.card.name).font(.system(size: 15.5, weight: .medium)).foregroundStyle(PT.ink)
                            Spacer()
                            Text(DK.hm(x.rec.t)).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Color(hex: "#2E9E5B"))
                        }
                    }
                }
                if !todo.isEmpty {
                    head("未打卡 · \(todo.count)")
                    ForEach(todo) { c in
                        row {
                            ZStack {
                                Circle().strokeBorder(Theme.adaptive("#E7E7EB", "#3A3A3E"), lineWidth: 1.5)
                                if c.ic == "text" {
                                    Text(c.text.isEmpty ? String(c.name.prefix(1)) : c.text).font(.system(size: 13, weight: .bold)).foregroundStyle(PT.ink)
                                } else {
                                    Image(IconCatalog.assetName(c.icon)).resizable().scaledToFit().frame(width: 24, height: 24)
                                }
                            }
                            .frame(width: 38, height: 38).opacity(0.7)
                            Text(c.name).font(.system(size: 15.5, weight: .medium)).foregroundStyle(PT.sub)
                            Spacer()
                            Text("未打卡").font(.system(size: 13.5, weight: .medium)).foregroundStyle(PT.faint)
                        }
                    }
                }
                if !jr.isEmpty {
                    head("笔记 · \(jr.count)")
                    ForEach(jr) { e in
                        row {
                            Image("dd_jr").renderingMode(.template).resizable().frame(width: 26, height: 23).foregroundStyle(PT.ink).frame(width: 38)
                            Text(e.displayTitle).font(.system(size: 15.5, weight: .medium)).foregroundStyle(PT.ink).lineLimit(1)
                            Spacer()
                            Text(DK.hm(e.c)).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Color(hex: "#2E9E5B"))
                        }
                    }
                }
                if done.isEmpty && todo.isEmpty && jr.isEmpty {
                    Text("这一天没有需要打卡的习惯").font(.system(size: 14)).foregroundStyle(PT.faint).frame(maxWidth: .infinity).padding(.vertical, 24)
                }
            }
        }
    }

    private func head(_ t: String) -> some View {
        Text(t).font(.system(size: 13, weight: .semibold)).foregroundStyle(PT.sub).padding(.horizontal, 6).padding(.top, 14).padding(.bottom, 8)
    }

    private func row<V: View>(@ViewBuilder _ v: () -> V) -> some View {
        HStack(spacing: 12) { v() }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minHeight: 43)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.adaptive("#F5F5F7", "#2A2A28")))
            .padding(.bottom, 8)
    }
}

// MARK: - 这段时间的打卡日

struct DaysSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let st: PeriodStats
    var onPick: (String) -> Void
    @State private var month: Date?

    private var months: [Date] {
        var out: [Date] = []
        var d = DK.monthStart(st.start)
        while d <= st.end { out.append(d); d = DK.calendar.date(byAdding: .month, value: 1, to: d) ?? DK.add(d, 31) }
        return out
    }

    var body: some View {
        let set = Set(st.dayList), ms = months, yr = ms.count > 1
        let cnt = { (m: Date) in set.filter { $0.hasPrefix(String(DK.key(m).prefix(7))) }.count }
        return FitSheet {
            VStack(alignment: .leading, spacing: 0) {
                if yr && month == nil {
                    ProtoSheetHead(title: "\(st.label)的打卡日", sub: "共 \(set.count) 天 · 点月份看那个月") { dismiss() }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                        ForEach(ms, id: \.self) { m in
                            Button { Feedback.tap(); withAnimation { month = m } } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("\(DK.month(m))月").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4"))
                                        Text("\(cnt(m)) 天").font(.system(size: 13, weight: .medium)).foregroundStyle(Color(hex: "#A39888"))
                                    }
                                    miniGrid(m, set)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.adaptive("#FAF8F3", "#262624")))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    let m = month ?? ms.first ?? DK.monthStart(st.start)
                    ProtoSheetHead(title: yr ? "\(DK.year(m))年\(DK.month(m))月的打卡日" : "\(st.label)的打卡日",
                                   sub: "共 \(yr ? cnt(m) : set.count) 天 · 点日期去看那天",
                                   back: yr ? { withAnimation { month = nil } } : nil) { dismiss() }
                    bigGrid(m, set)
                }
            }
        }
    }

    private func lead(_ m: Date) -> Int {
        let ws = store.s.prefs.weekStart == 0 ? 0 : 1
        return (DK.weekday(m) - ws + 7) % 7
    }

    private func inRange(_ k: String) -> Bool { k >= DK.key(st.start) && k <= DK.key(st.end) }

    private func bigGrid(_ m: Date, _ set: Set<String>) -> some View {
        let ws = store.s.prefs.weekStart == 0 ? 0 : 1
        let n = DK.daysInMonth(m)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                Text(DK.wdName[(i + ws) % 7]).font(.system(size: 11.5)).foregroundStyle(Color(hex: "#A39888")).padding(.top, 2).padding(.bottom, 6)
            }
            ForEach(0..<lead(m), id: \.self) { i in Color.clear.frame(height: 40).id("b\(i)") }
            ForEach(1...n, id: \.self) { i in
                let k = DK.key(DK.add(m, i - 1)), on = set.contains(k), r = inRange(k)
                Button { onPick(k) } label: {
                    Text("\(i)").font(.system(size: 15, weight: on ? .bold : .regular)).monospacedDigit()
                        .foregroundStyle(on ? Color(hex: "#2F4B29") : Color(hex: "#C9C1B4"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(on ? Color(hex: "#BFE3C9") : .clear))
                        .overlay { if k == DK.today { Circle().strokeBorder(Color(hex: "#8DB98A"), lineWidth: 1.5) } }
                        .opacity(r ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                .disabled(!on)
            }
        }
    }

    private func miniGrid(_ m: Date, _ set: Set<String>) -> some View {
        let n = DK.daysInMonth(m)
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(13), spacing: 1), count: 7), spacing: 1) {
            ForEach(0..<lead(m), id: \.self) { i in Color.clear.frame(width: 13, height: 13).id("m\(i)") }
            ForEach(1...n, id: \.self) { i in
                let k = DK.key(DK.add(m, i - 1))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(set.contains(k) ? Color(hex: "#8FCB97") : Theme.adaptive("#F1ECE3", "#34322E"))
                    .frame(width: 13, height: 13)
                    .opacity(inRange(k) ? 1 : 0.35)
            }
        }
    }
}

// MARK: - 这段时间的笔记

struct JournalRangeSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var toaster: Toaster
    @Environment(\.dismiss) private var dismiss
    let from: String
    let to: String
    let label: String
    var title: String? = nil
    @State private var edit: JournalTarget?
    @State private var pop: PopMenuState?

    var body: some View {
        let all = store.s.journal.filter { $0.key >= from && $0.key <= to }
            .flatMap { k, v in v.map { (k: k, e: $0) } }
            .sorted { $0.e.c > $1.e.c }
        return FitSheet {
            VStack(alignment: .leading, spacing: 10) {
                ProtoSheetHead(title: title ?? "\(label)的笔记", sub: "共 \(all.count) 篇 · 最近的在上面") { dismiss() }
                if all.isEmpty {
                    Text("\(title == nil ? "这段时间还没有笔记。" : "还没有笔记。")\n在打卡页点「笔记」写下第一篇吧。").font(.system(size: 14)).foregroundStyle(PT.faint)
                        .multilineTextAlignment(.center).lineSpacing(6)
                        .frame(maxWidth: .infinity).padding(.top, 24).padding(.bottom, 30)
                } else {
                    ForEach(all, id: \.e.id) { x in jrCard(x.k, x.e) }
                }
            }
        }
        .overlay { PopMenuLayer(state: $pop) }
        .fullScreenCover(item: $edit) { t in
            JournalEditor(day: t.day, entryId: t.entryId).environmentObject(store).environmentObject(toaster)
        }
    }

    private func jrCard(_ k: String, _ e: JournalEntry) -> some View {
        JournalCardView(day: k, entry: e, lines: 3) {
            edit = JournalTarget(day: k, entryId: e.id)
        } onMore: { f in
            pop = store.journalMenu(day: k, entry: e, anchor: f, toaster: toaster) { edit = JournalTarget(day: k, entryId: e.id) }
        } onDelete: {
            withAnimation(.easeOut(duration: 0.25)) { store.deleteJournal(e.id, on: k) }
            toaster.show("已删除", gray: true)
        }
    }
}

// MARK: - 周度打卡总结说明 + 生成

struct SumInfoSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let t: AppState.SumTarget
    var onGo: () -> Void

    var body: some View {
        let e = store.s.aiCache[t.key]
        let rows: [(String, String, String)] = [
            ("si_cal", "这次生成哪一期", "\(t.label)\(t.picked ? "（统计页正在看的这一期）" : "")。想生成更早的，先在统计页切到那一期，再点这里。"),
            ("si_clock", "什么时候生成", "一周结束后随时可以生成，不会过期。每周只能生成 1 次，生成后不能重新统计。"),
            ("si_chart", "会用到哪些数据", "打卡次数、打卡天数、完成率、各习惯完成情况、新事件，以及笔记和日志的数量。"),
            ("si_shield", "怎么生成", "全部在手机上计算，不联网，也不会读取日志和笔记的内容。")
        ]
        return FitSheet {
            VStack(alignment: .leading, spacing: 0) {
                ProtoSheetHead(title: "周度打卡总结") { dismiss() }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        Image("st_wk").resizable().scaledToFit().frame(width: 38, height: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(e == nil ? "可以生成 \(t.label) 的总结" : "这一期的总结已经生成").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Color(hex: "#3E3532"))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(e.flatMap { $0.at }.map { at in
                                let d = Date(timeIntervalSince1970: at / 1000); return "生成于 \(DK.month(d))月\(DK.day(d))日"
                            } ?? "本机统计，马上就好").font(.system(size: 12)).foregroundStyle(Color(hex: "#7D7266"))
                        }
                        Spacer(minLength: 0)
                        Text("所有人免费").font(.system(size: 10.5, weight: .heavy)).foregroundStyle(Color(hex: "#3F7A3A"))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: "#DDF0D8")))
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "#E7F0FB")))
                    .padding(.bottom, 10)
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                        HStack(alignment: .top, spacing: 11) {
                            Image(r.0).renderingMode(.template).resizable().frame(width: 15, height: 15)
                                .foregroundStyle(Color(hex: "#6B6157"))
                                .frame(width: 28, height: 28)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.adaptive("#F4F0E8", "#2F2E2B")))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.1).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4")).padding(.top, 5)
                                Text(r.2).font(.system(size: 12.5)).foregroundStyle(Theme.adaptive("#7D7266", "#A39A8E")).lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 4).padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if i < rows.count - 1 {
                                Rectangle().stroke(Theme.adaptive("#ECE6DB", "#3A3732"), style: StrokeStyle(lineWidth: 1, dash: [4, 3])).frame(height: 1)
                            }
                        }
                    }
                    Button { onGo() } label: {
                        Text(e == nil ? "生成这一周的总结" : "查看总结").font(.system(size: 15.5, weight: .bold))
                            .foregroundStyle(Theme.adaptive("#FFFFFF", "#2A2724"))
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(Capsule().fill(Theme.adaptive("#3E3532", "#F2EDE4")))
                    }
                    .buttonStyle(PressScale(scale: 0.97))
                    .padding(.top, 14)
                    if e == nil {
                        Text("每周只能生成 1 次，生成后不能重新统计").font(.system(size: 12)).foregroundStyle(Color(hex: "#8F857A"))
                            .frame(maxWidth: .infinity).padding(.top, 8)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 2).padding(.bottom, 18)
            }
        }
    }
}

struct SumRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        FitSheet {
            VStack(alignment: .leading, spacing: 0) {
                ProtoSheetHead(title: "打卡总结说明") { dismiss() }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image("st_wk").resizable().scaledToFit().frame(width: 26, height: 23)
                        Text("周度打卡总结").font(.system(size: 14.5, weight: .bold)).foregroundStyle(Color(hex: "#3E3532"))
                        Spacer()
                        Text("所有人免费").font(.system(size: 10.5, weight: .heavy)).foregroundStyle(Color(hex: "#3F7A3A"))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: "#DDF0D8")))
                    }
                    .padding(.bottom, 2)
                    line("时间", "一周结束后随时可以生成，不会过期。每周只能生成 1 次，生成后不能重新统计。")
                    line("数据", "打卡次数、打卡天数、完成率、各习惯完成情况、新事件，以及笔记和日志的数量。")
                    line("方式", "全部在手机上计算，不联网，也不会读取日志和笔记的内容。")
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#EEF4FC")))
                .padding(.bottom, 10)
                Text("默认生成最近结束的一期；在统计页切到更早的周、月、年，再点按钮就能生成那一期。")
                    .font(.system(size: 11.5)).foregroundStyle(Color(hex: "#A39888")).lineSpacing(3).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.horizontal, 4).padding(.top, 4)
            }
        }
    }

    private func line(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(k).font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "#A39888")).padding(.top, 1)
            Text(v).font(.system(size: 12.5)).foregroundStyle(Color(hex: "#6F665C")).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}

struct SumHistorySheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var onPick: (String) -> Void

    var body: some View {
        let keys = store.s.aiCache.keys.filter { k in
            let a = k.split(separator: "|")
            return a.count == 2 && ["week", "month", "year"].contains(String(a[0])) && a[1].count == 10
        }.sorted { ($0.split(separator: "|").last ?? "") > ($1.split(separator: "|").last ?? "") }
        let groups: [(String, String)] = [("year", "年度 AI 总结"), ("month", "月度 AI 总结"), ("week", "周总结")]
        return FitSheet {
            VStack(alignment: .leading, spacing: 0) {
                ProtoSheetHead(title: "往期总结", sub: "共 \(keys.count) 份 · 点一份查看") { dismiss() }
                if keys.isEmpty {
                    Text("还没有生成过总结").font(.system(size: 13)).foregroundStyle(PT.sub).frame(maxWidth: .infinity).padding(.vertical, 30)
                }
                ForEach(groups, id: \.0) { g in
                    let ks = keys.filter { $0.hasPrefix(g.0 + "|") }
                    if !ks.isEmpty {
                        HStack(spacing: 7) {
                            Image(g.0 == "week" ? "st_wk" : "st_bot").resizable().scaledToFit().frame(width: 24, height: 21)
                            Text(g.1).font(.system(size: 13.5, weight: .heavy)).foregroundStyle(Theme.adaptive("#3E3532", "#F2EDE4"))
                            Spacer()
                            Text("\(ks.count) 份").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Color(hex: "#A39888"))
                        }
                        .padding(.horizontal, 4).padding(.top, 14).padding(.bottom, 8)
                        ForEach(ks, id: \.self) { k in item(k, g.0) }
                    }
                }
            }
        }
    }

    private func item(_ k: String, _ per: String) -> some View {
        let e = store.s.aiCache[k]
        let s = DK.date(String(k.split(separator: "|").last ?? ""))
        let label: String = per == "week" ? "\(DK.md(DK.key(s)))–\(DK.md(DK.key(DK.add(s, 6))))" : per == "month" ? "\(DK.year(s))年\(DK.month(s))月" : "\(DK.year(s))年"
        let pv = (e?.paras.first ?? "").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let sub = (e?.local == true ? "本机统计" : "AI 生成") + (e?.stat.map { " · 完成率 \($0.rate)%" } ?? "")
        let bg: String = per == "week" ? "#EEF4FC" : per == "month" ? "#FFF5D9" : "#EFF6EA"
        return Button { onPick(k) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: "#3E3532"))
                    Text(sub).font(.system(size: 12)).foregroundStyle(Color(hex: "#7D7266"))
                    Text(pv.count > 40 ? String(pv.prefix(40)) + "…" : pv).font(.system(size: 12.5)).foregroundStyle(Color(hex: "#5E554C")).lineLimit(1)
                }
                Spacer()
                Text("›").font(.system(size: 20)).foregroundStyle(Color(hex: "#B5AA9C"))
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.adaptive(bg, "#161615")))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }
}

// MARK: - 旧的总结内容（往期数据兼容）

struct SummaryContent: View {
    let entry: SummaryEntry
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text2)
            ForEach(Array(entry.paras.enumerated()), id: \.offset) { _, p in
                richText(p).font(.system(size: 14.5)).foregroundStyle(Theme.text).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
            Text(entry.cheer).font(.system(size: 13.5)).foregroundStyle(Theme.text2)
        }
    }
}
