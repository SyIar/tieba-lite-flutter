# Tieba Lite

TiebaLite 的 iOS 客户端，当前发布 target 已迁移到 Swift / SwiftUI / UIKit，默认中文。原生 target 不包含 Flutter / Dart runtime；旧 Flutter 源码保留作为协议、存储格式和功能对照。项目仍需真实账户和 iPhone 升级验收，不能将源码或编译通过等同于全部功能验收。

## 基线

- 上游：[HuanCheng65/TiebaLite](https://github.com/HuanCheng65/TiebaLite)
- 分支：`4.0-dev`
- Commit：`2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15`
- 上游版本：`4.0.0-beta.1`
- 原项目 Kotlin/Android → Flutter/Dart → 原生 Swift；本工程不是上游官方 iOS 发行版。
- 保留上游 GPLv3 许可和作者归属。上游 README 另有仅学习交流、禁止商业用途的声明，见 `THIRD_PARTY_NOTICES.md`。

## 构建与安装

Windows 用于源码检查和旧协议 fixture 导出。原生编译和 Swift core 测试在 macOS/Xcode 完成。按用户要求不再执行模拟器校验，由用户真机测试。手动工作流 `ios-native.yml` 产出供 Sideloadly 重新签名的 unsigned IPA，不要求将 Apple ID 或签名证书上传到 GitHub。当前原生 target 最低支持 iOS 26。

公开仓库为 [SyIar/tieba-lite-flutter](https://github.com/SyIar/tieba-lite-flutter)。工作流使用标准 GitHub-hosted runner，手动触发，未配置自动发布、推送触发或 Apple 账号凭据。实际构建与制品状态见 [VALIDATION.md](docs/VALIDATION.md)。

原生实现和验证状态见 [SWIFT_MIGRATION.md](docs/SWIFT_MIGRATION.md)，操作说明见 [BUILD_IOS.md](docs/BUILD_IOS.md)。[FEATURE_MATRIX.md](docs/FEATURE_MATRIX.md) 保留旧 Flutter 基线，不能作为原生版本的验收证明。

字体采用混排：英文、数字和 emoji 使用苹果系统字体，汉字、日文假名和韩文使用内置的思源宋体 Regular/Bold。保留系统动态字号及 App 字号设置。构建复用已上传的固定版本字体文件，不需要重复上传，手机运行时也不下载字体。来源和校验流程见 [原生字体资源](native/Resources/Fonts/README.md)。

## 本地约束

- 不运行 Gradle，不依赖公司 Maven，不新增 Java 单测。
- 允许独立 Swift 测试及旧 Flutter 的 Dart / widget tests；这不改变 Java 单测禁令。
- 非 Markdown/SQL 文件使用英文；用户批准的中文本地化资源为例外。中文文案集中在 `lib/l10n/app_zh.arb`，生成的本地化代码不提交。
- Baidu 凭据仅保存在平台安全存储中；不写进仓库、日志、GitHub Secrets 或普通偏好存储。
- 未经操作人主动点击，不发送回复、签到、关注、删除或资料修改请求。
- Android 定时后台任务不能直接等价为 iOS 的定时保证，见 iOS 平台说明。
