# 验证记录

日期：2026-09-24。上游基线见 `FEATURE_MATRIX.md`，工具链固定为 Flutter 3.47.5 / Dart 3.13.4。

## 已完成

- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub`：最新 CI 的 58 tests 全部通过，包含 protocol fixtures、账号存储与 WebView session 隔离、iOS 插件初始化回归、启动恢复、登录异常后的导航清理、分页和楼层定位、历史迁移、缓存与草稿隔离、图标 channel、avatar crop、emoticons 和 deep link。
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
- build `2` 本机归档：`D:\workspace\tieba-lite-flutter\artifacts\run-35995600459\TiebaLite-unsigned.ipa`，大小 `24,652,611` bytes。下载后重新检查 ZIP 完整性、device 平台、Runner / App.framework / Flutter.framework 的 arm64、source commit，以及复制前后 SHA-256，全部通过。
- IPA SHA-256：`52dbf0fce2e8ff84a12a3d5b221a949d944eac77ac6572aa1e82fdcd8885c5f3`。
- bundle identifier：`org.tblite.flutter.tiebaLite`。云端制品保持未签名，安装时由 Sideloadly 在本机重新签名；上述构建成功不代表真机业务验收完成。

### 当前修复版：0.1.0 (4)

- [运行 35998406483](https://github.com/SyIar/tieba-lite-flutter/actions/runs/35998406483) 成功，source `4c92398a9963306c9e00f76145c5cd375d09a70b`，包含 iOS 登录初始化修复与新的默认蓝底白色圆润“贴”字图标。
- 58 tests、Dart analyze、Web release、Xcode 26.3 编译、IPA 打包及云端结构校验全部通过。
- 当前安装文件：`D:\workspace\sideloadly-setup\TiebaLite-unsigned.ipa`，`25,712,323` bytes；归档保存在 `artifacts/run-35998406483/`。
- IPA SHA-256：`a1af01aad4f12ee267f62cb8d405cc69f2df8047c55b89f09f532ae4ec1920a5`；本机重复校验 ZIP、device arm64、source commit、build number 和文件复制校验值均通过。
- 从 IPA 提取主图标并对 Xcode 的 CgBI PNG 做无损解码，120 × 120 RGB 像素与新源图对应尺寸完全一致。图标源图与提示词见 `APP_ICON.md`。

## Wi-Fi 安装记录

- 2026-09-24，Sideloadly 0.60 已通过 `@Wi-Fi` 识别 iOS 27.2 设备，使用现有本地账户签名并安装 `0.1.0 (2)`，最终显示 `Done. / 100%`。
- 本地安装记录确认 `Tieba Lite` 已登记自动刷新，`one_off=0`、`known_ttl=7`、`refresh_at_hours=96`、`failures_count=0`；daemon 后续检查已识别该 App。
- 用户随后确认可以正常进入首页，首次真机安装、启动与首页显示通过；真实百度登录及其他业务功能仍须分别确认。账号、设备标识、证书和原始日志未提交到仓库。
- 20:29:15，`0.1.0 (4)` 在同一 `@Wi-Fi` 连接下覆盖安装完成，Sideloadly 显示 `Done. / 100%`。本地仅有一条有效的 Tieba Lite 自动刷新记录，`one_off=0`、`failures_count=0`，缓存文件标识与新的 IPA 内容匹配。用户在登录页和桌面图标复验请求后回复“ok了”，确认本次问题解决；未将此反馈扩大为所有已登录业务的逐项验收。

## iOS 登录初始化修复

- build `2` 的真机登录页显示“请求失败”与“重试”，发生在百度 WebView 创建前。
- 根因：`BaiduWebSessionCoordinator` 无条件调用 `WebStorageManager.deleteAllData()`，但锁定的 iOS 插件没有实现该 Android-only 接口。使用真实 `IOSInAppWebViewPlatform` Dart adapter 的新回归测试复现 `UnimplementedError: deleteAllData is not implemented on the current platform`。
- 修复：iOS / macOS 使用 `removeDataModifiedSince`、全部 `WebsiteDataType` 与 Unix epoch；Android 保留原接口。清理仍在加载或注入账号 Cookie 前完成，失败时仍阻止会话打开。
- 测试直接使用已锁定的 iOS Dart adapter，只 mock 原生 method channels；为此将同版本 `flutter_inappwebview_ios 1.1.2` 声明为 dev dependency，没有升级运行时依赖。修复后 2 项新回归与原 5 项 WebView session 测试通过，Dart analyze 无问题。
- 参考：[插件官方平台用法](https://inappwebview.dev/docs/web-storage-manager/)。修复版云构建、制品校验与 Wi-Fi 覆盖安装已通过，用户已反馈本次登录页问题解决。
- [运行 35997532834](https://github.com/SyIar/tieba-lite-flutter/actions/runs/35997532834) 已通过 verify job。用户在构建中追加蓝底白色圆润“贴”字图标，故主动取消该次 iOS 构建，并将图标与登录修复合并重建；该取消不作为代码编译失败记录。

## 待完成的真机验收

- 登录后的会话持久化、Keychain、WebView cookies 与账号切换隔离；相册、媒体、分享、alternate icons、incoming links。
- 登录后的服务端接口与用户主动选择的写操作。

本地 Flutter 测试和 Web 编译不等同于 iOS 编译成功或全部业务验收通过。未执行 Gradle，未新增 Java tests。
