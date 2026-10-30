import Foundation

/// 隐私政策、用户协议、致谢、使用指南的文字。
/// 上线前把【开发者名称】换成你在 App Store 上的开发者名字，并核对内容是否和实际功能一致。
enum LegalText {
    static let updated = "2026 年 10 月 23 日"

    static let updatedEN = "October 23, 2026"
    static let updatedHant = "2026 年 10 月 23 日"

    /// 按当前语言取隐私政策、用户协议、致谢
    static var privacy: String { L10n.lang == "en" ? privacyEN : L10n.lang == "zh-Hant" ? privacyHant : privacyZH }
    static var terms: String { L10n.lang == "en" ? termsEN : L10n.lang == "zh-Hant" ? termsHant : termsZH }
    static var credits: String { L10n.lang == "en" ? creditsEN : L10n.lang == "zh-Hant" ? creditsHant : creditsZH }

    static let privacyEN = """
**Xiaoman Privacy Policy**

Last updated: \(updatedEN)
Effective: \(updatedEN)

Xiaoman ("the App") is developed and operated by independent developer superQL. We take your privacy seriously. This policy explains what information the App handles, why, and your rights.

**1. We don’t collect your personal data**

The App requires no sign-up or login and has no servers of its own. The habits, check-ins, logs, notes, moods, avatar, photo icons and settings you create are stored only on your phone. We can’t see or access any of them.

**2. Phone permissions**

The following permissions are requested only when you use the related feature. You can decline them or turn them off anytime in the system Settings; other features keep working:

• Photos: used when you choose an avatar or a photo habit icon. The selected image is compressed and stored only on your device.
• Camera: used when you take a photo for your avatar or a habit icon.
• Notifications: used for the check-in alarms and daily reminders you set. Reminders are scheduled on your device without going through the network.
• Face ID / Touch ID: used only when you turn on the passcode lock. Verification is done by the system; the App never receives your biometric data.

**3. User ID**

The App generates a random 8-digit user ID on your device and stores it in the system Keychain (if iCloud Keychain is on, it syncs with your Apple ID). It contains no personal identity information and is only used to help us locate issues when you send feedback.

**4. Feedback**

The Feedback page is provided by Tencent Survey (wj.qq.com). To help troubleshoot, your user ID, plan type and app version are filled in automatically when the survey opens. What you enter in the survey (including any contact details and screenshots you choose to leave) is handled by Tencent Survey under its privacy policy and is visible only to the developer. Nothing is sent unless you open the Feedback page.

**5. Features that use the network**

• Check for updates: asks Apple’s App Store for the latest version number; no personal information is sent.
• Premium purchases: purchases, renewals and restores are handled by Apple’s App Store; we never receive your payment information.
• External web pages such as the filing number or the feedback survey are handled by those websites under their own rules.

**6. Third-party SDKs**

The App does not include any third-party SDKs (including advertising, analytics or push SDKs).

**7. Storing, exporting and deleting data**

You can export all your data anytime in “Me → Backup”, and reset all check-ins in Settings. Deleting the App deletes all data on your device, so please export a backup first. Because we don’t have your data, we can’t recover or delete it for you; deletion is done entirely by you on your phone.

**8. Children**

If you are under 14, please read this policy and use the App with the consent and guidance of a parent or guardian.

**9. Updates and contact**

If this policy changes significantly, the App will ask you to read and agree to it again. For any questions, comments or complaints, contact us via “Me → Feedback”. We will reply within 15 business days.
"""

