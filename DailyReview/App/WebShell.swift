import SwiftUI
import WebKit
import UIKit
import LocalAuthentication
import WidgetKit

// MARK: - 网页版界面（把最终版网页原样装进 App，用原生能力补齐：存储、触感、分享导出、反馈、面容 ID、提醒、小组件）

/// 界面模式：web 网页版（默认，和原型完全一致）/ native 原生版（测试中）
enum UIMode {
    static let key = "uiMode"
    static var current: String { UserDefaults.standard.string(forKey: key) ?? "web" }
}

struct WebRootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var purchases: Purchases
    @AppStorage(UIMode.key) private var uiMode = "web"
    @StateObject private var bridge = WebBridge()
    @State private var askSwitch = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        WebContainer(bridge: bridge)
            .ignoresSafeArea()
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .overlay {
                // 页面加载完成前显示启动画面，避免白屏
                if !bridge.ready {
                    ZStack {
                        Color(UIColor.systemBackground).ignoresSafeArea()
                        Image("prog_palm").resizable().scaledToFit().frame(width: 64, height: 64).opacity(0.9)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: bridge.ready)
            .sheet(item: $bridge.feedback) { f in
                NavigationStack {
                    WebFeedbackView(fields: f.fields)
                        .navigationTitle("意见反馈")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { bridge.feedback = nil } } }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in askSwitch = true }
            .onChange(of: phase) { _, p in
                if p == .active { bridge.reloadIfChangedOutside() }
                if p == .background { bridge.flush {} }
            }
            .confirmationDialog("界面模式", isPresented: $askSwitch, titleVisibility: .visible) {
                Button("切换到原生版界面（测试）") {
                    bridge.flush {
                        store.reloadFromDisk()
                        uiMode = "native"
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("当前是网页版界面。原生版还在测试中，数据两边共用。")
            }
    }
}

struct FeedbackFields: Identifiable {
    let id = UUID()
    let fields: [String: String]
}

struct WebFeedbackView: View {
    let fields: [String: String]
    @State private var loading = true
    var body: some View {
        ZStack {
            TxcWebView(fields: fields, loading: $loading)
            if loading { ProgressView().controlSize(.large) }
        }
    }
}

// MARK: - WKWebView 容器

struct WebContainer: UIViewRepresentable {
    @ObservedObject var bridge: WebBridge

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.setURLSchemeHandler(LocalSchemeHandler(), forURLScheme: LocalSchemeHandler.scheme)
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let ucc = cfg.userContentController
        ucc.addScriptMessageHandler(bridge, contentWorld: .page, name: "native")
        ucc.addUserScript(WKUserScript(source: WebBridge.startScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: WebBridge.endScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .systemBackground
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        // 和系统 App 一样：滑到顶部 / 底部继续拉会有弹性回弹，右侧滚动条也会跟着变短
        wv.scrollView.bounces = true
        wv.scrollView.alwaysBounceVertical = true
        wv.scrollView.alwaysBounceHorizontal = false
        wv.scrollView.showsVerticalScrollIndicator = true
        wv.underPageBackgroundColor = .systemBackground
        wv.allowsLinkPreview = false
        wv.navigationDelegate = bridge
        wv.uiDelegate = bridge
        if #available(iOS 16.4, *) { wv.isInspectable = true }
        bridge.webView = wv
        wv.load(URLRequest(url: URL(string: "\(LocalSchemeHandler.scheme)://app/index.html")!))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - 本地页面服务（自定义网址，让网页有固定来源，存储更可靠）

final class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "xiaoman"

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        var name = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if name.isEmpty || name == "index.html" { name = "xiaoman.html" }
        let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        guard let file = Bundle.main.url(forResource: base, withExtension: ext), let data = try? Data(contentsOf: file) else {
            let r = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: [:])!
            task.didReceive(r); task.didFinish(); return
        }
        let mime: String
        switch ext.lowercased() {
        case "html": mime = "text/html; charset=utf-8"
        case "js": mime = "text/javascript"
        case "css": mime = "text/css"
        case "png": mime = "image/png"
        case "json", "webmanifest": mime = "application/json"
        default: mime = "application/octet-stream"
        }
        let r = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                headerFields: ["Content-Type": mime, "Content-Length": "\(data.count)", "Cache-Control": "no-store"])!
        task.didReceive(r)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

// MARK: - 网页 ↔ 原生 通信

@MainActor
final class WebBridge: NSObject, ObservableObject, WKScriptMessageHandlerWithReply, WKNavigationDelegate, WKUIDelegate {
    weak var webView: WKWebView?
    @Published var feedback: FeedbackFields?
    @Published var ready = false
    private var postTask: Task<Void, Never>?
    private var lastWrite = Date.distantPast
    private var asked = false

    /// 页面加载前注入：存储、触感、分享
    static let startScript = """
    (function(){
      var N=function(m){return window.webkit.messageHandlers.native.postMessage(m)};
      window.__XM_NATIVE__=true;
      window.storage={
        get:function(k){return N({cmd:'load'}).then(function(v){return v?{value:v}:null})},
        set:function(k,v){return N({cmd:'save',value:v}).then(function(){return true})}
      };
      try{Object.defineProperty(navigator,'vibrate',{configurable:true,value:function(p){N({cmd:'haptic',kind:Array.isArray(p)?'success':(p>=20?'medium':'light')}).catch(function(){});return true}})}catch(e){}
      var toB64=function(f){return new Promise(function(res,rej){var r=new FileReader();r.onload=function(){res(String(r.result).split(',')[1]||'')};r.onerror=rej;r.readAsDataURL(f)})};
      try{navigator.canShare=function(d){return !!(d&&((d.files&&d.files.length)||d.text||d.url))}}catch(e){}
      try{navigator.share=function(d){d=d||{};return Promise.all((d.files||[]).map(function(f){return toB64(f).then(function(b){return {name:f.name||'file',mime:f.type||'',b64:b}})}))
        .then(function(files){return N({cmd:'share',files:files,text:d.text||'',url:d.url||'',title:d.title||''})})
        .then(function(r){if(r!=='shared'){var e=new Error('cancel');e.name='AbortError';throw e}})}}catch(e){}
    })();
    """

    /// 页面加载后注入：反馈走原生页面、面容 ID 走系统验证
    static let endScript = """
    (function(){
      var N=function(m){return window.webkit.messageHandlers.native.postMessage(m)};
      var sub=HTMLFormElement.prototype.submit;
      HTMLFormElement.prototype.submit=function(){
        if(/support\\.qq\\.com/.test(this.action||'')){var f={};for(var i=0;i<this.elements.length;i++){var el=this.elements[i];if(el.name)f[el.name]=el.value}N({cmd:'feedback',fields:f}).catch(function(){});return}
        return sub.call(this)};
      if(typeof window.faceScan==='function'){
        window.faceScan=function(onOk,label,onFail){N({cmd:'faceid',label:label||''}).then(function(ok){if(ok){onOk&&onOk()}else{onFail&&onFail()}}).catch(function(){onFail&&onFail()})};
      }
    })();
    """

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String: Any], let cmd = body["cmd"] as? String else { replyHandler(nil, nil); return }
        switch cmd {
        case "load":
            replyHandler(Persistence.loadRaw(), nil)
        case "save":
            if let v = body["value"] as? String {
                Persistence.saveRaw(v)
                lastWrite = Date()
                schedulePostSave()
            }
            replyHandler(true, nil)
        case "haptic":
            switch body["kind"] as? String {
            case "success": Feedback.success()
            case "medium": Feedback.check()
            default: Feedback.tap()
            }
            replyHandler(true, nil)
        case "share":
            share(body) { replyHandler($0, nil) }
        case "feedback":
            var f: [String: String] = [:]
            for (k, v) in (body["fields"] as? [String: Any]) ?? [:] { f[k] = "\(v)" }
            f["clientInfo"] = DeviceInfo.model
            f["osVersion"] = DeviceInfo.osVersion
            feedback = FeedbackFields(fields: f)
            replyHandler(true, nil)
        case "faceid":
            let ctx = LAContext()
            var err: NSError?
            guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { replyHandler(false, nil); return }
            ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁小满") { ok, _ in
                DispatchQueue.main.async { replyHandler(ok, nil) }
            }
        default:
            replyHandler(nil, nil)
        }
    }

    /// 网页保存后：刷新小组件、重排提醒（稍等一下，连续修改只做一次）
    private func schedulePostSave() {
        postTask?.cancel()
        postTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
            guard let s = Persistence.load() else { return }
            // 用户新开了提醒（数量比上次多）才请求通知权限，打开 App 时不打扰
            let n = (s.prefs.daily.on ? 1 : 0) + s.cards.reduce(0) { $0 + ($1.reminders ?? []).count }
            let d = UserDefaults.standard
            let last = d.object(forKey: "reminderCount") as? Int
            d.set(n, forKey: "reminderCount")
            if let last, n > last, self?.asked == false {
                self?.asked = true
                _ = await Notifier.shared.requestPermission()
            }
            Notifier.shared.rescheduleAll(s)
        }
    }

    /// 切换界面前，让网页把最后的修改写完
    func flush(_ done: @escaping () -> Void) {
        webView?.evaluateJavaScript("try{typeof saveNow==='function'&&saveNow()}catch(e){}") { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { done() }
        }
    }

    /// 回到前台：如果小组件改过数据，就重新载入页面
    func reloadIfChangedOutside() {
        guard let m = Persistence.modified, m > lastWrite.addingTimeInterval(1) else { return }
        lastWrite = Date()
        webView?.reload()
    }

    private func share(_ body: [String: Any], done: @escaping (String) -> Void) {
        var items: [Any] = []
        for f in (body["files"] as? [[String: Any]]) ?? [] {
            guard let b64 = f["b64"] as? String, let data = Data(base64Encoded: b64) else { continue }
            let name = (f["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "file"
            if let u = Backup.tempFile(name: name, data: data) { items.append(u) }
        }
        if items.isEmpty {
            if let t = body["text"] as? String, !t.isEmpty { items.append(t) }
            if let u = body["url"] as? String, let url = URL(string: u), !u.isEmpty { items.append(url) }
        }
        guard !items.isEmpty, let top = UIApplication.topViewController() else { done("cancel"); return }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in done(completed ? "shared" : "cancel") }
        if let pop = vc.popoverPresentationController { pop.sourceView = top.view; pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 40, width: 1, height: 1) }
        top.present(vc, animated: true)
    }

    // 外部链接用系统浏览器打开，本地页面留在 App 里
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if url.scheme == LocalSchemeHandler.scheme || url.scheme == "about" || url.scheme == "blob" || url.scheme == "data" {
            decisionHandler(.allow); return
        }
        if action.navigationType == .linkActivated || action.targetFrame == nil || action.targetFrame?.isMainFrame == true {
            UIApplication.shared.open(url)
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { UIApplication.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.ready = true }
    }

    // 页面进程被系统回收时自动重新加载
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    // 网页里的 alert / confirm / prompt
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "好的", style: .default) { _ in completionHandler() })
        guard let top = UIApplication.topViewController() else { completionHandler(); return }
        top.present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
        guard let top = UIApplication.topViewController() else { completionHandler(false); return }
        top.present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(a.textFields?.first?.text) })
        guard let top = UIApplication.topViewController() else { completionHandler(nil); return }
        top.present(a, animated: true)
    }
}

// MARK: - 小工具

extension UIApplication {
    static func topViewController() -> UIViewController? {
        let scene = shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

/// 摇一摇：切换界面模式（测试用的隐藏入口）
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { NotificationCenter.default.post(name: .deviceDidShake, object: nil) }
        super.motionEnded(motion, with: event)
    }
}
