import SwiftUI
import WebKit
import StoreKit

// MARK: - 意见反馈（腾讯兔小巢，不需要自己的服务器）

struct FeedbackView: View {
    @EnvironmentObject var store: Store
    @State private var loading = true

    var body: some View {
        ZStack {
            TxcWebView(fields: fields, loading: $loading)
            if loading { ProgressView().controlSize(.large) }
        }
        .pageBackground()
        .navigationTitle("意见反馈")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var fields: [String: String] {
        let P = store.s.prefs
        let nick = P.nick.trimmingCharacters(in: .whitespaces)
        return [
            "openid": P.localId ?? "anonymous",
            "nickname": String((nick.isEmpty || nick == "我" ? "小满用户" : nick).prefix(20)),
            "avatar": "https://txc.qq.com/static/desktop/img/products/def-product-logo.png",
            "clientInfo": DeviceInfo.model,
            "clientVersion": DeviceInfo.appVersion,
            "os": "iOS",
            "osVersion": DeviceInfo.osVersion,
            "customInfo": "build \(DeviceInfo.build)"
        ]
    }
}

struct TxcWebView: UIViewRepresentable {
    static let productURL = URL(string: "https://support.qq.com/product/802265")!
    let fields: [String: String]
    @Binding var loading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = false
        wv.backgroundColor = .clear
        var req = URLRequest(url: Self.productURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        req.httpBody = fields.map { k, v in
            "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&").data(using: .utf8)
        wv.load(req)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: TxcWebView
        init(_ p: TxcWebView) { parent = p }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.loading = false }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.loading = false }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.loading = false }
        }
    }
}

// MARK: - 小组件说明

struct WidgetGuideView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    smallPreview
                    VStack(alignment: .leading, spacing: 6) {
                        Text("桌面小组件").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
                        Text("不用打开 App，在桌面上就能看进度、直接打卡。").font(.system(size: 13.5)).foregroundStyle(Theme.text2)
                    }
                }
                CardBox {
                    Text("添加方法").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                    step(1, "回到桌面，长按空白处，直到图标开始晃动")
                    step(2, "点左上角的「编辑」→「添加小组件」")
                    step(3, "搜索「小满」，选择小号或中号，点「添加小组件」")
                    step(4, "中号小组件上，点习惯图标就能直接打卡")
                }
                Text("如果搜不到，先打开一次 App，再重启手机试试。").font(.system(size: 12.5)).foregroundStyle(Theme.text3)
            }
            .padding(16)
        }
        .pageBackground()
        .navigationTitle("小组件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var smallPreview: some View {
        let cs = store.s.visibleCards(on: DK.today).filter { !$0.isNote }
        let done = cs.filter { store.s.isChecked(DK.today, $0.id) }.count
        return VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Theme.tile, lineWidth: 8)
                Circle().trim(from: 0, to: cs.isEmpty ? 0 : CGFloat(done) / CGFloat(cs.count))
                    .stroke(Theme.green, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                Image("prog_palm").resizable().scaledToFit().frame(width: 30)
            }
            .frame(width: 66, height: 66)
            Text("\(done)/\(cs.count)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
        }
        .frame(width: 110, height: 110)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.card))
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func step(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                .frame(width: 22, height: 22).background(Circle().fill(Theme.yellow))
            Text(t).font(.system(size: 14.5)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 会员

struct VipView: View {
    @EnvironmentObject var purchases: Purchases
    @Environment(\.dismiss) private var dismiss
    @State private var msg: String?

    /// 会员权益：上线前按实际情况修改
    private let perks: [(String, String, String)] = [
        ("infinity", "不限数量的习惯", "免费版可以先体验，会员不设上限"),
        ("paintpalette.fill", "更多配色和图标样式", "让每个习惯更有辨识度"),
        ("chart.bar.xaxis", "高级统计", "更长时间范围的趋势和对比"),
        ("heart.fill", "支持持续更新", "你的支持是更新的动力")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); CloseButton { dismiss() } }.padding(14)
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "crown.fill").font(.system(size: 40)).foregroundStyle(Theme.vipGold)
                    Text(purchases.isVIP ? "你已经是会员" : "开通小满会员").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.text)
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(perks.indices, id: \.self) { i in
                            let p = perks[i]
                            HStack(spacing: 12) {
                                Image(systemName: p.0).font(.system(size: 16)).foregroundStyle(Color(hex: "#C98A1E"))
                                    .frame(width: 36, height: 36).background(Circle().fill(Color(hex: "#FFF3D6")))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.1).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                                    Text(p.2).font(.system(size: 12.5)).foregroundStyle(Theme.text3)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.tile))

                    if purchases.products.isEmpty {
                        Text("暂时无法获取会员价格，请检查网络后重试。")
                            .font(.system(size: 13)).foregroundStyle(Theme.text3).multilineTextAlignment(.center)
                        Button("重新加载") { Task { await purchases.loadProducts() } }
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                            .buttonStyle(PillButtonStyle(fill: Theme.pill))
                    } else {
                        ForEach(purchases.products, id: \.id) { p in
                            Button { Task { await purchases.buy(p) } } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.displayName).font(.system(size: 16, weight: .bold))
                                        Text(p.id == Purchases.yearly ? "按年自动续期，可随时在系统设置里取消" : "一次购买，永久有效")
                                            .font(.system(size: 11.5)).opacity(0.7)
                                    }
                                    Spacer()
                                    Text(p.displayPrice).font(.system(size: 18, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 18).frame(height: 64)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.vipGold))
                            }
                            .buttonStyle(.plain)
                            .disabled(purchases.busy || purchases.isVIP)
                            .opacity(purchases.isVIP ? 0.5 : 1)
                        }
                    }

                    Button("恢复购买") { Task { await purchases.restore() } }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text2)
                        .disabled(purchases.busy)

                    Text("年会员到期前 24 小时内会自动续费，可在「设置 → Apple ID → 订阅」中随时取消。购买即表示同意《用户协议》和《隐私政策》。")
                        .font(.system(size: 11)).foregroundStyle(Theme.text3).multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
                .padding(.horizontal, 20).padding(.bottom, 30)
            }
        }
        .background(Theme.pageBg.ignoresSafeArea())
        .overlay { if purchases.busy { ProgressView().controlSize(.large) } }
        .onChange(of: purchases.message) { _, m in
            if let m { msg = m; purchases.message = nil }
        }
        .alert(msg ?? "", isPresented: Binding(get: { msg != nil }, set: { if !$0 { msg = nil } })) {
            Button("好的") { msg = nil }
        }
    }
}
