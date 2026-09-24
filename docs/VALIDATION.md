# 验证记录

日期：2026-09-24。上游基线见 `FEATURE_MATRIX.md`，工具链固定为 Flutter 3.47.5 / Dart 3.13.4。

## 已完成

- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub`：56 tests 全部通过，包含 protocol fixtures、账号存储与 WebView session 隔离、启动恢复、登录异常后的导航清理、分页和楼层定位、历史迁移、缓存与草稿隔离、图标 channel、avatar crop、emoticons 和 deep link。
- `flutter build web --release --no-pub`：成功；在 402 × 874 预览中确认中文字体、首页、个人页、设置和浅色 / 深色切换，检查时没有前端 error log。
- `scripts/check_repository.py`：源码语言与本地化 key 检查通过；306 对 EN/ZH ARB keys 对齐。
- 原生配置静态验证：5 个 plist / entitlements 可解析；57 个 icon catalog 引用尺寸正确且不透明。
- Python 打包校验脚本语法与 Mach-O 架构识别检查通过；两个 CI shell scripts 的 Bash 语法检查通过。
- Guest 只读接口探测记录在 `API_MIGRATION.md`。定位楼层的真实请求已确认应使用 `pn=0` / `pid`，并读取服务端实际页码。

所有 protocol 写操作测试均为本地合成 fixture。没有使用真实账号执行回复、签到、关注、删帖、举报或资料修改。

## 云构建记录

- 公开仓库：[SyIar/tieba-lite-flutter](https://github.com/SyIar/tieba-lite-flutter)。用户授权后创建并上传；工作流仅使用标准 runner。
- [首次运行 35994661467](https://github.com/SyIar/tieba-lite-flutter/actions/runs/35994661467)，source `77213f39a4984bf22c5c93916bf012b077ee0948`：Linux job 的分析、56 tests、仓库检查、Web release 全部通过；iOS 编译失败。runner 默认 Xcode 16.4 不包含 `connectivity_plus 7.3.1` 使用的 `NWPath.isUltraConstrained` API。
- 修复：在 iOS job 使用 `DEVELOPER_DIR` 选择 runner 已安装的 Xcode 26.3，保持依赖锁与 iOS 15 最低运行版本。
- [第二次运行 35995600459](https://github.com/SyIar/tieba-lite-flutter/actions/runs/35995600459)，source `3c0ba34e243f33269134869be383c6a5aa7a436e`，build `2`：两个 job 全部成功。Linux 再次通过全部 56 tests、Dart analyze 和 Web release；macOS 使用 Xcode `26.3 / 17C529`，成功编译 `Runner.app`、校验并上传 IPA。
- artifact：`TiebaLite-iOS-unsigned-2`，包含 IPA、`SHA256SUMS`、`build-info.json`；GitHub 保存 7 天，本机另留固定副本。
- 本机文件：`D:\workspace\sideloadly-setup\TiebaLite-unsigned.ipa`，大小 `24,652,611` bytes。下载后重新检查 ZIP 完整性、device 平台、Runner / App.framework / Flutter.framework 的 arm64、source commit，以及复制前后 SHA-256，全部通过。
- IPA SHA-256：`52dbf0fce2e8ff84a12a3d5b221a949d944eac77ac6572aa1e82fdcd8885c5f3`。
- bundle identifier：`org.tblite.flutter.tiebaLite`。云端制品保持未签名，安装时由 Sideloadly 在本机重新签名；上述构建成功不代表真机业务验收完成。

## Wi-Fi 安装记录

- 2026-09-24，Sideloadly 0.60 已通过 `@Wi-Fi` 识别 iOS 27.2 设备，使用现有本地账户签名并安装 `0.1.0 (2)`，最终显示 `Done. / 100%`。
- 本地安装记录确认 `Tieba Lite` 已登记自动刷新，`one_off=0`、`known_ttl=7`、`refresh_at_hours=96`、`failures_count=0`；daemon 后续检查已识别该 App。
- 用户随后确认可以正常进入首页，首次真机安装、启动与首页显示通过；真实百度登录及其他业务功能仍须分别确认。账号、设备标识、证书和原始日志未提交到仓库。

## 待验证

### iOS 登录初始化修复

- build `2` 的真机登录页显示“请求失败”与“重试”，发生在百度 WebView 创建前。
- 根因：`BaiduWebSessionCoordinator` 无条件调用 `WebStorageManager.deleteAllData()`，但锁定的 iOS 插件没有实现该 Android-only 接口。使用真实 `IOSInAppWebViewPlatform` Dart adapter 的新回归测试复现 `UnimplementedError: deleteAllData is not implemented on the current platform`。
- 修复：iOS / macOS 使用 `removeDataModifiedSince`、全部 `WebsiteDataType` 与 Unix epoch；Android 保留原接口。清理仍在加载或注入账号 Cookie 前完成，失败时仍阻止会话打开。
- 测试直接使用已锁定的 iOS Dart adapter，只 mock 原生 method channels；为此将同版本 `flutter_inappwebview_ios 1.1.2` 声明为 dev dependency，没有升级运行时依赖。修复后 2 项新回归与原 5 项 WebView session 测试通过，Dart analyze 无问题。
- 参考：[插件官方平台用法](https://inappwebview.dev/docs/web-storage-manager/)。云构建、修复版覆盖安装与登录页真机复验待完成。

### 其余真机验收

- iPhone 上的真实百度登录、Keychain、WebView cookies、相册、媒体、分享、alternate icons、incoming links。
- 登录后的服务端接口与用户主动选择的写操作。

本地 Flutter 测试和 Web 编译不等同于 iOS 编译成功或全部业务验收通过。未执行 Gradle，未新增 Java tests。
