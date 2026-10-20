# 每日复盘 · SwiftUI 原生版

iOS 17 及以上，iPhone 竖屏。数据只存本机（App Group 里的 `state.json`），备份格式和网页原型通用，可以互相导入。

## 目录

| 位置 | 内容 |
| --- | --- |
| `App/` | App 本体：各个页面、数据存取（Store）、通知、密码锁、内购 |
| `Shared/` | App 和小组件共用：数据模型、统计规则、配色、图标、备份、小组件打卡 |
| `Widget/` | 桌面小组件（小号：进度；中号：可直接点图标打卡） |
| `Shared/Assets.xcassets` | 图标、插画、App 图标 |
| `project.yml` | 工程配置（用 XcodeGen 生成 Xcode 工程） |
| `../.github/workflows/ios-build.yml` | 推到 GitHub 后自动在 Mac 上编译检查 |

## 常改的地方

- **颜色**：`Shared/Theme.swift`（页面底色、文字色、卡片配色板、日期颜色）
- **默认头像**：`App/MeView.swift` 里的 `DefaultAvatar`
- **底部导航图标**：`Shared/Assets.xcassets/Art/tab_*`
- **文字**：隐私政策、协议、使用指南在 `App/LegalText.swift`
- **会员权益文案**：`App/MoreViews.swift` 里的 `perks`

## 编译检查（没有 Mac 也可以）

1. 在 GitHub 新建私有仓库 `daily-review-ios`，把 `ios` 文件夹里的内容推上去。
2. 每次推送都会自动编译，在仓库的 **Actions** 页看结果，绿色就是通过。

## 装到自己的 iPhone / 上架（需要 Apple 开发者账号，¥688/年）

1. 在 [developer.apple.com](https://developer.apple.com) 注册开发者账号。
2. 在「Certificates, Identifiers & Profiles」里创建：
   - App ID：`com.dailyreview.app`（勾选 App Groups）
   - App ID：`com.dailyreview.app.widget`（勾选 App Groups）
   - App Group：`group.com.dailyreview.app`
   - 如果这些 ID 已被占用，把 `project.yml` 和 `Shared/Persistence.swift` 里的 `com.dailyreview` 统一换成你自己的前缀。
3. 把 Team ID 填到 `project.yml` 的 `DEVELOPMENT_TEAM`。
4. 在 App Store Connect 新建 App，创建两个内购商品：
   - `com.dailyreview.app.vip.year`（自动续期订阅，一年）
   - `com.dailyreview.app.vip.life`（非消耗型）
5. 签名打包、上传 TestFlight 用 GitHub Actions 完成（需要把证书和 App Store Connect API 密钥放进仓库的 Secrets，到时一步步配置）。
6. TestFlight 装到手机上测试，没问题再提交审核。

## 上线前要确认

- 隐私政策、用户协议里的【开发者名称】
- 会员权益要和实际功能一致（审核会检查）
- 中国大陆上架需要 App 备案
- 隐私政策需要一个能公开访问的网址（App Store Connect 要填）
- 习惯图标来自 OpenMoji（CC BY-SA 4.0），「致谢」页已注明，不要删
