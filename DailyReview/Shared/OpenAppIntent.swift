import AppIntents

/// 控制中心「小满打卡」按钮：点一下打开 App
struct OpenXiaomanIntent: AppIntent {
    static var title: LocalizedStringResource = "打开小满"
    static var description = IntentDescription("打开小满，记录今天的打卡")
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult { .result() }
}