    static let privacyHant = """
**小滿記 隱私政策**

更新日期：\(updatedHant)
生效日期：\(updatedHant)

小滿記（以下簡稱"本 App"）由個人開發者 superQL 開發和運營。我們非常重視你的隱私，本政策說明本 App 會處理哪些資訊、為什麼處理以及你的權利。

**一、我們不收集你的個人資料**

本 App 不需要註冊或登入，也沒有自己的伺服器。你建立的習慣、打卡記錄、打卡日誌、筆記、心情、頭像、照片圖示和各項設定，全部只儲存在你的手機上，我們看不到、也拿不到這些內容。

**二、需要用到的手機許可權**

以下許可權都只在你使用相關功能時才會請求，你可以拒絕，也可以隨時在系統"設定"裡關閉，關閉後不影響其他功能：

• 相簿：你主動選擇頭像或習慣照片圖示時使用，選中的圖片壓縮後只儲存在本機。
• 相機：你主動拍照作為頭像或習慣圖示時使用。
• 通知：用於你設定的打卡鬧鐘和每日提醒，提醒在本機安排，不經過網路。
• Face ID / Touch ID：只在你開啟"密碼鎖"時使用，驗證由系統完成，本 App 拿不到你的生物識別資訊。

**三、使用者 ID**

本 App 會在本機隨機生成一個 8 位數字的使用者 ID，儲存在系統鑰匙串裡（如果你開啟了 iCloud 鑰匙串，會隨你的 Apple ID 同步）。它不包含任何個人身份資訊，只用於你在"意見反饋"時方便我們定位問題。

**四、意見反饋**

"意見反饋"頁面由騰訊問卷（wj.qq.com）提供。為了方便排查問題，開啟問卷時會自動填寫你的使用者 ID、會員型別和 App 版本號；你在問卷裡填寫的內容（包括你自願留下的聯絡方式和截圖）由騰訊問卷按照其隱私政策處理，只有開發者能看到。不開啟反饋頁面時，不會傳遞任何資訊。

**五、聯網的功能**

• 檢查更新：會向 Apple 的 App Store 查詢最新版本號，不傳送你的個人資訊。
• 購買會員：會員購買、續訂和恢復購買由 Apple 的 App Store 處理，我們拿不到你的支付資訊。
• 開啟備案號、反饋問卷等外部網頁時，由對應的網站按其規則處理。

**六、第三方 SDK**

本 App 沒有接入任何第三方 SDK（包括廣告、統計和推送 SDK）。

**七、資料的儲存、匯出和刪除**

你可以在"我的 → 備份"中隨時匯出全部資料，也可以在"設定"中重置清零習慣記錄。刪除本 App 會同時刪除本機上的所有資料，請提前匯出備份。因為我們沒有你的資料，所以無法替你找回或刪除，刪除完全由你在手機上完成。

**八、未成年人保護**

如果你是未滿 14 週歲的未成年人，請在監護人同意和指導下閱讀本政策並使用本 App。

**九、政策更新與聯絡我們**

本政策有重要更新時，會在 App 內再次請你閱讀並同意。如有任何疑問、意見或投訴，可以通過"我的 → 意見反饋"聯絡我們，我們會在 15 個工作日內回覆。
"""

    static let termsEN = """
**Xiaoman Terms of Use**

Last updated: \(updatedEN)

Welcome to Xiaoman ("the App"). The App is developed and operated by independent developer superQL. Please read these terms carefully before using the App. By tapping “Agree and continue” or continuing to use the App, you agree to these terms.

**1. Service**

The App offers habit check-ins, check-in logs, notes, moods, stats, reminders, Home Screen widgets and more. Your data is stored on your phone.

**2. Your data**

The content you create in the App belongs to you. Because data is stored only on your device, please export backups regularly in “Me → Backup”. We can’t recover data lost because your phone is lost or damaged, the App is deleted, or for similar reasons.

**3. Premium**

1. Premium comes as Yearly (an auto-renewing yearly subscription), Monthly (an auto-renewing monthly subscription) and Lifetime (a one-time purchase).
2. Yearly includes a 3-day free trial the first time you subscribe. If you don’t cancel at least 24 hours before the trial ends, Apple will charge the yearly price and your membership period begins.
3. Yearly and Monthly renew automatically, charged to your Apple ID account within 24 hours before the current period ends. To cancel, turn off auto-renewal at least 24 hours before the period ends in iPhone Settings → Apple ID → Subscriptions.
4. Purchased memberships can be restored with “Restore purchases” on devices using the same Apple ID.
5. Prices are as shown in the App Store; refunds are handled under Apple’s rules.

**4. Acceptable use**

Please follow applicable laws. Don’t use the App for illegal activities, and don’t post illegal, infringing or harassing content through Feedback.

**5. Disclaimer**

Stats and summaries in the App only organize the data you record yourself. They are for reference only and are not medical, psychological or other professional advice.

**6. Changes**

If these terms change significantly, the App will ask you to read and agree to them again. For questions, contact us via “Me → Feedback”.
"""

