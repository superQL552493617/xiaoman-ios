import XCTest
import StoreKitTest

/// 点一遍真实界面：网页版（上架用的界面）和原生版的会员页，开通年度卡（免费试用），截图留档
final class VipUITests: XCTestCase {

    override func setUp() { continueAfterFailure = true }

    private func session() throws -> SKTestSession {
        let s = try SKTestSession(configurationFileNamed: "ProductsCN")
        s.resetToDefaultState()
        s.disableDialogs = true
        s.clearTransactions()
        s.storefront = "CHN"
        return s
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            let dir = URL(fileURLWithPath: home).appendingPathComponent("iapshots")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? png.write(to: dir.appendingPathComponent(name + ".png"))
        }
    }

    func test1WebVip() throws {
        let s = try session(); _ = s
        let app = XCUIApplication()
        app.launchArguments = ["-testVIP", "NO", "-uiMode", "web", "-shotJS", Data("S.vip=false;S.prefs.plan='free';save();openVip()".utf8).base64EncodedString()]
        app.launch()
        sleep(9)
        shot(app, "1-web-vip")
        let cta = app.webViews.buttons.matching(NSPredicate(format: "label CONTAINS '免费试用'")).firstMatch
        if cta.waitForExistence(timeout: 6) {
            cta.tap()
        } else {
            // 找不到按钮时按位置点（底部大按钮）
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86)).tap()
        }
        sleep(6)
        shot(app, "2-web-after-buy")
        app.terminate()
    }

    func test2NativeVip() throws {
        let s = try session(); _ = s
        let app = XCUIApplication()
        app.launchArguments = ["-testVIP", "NO", "-uiMode", "native", "-shotTab", "today", "-shotVip", "1"]
        app.launch()
        sleep(6)
        shot(app, "3-native-vip")
        let b = app.buttons.matching(NSPredicate(format: "label CONTAINS '免费试用'")).firstMatch
        if b.waitForExistence(timeout: 6) { b.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.87)).tap() }
        sleep(5)
        shot(app, "4-native-after-buy")
        app.terminate()
    }
}
