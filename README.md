# Tieba Lite for Flutter

TiebaLite 的 Flutter / iOS 迁移工程，默认中文，保留原项目已经实现的功能范围。项目仍处于迁移和验证阶段，不能将源码完成度等同于服务端兼容性或 iPhone 验收通过。

## 基线

- 上游：[HuanCheng65/TiebaLite](https://github.com/HuanCheng65/TiebaLite)
- 分支：`4.0-dev`
- Commit：`2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15`
- 上游版本：`4.0.0-beta.1`
- 原项目 Kotlin/Android → Flutter/Dart；本工程不是上游官方 iOS 发行版。
- 保留上游 GPLv3 许可和作者归属。上游 README 另有仅学习交流、禁止商业用途的声明，见 `THIRD_PARTY_NOTICES.md`。

## 构建与安装

Windows 用于 Dart 分析、协议验证和共享 UI 预览。iOS device 构建必须在 macOS/Xcode 完成。GitHub Actions 产出供 Sideloadly 重新签名的 unsigned IPA，不要求将 Apple ID 或签名证书上传到 GitHub。

GitHub 仓库创建、可见性以及云构建费用须经用户确认后才执行。工作流为手动触发，未配置自动发布、推送触发或账号凭据。

操作说明见 [BUILD_IOS.md](docs/BUILD_IOS.md)，迁移状态见 [FEATURE_MATRIX.md](docs/FEATURE_MATRIX.md)，验收边界见 [MIGRATION_PLAN.md](docs/MIGRATION_PLAN.md)。

## 本地约束

- 不运行 Gradle，不依赖公司 Maven，不新增 Java 单测。
- 用户已明确允许本 Flutter 项目的 Dart / widget tests；这不改变 Java 单测禁令。
- 非 Markdown/SQL 文件使用英文；用户批准的中文本地化资源为例外。中文文案集中在 `lib/l10n/app_zh.arb`，生成的本地化代码不提交。
- Baidu 凭据仅保存在平台安全存储中；不写进仓库、日志、GitHub Secrets 或普通偏好存储。
- 未经操作人主动点击，不发送回复、签到、关注、删除或资料修改请求。
- Android 定时后台任务不能直接等价为 iOS 的定时保证，见 iOS 平台说明。