    static let termsHant = """
**小滿記 使用者協議**

更新日期：\(updatedHant)

歡迎使用小滿記（以下簡稱"本 App"）。本 App 由個人開發者 superQL 開發和運營。使用本 App 前請仔細閱讀本協議，點"同意並繼續"或繼續使用即表示你同意本協議。

**一、服務內容**

本 App 提供習慣打卡、打卡日誌、筆記、心情、統計、提醒、桌面小工具等功能，資料儲存在你的手機上。

**二、你的資料**

你在本 App 中建立的內容歸你所有。因為資料只儲存在本機，請定期在"我的 → 備份"中匯出備份。因手機丟失、損壞、刪除 App 等原因造成的資料丟失，我們無法幫你找回。

**三、會員服務**

1. 會員分為年度卡（按年自動續期訂閱）、月度卡（按月自動續期訂閱）和永久會員（一次性購買）。
2. 首次開通年度卡可免費試用 3 天。試用期結束前 24 小時內沒有取消的，Apple 會按年度卡價格扣費並開始計算會員期。
3. 年度卡、月度卡到期前 24 小時內，Apple 會自動從你的 Apple ID 帳號扣費續期。如需取消，請在到期前至少 24 小時，在 iPhone"設定 → Apple ID → 訂閱"中關閉自動續期。
4. 已購買的會員可以在使用同一 Apple ID 的裝置上通過"恢復購買"找回。
5. 價格以 App Store 顯示的為準，退款按 Apple 的規定處理。

**四、使用規範**

請遵守法律法規，不要利用本 App 從事違法活動，也不要通過意見反饋釋出違法、侵權、騷擾內容。

**五、免責說明**

本 App 中的統計和總結只是對你自己記錄的資料進行整理，僅供參考，不構成任何醫療、心理或其他專業建議。

**六、協議變更**

協議有重要更新時會在 App 內再次請你閱讀並同意。如有疑問，可以通過"我的 → 意見反饋"聯絡我們。
"""

    static let creditsEN = """
**Credits**

Some habit icons in the App come from **OpenMoji** (openmoji.org), created by designers and developers at HfG Schwäbisch Gmünd and licensed under **CC BY-SA 4.0**. We adjusted the size and format of some icons.

License: creativecommons.org/licenses/by-sa/4.0

System icons are Apple SF Symbols.

Fonts bundled in the App are used under the **SIL Open Font License 1.1** (renamed and subset as the license requires): LXGW WenKai, Yozai, Xiaolai (LXGW), ZCOOL KuaiLe, ZCOOL QingKe HuangYou (ZCOOL), BoutiqueBitmap9x9, Chiron GoRound.


Thank you for showing up and keeping a record.
"""

    static let creditsHant = """
**致謝**

本 App 的部分習慣圖示來自 **OpenMoji**（openmoji.org），由 HfG Schwäbisch Gmünd 的設計師和開發者共同創作，按照 **CC BY-SA 4.0** 協議授權使用。我們對部分圖示做了尺寸和格式上的調整。

協議全文：creativecommons.org/licenses/by-sa/4.0

系統圖示來自 Apple SF Symbols。

App 內建的字型均按 **SIL Open Font License 1.1** 授權使用（已按協議改名、裁剪）：霞鶩文楷、悠哉字型、小賴字型（LXGW）、站酷快樂體、站酷慶科黃油體（站酷）、精品點陣體 9×9、Chiron GoRound。


謝謝每一位願意堅持、願意記錄的你。
"""

    static let privacyZH = """
**小满记 隐私政策**

更新日期：\(updated)
生效日期：\(updated)

小满记（以下简称"本 App"）由个人开发者 superQL 开发和运营。我们非常重视你的隐私，本政策说明本 App 会处理哪些信息、为什么处理以及你的权利。

**一、我们不收集你的个人数据**

本 App 不需要注册或登录，也没有自己的服务器。你创建的习惯、打卡记录、打卡日志、笔记、心情、头像、照片图标和各项设置，全部只保存在你的手机上，我们看不到、也拿不到这些内容。

**二、需要用到的手机权限**

以下权限都只在你使用相关功能时才会请求，你可以拒绝，也可以随时在系统"设置"里关闭，关闭后不影响其他功能：

• 相册：你主动选择头像或习惯照片图标时使用，选中的图片压缩后只保存在本机。
• 相机：你主动拍照作为头像或习惯图标时使用。
• 通知：用于你设置的打卡闹钟和每日提醒，提醒在本机安排，不经过网络。
• 面容 ID / 触控 ID：只在你开启"密码锁"时使用，验证由系统完成，本 App 拿不到你的生物识别信息。

**三、用户 ID**

本 App 会在本机随机生成一个 8 位数字的用户 ID，保存在系统钥匙串里（如果你开启了 iCloud 钥匙串，会随你的 Apple ID 同步）。它不包含任何个人身份信息，只用于你在"意见反馈"时方便我们定位问题。

**四、意见反馈**

"意见反馈"页面由腾讯问卷（wj.qq.com）提供。为了方便排查问题，打开问卷时会自动填写你的用户 ID、会员类型和 App 版本号；你在问卷里填写的内容（包括你自愿留下的联系方式和截图）由腾讯问卷按照其隐私政策处理，只有开发者能看到。不打开反馈页面时，不会传递任何信息。

**五、联网的功能**

• 检查更新：会向 Apple 的 App Store 查询最新版本号，不发送你的个人信息。
• 购买会员：会员购买、续订和恢复购买由 Apple 的 App Store 处理，我们拿不到你的支付信息。
• 打开备案号、反馈问卷等外部网页时，由对应的网站按其规则处理。

**六、第三方 SDK**

本 App 没有接入任何第三方 SDK（包括广告、统计和推送 SDK）。

**七、数据的保存、导出和删除**

你可以在"我的 → 备份"中随时导出全部数据，也可以在"设置"中重置清零习惯记录。删除本 App 会同时删除本机上的所有数据，请提前导出备份。因为我们没有你的数据，所以无法替你找回或删除，删除完全由你在手机上完成。

**八、未成年人保护**

如果你是未满 14 周岁的未成年人，请在监护人同意和指导下阅读本政策并使用本 App。

**九、政策更新与联系我们**

本政策有重要更新时，会在 App 内再次请你阅读并同意。如有任何疑问、意见或投诉，可以通过"我的 → 意见反馈"联系我们，我们会在 15 个工作日内回复。
"""

