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
        .navigationTitle(L("意见反馈"))
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
    /// 私密反馈表单的网址（只有开发者能看到提交的内容）；没有时打开兔小巢
    var url: URL? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 问卷里标题含「用户 ID」的填空题自动填上（免费版问卷不能用链接传参，只能在页面里帮用户填）
    static func fillScript(_ text: String) -> String {
        let v = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        return """
        (function(){var V='\(v)',done=false,n=0;
        function setv(el){var p=el.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;
          Object.getOwnPropertyDescriptor(p,'value').set.call(el,V);
          ['input','change','blur'].forEach(function(t){el.dispatchEvent(new Event(t,{bubbles:true}))})}
        function fill(){var all=document.querySelectorAll('body *');
          for(var i=0;i<all.length;i++){var e=all[i],t=(e.innerText||'').trim();
            if(t.length>60||!/用户\\s*ID/i.test(t))continue;
            if(e.querySelector&&[].some.call(e.children,function(c){return /用户\\s*ID/i.test(c.innerText||'')}))continue;
            var a=e;for(var k=0;k<8&&a;k++){var ins=a.querySelectorAll('input[type=text],input:not([type]),textarea');
              if(ins.length===1){if(!ins[0].value&&!ins[0].dataset.xmf){ins[0].dataset.xmf='1';setv(ins[0])}return}if(ins.length>1)break;a=a.parentElement}}}
        var iv=setInterval(function(){try{fill()}catch(e){}if(++n>120)clearInterval(iv)},500);})();
        """
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        if url != nil, let f = fields["fill"], !f.isEmpty {
            cfg.userContentController.addUserScript(WKUserScript(source: Self.fillScript(f), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = false
        wv.backgroundColor = .clear
        if let u = url { wv.load(URLRequest(url: u)); return wv }
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
                        Text("桌面小组件").font(.app(size: 20, weight: .bold)).foregroundStyle(Theme.text)
                        Text("不用打开 App，在桌面上就能看进度、直接打卡。").font(.app(size: 13.5)).foregroundStyle(Theme.text2)
                    }
                }
                CardBox {
                    Text("添加方法").font(.app(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                    step(1, "回到桌面，长按空白处，直到图标开始晃动")
                    step(2, "点左上角的「编辑」→「添加小组件」")
                    step(3, "搜索「小满」，选择小号或中号，点「添加小组件」")
                    step(4, "中号小组件上，点习惯图标就能直接打卡")
                }
                Text("如果搜不到，先打开一次 App，再重启手机试试。").font(.app(size: 12.5)).foregroundStyle(Theme.text3)
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
            Text("\(done)/\(cs.count)").font(.app(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
        }
        .frame(width: 110, height: 110)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.card))
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func step(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.app(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                .frame(width: 22, height: 22).background(Circle().fill(Theme.yellow))
            Text(t).font(.app(size: 14.5)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

