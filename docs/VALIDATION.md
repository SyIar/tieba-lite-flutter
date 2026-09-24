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

## 待验证

- GitHub Actions 的 macOS / Xcode 实际编译及 unsigned IPA 结构校验。
- Sideloadly 重新签名和 iPhone 安装、启动。
- iPhone 上的真实百度登录、Keychain、WebView cookies、相册、媒体、分享、alternate icons、incoming links。
- 登录后的服务端接口与用户主动选择的写操作。

本地 Flutter 测试和 Web 编译不等同于 iOS 编译成功或全部业务验收通过。未执行 Gradle，未新增 Java tests。