    static let termsZH = """
**小满记 用户协议**

更新日期：\(updated)

欢迎使用小满记（以下简称"本 App"）。本 App 由个人开发者 superQL 开发和运营。使用本 App 前请仔细阅读本协议，点"同意并继续"或继续使用即表示你同意本协议。

**一、服务内容**

本 App 提供习惯打卡、打卡日志、笔记、心情、统计、提醒、桌面小组件等功能，数据保存在你的手机上。

**二、你的数据**

你在本 App 中创建的内容归你所有。因为数据只保存在本机，请定期在"我的 → 备份"中导出备份。因手机丢失、损坏、删除 App 等原因造成的数据丢失，我们无法帮你找回。

**三、会员服务**

1. 会员分为年度卡（按年自动续期订阅）、月度卡（按月自动续期订阅）和永久会员（一次性购买）。
2. 首次开通年度卡可免费试用 3 天。试用期结束前 24 小时内没有取消的，Apple 会按年度卡价格扣费并开始计算会员期。
3. 年度卡、月度卡到期前 24 小时内，Apple 会自动从你的 Apple ID 账户扣费续期。如需取消，请在到期前至少 24 小时，在 iPhone"设置 → Apple ID → 订阅"中关闭自动续期。
4. 已购买的会员可以在使用同一 Apple ID 的设备上通过"恢复购买"找回。
5. 价格以 App Store 显示的为准，退款按 Apple 的规定处理。

**四、使用规范**

请遵守法律法规，不要利用本 App 从事违法活动，也不要通过意见反馈发布违法、侵权、骚扰内容。

**五、免责说明**

本 App 中的统计和总结只是对你自己记录的数据进行整理，仅供参考，不构成任何医疗、心理或其他专业建议。

**六、协议变更**

协议有重要更新时会在 App 内再次请你阅读并同意。如有疑问，可以通过"我的 → 意见反馈"联系我们。
"""

    static let creditsZH = """
**致谢**

本 App 的部分习惯图标来自 **OpenMoji**（openmoji.org），由 HfG Schwäbisch Gmünd 的设计师和开发者共同创作，按照 **CC BY-SA 4.0** 协议授权使用。我们对部分图标做了尺寸和格式上的调整。

协议全文：creativecommons.org/licenses/by-sa/4.0

系统图标来自 Apple SF Symbols。

App 内置的字体均按 **SIL Open Font License 1.1** 授权使用（已按协议改名、裁剪）：霞鹜文楷、悠哉字体、小赖字体（LXGW）、站酷快乐体、站酷庆科黄油体（站酷）、精品点阵体 9×9、Chiron GoRound。


谢谢每一位愿意坚持、愿意记录的你。
"""

    static let guide = """
**快速上手**

**1. 新建习惯**
在"打卡"页点"日常打卡"旁边的 **+**，填名字、选图标和颜色，设置哪几天要做、要不要提醒。

**2. 打卡**
点一下习惯图标就完成了。再点一下已完成的图标，可以写一句打卡日志、取消打卡、暂停或编辑。

**3. 看别的日子**
点顶部的日期可以展开一周日期栏，左右滑动切换周，点某一天可以补打卡。

**4. 分组**
点 **⇄** 可以在"分组显示"和"不分组"之间切换。按住图标拖动可以调整顺序或换到另一个分组。

**5. 暂停**
出差、生病时可以暂停习惯，暂停期间不显示、不计入完成率。可以选结束日期自动恢复，也可以手动恢复。

**6. 笔记、回忆、心情**
打卡页顶部的快捷栏可以写笔记、翻看过去的记录、记心情。在"我的 → 个性化"里可以选择显示哪些。

**7. 统计**
"统计"页按周、月、年查看打卡次数、完成率和每个习惯的完成情况。每周第一天可以生成上周的总结。

**8. 备份**
数据只保存在这台手机上。换手机或删除 App 前，请到"我的 → 备份恢复"导出备份。
"""
}
