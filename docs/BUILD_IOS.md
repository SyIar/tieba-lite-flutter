# iOS 云构建和安装

## 当前边界

`.github/workflows/ios-unsigned.yml` 已在 [run 36005115695](https://github.com/SyIar/tieba-lite-flutter/actions/runs/36005115695) 成功执行。最新安装包 `0.1.0 (8)` 将吧内置顶帖集中为单行标题列表，随页面滚动，减少普通帖子前的空间占用。保留关注列表等级与签到状态、签到按钮完成态、首页 5 个最近访问 FIFO、登录初始化修复与新默认图标。unsigned IPA 已下载并验证到 `D:\workspace\sideloadly-setup\TiebaLite-unsigned.ipa`。沿用用户只打包的要求，未安装到手机；最近一次已确认安装为 `0.1.0 (4)`。版本来源、校验值和 iPhone 验收见 [VALIDATION.md](VALIDATION.md)。

该工作流只通过 Actions 页面手动触发，普通 push 不会触发构建。用户已于 2026-09-24 确认使用公开仓库 [SyIar/tieba-lite-flutter](https://github.com/SyIar/tieba-lite-flutter) 和标准 GitHub-hosted runner；未启用付费 runner 或修改账单设置。

## 工具链

- Flutter `3.47.5`，固定 commit `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`。
- 依赖以 `pubspec.lock` 为准，CI 使用 `--enforce-lockfile`。
- Linux job 验证 Dart 与 Web；macOS job 使用 `macos-15`，通过 `DEVELOPER_DIR` 固定选择 Xcode `26.3`，实际版本写入 `build-info.json`。
- `connectivity_plus 7.3.1` 使用 iOS 26 的 `NWPath.isUltraConstrained`，需要包含该 API 的编译 SDK。runner 默认的 Xcode 16.4 会编译失败；这不改变 App 的 iOS 15 最低运行版本。
- `flutter build ios --release --no-codesign` 构建 device app，随后打包 `Payload/Runner.app`，保留 framework 和 symlink。
- IPA 验证包括必需文件、arm64、`iphoneos` 平台、ZIP 完整性、SHA-256，不等同于签名有效或全部业务功能通过。

## GitHub 执行

1. 创建或选择用户拥有的仓库，并确定 private/public。
2. 上传本工程和许可说明，不上传 IPA、登录 Cookie、Apple ID、证书或个人配置。
3. 核对 Actions 可用额度和预算。公开仓库的标准 runner 与私有仓库的额度/费用不同，以 GitHub 当前账单页面为准。
4. 进入 Actions → Build unsigned iOS app → Run workflow。
5. 成功后下载 `TiebaLite-iOS-unsigned-<run_number>` artifact。解压获得 `TiebaLite-unsigned.ipa`、`SHA256SUMS`、`build-info.json`。
6. 将 IPA 保存到 `D:\workspace\sideloadly-setup\` 的固定文件名；在 Sideloadly 中选择它并用用户本人账号重新签名安装。保持自动刷新开启。

无需把 Apple ID 放到 GitHub。本流程不是 App Store / TestFlight 发布，也不替代 Sideloadly 的个人签名续期。

## 本地共享 UI 验证

```powershell
$env:PUB_CACHE = 'D:\workspace\tools\pub-cache'
& D:\workspace\tools\flutter\bin\flutter.bat pub get
& D:\workspace\tools\flutter\bin\flutter.bat gen-l10n
& D:\workspace\tools\flutter\bin\flutter.bat analyze --no-pub
& D:\workspace\tools\flutter\bin\flutter.bat build web --release --no-pub
```

Web 仅用于共享 UI 验证。百度登录、Keychain、iOS 相册、原生媒体和网络策略需在 iPhone 验收，浏览器 CORS 不能当作 iOS API 测试。

## 官方参考

- [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios)
- [本次 macOS runner 的 Xcode 与 SDK 清单](https://github.com/actions/runner-images/blob/macos-15-arm64/20260907.0337/images/macos/macos-15-arm64-Readme.md)
- [GitHub runner selection and billing distinction](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job)
