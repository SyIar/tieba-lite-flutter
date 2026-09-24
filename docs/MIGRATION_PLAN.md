# 全功能迁移与验收计划

## 用户已确认

1. 按 TiebaLite 已实现的全部功能迁移，接受较长开发周期，不以网页套壳替代原生页面。
2. 使用 GitHub Actions 的 macOS 云构建；涉及账号、仓库公开或费用时再确认。
3. App 默认中文；仅中文本地化资源允许中文，代码、注释、日志和配置继续英文。
4. IPA 沿用现有 Sideloadly 本地签名、安装及续签链路。
5. 用户于 2026-09-24 澄清：仅禁止 Java 单测，允许本项目 Dart / Flutter widget tests。

## 基线和范围

以 `4.0-dev` 的 `2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15` 为逐项对照基线。

核心模块包括登录及多账号、关注/置顶/最近访问贴吧、三类发现 Feed、吧内浏览和搜索、帖子和楼中楼、文字/表情/图片回复、图片/GIF/视频/音频、收藏/历史/草稿、签到、关注用户、消息、资料、屏蔽和阅读设置。以功能矩阵记录实现和验收状态，不用文件数量作为完成标准。

上游 `ForumPage.kt` 的发布新帖选项仅显示 unavailable；这不是已经存在的发布能力。该能力不被虚构为已经完成的迁移项。

## 实现

- API：依据上游签名规则、真实 JSON 端点和 protobuf schema；服务端字段转为共享 domain models。
- UI：Flutter 原生页面；WebView 仅用于百度真实登录或上游确实依赖网页的操作。
- 存储：凭据与普通数据分离，Keychain 保存账号，普通偏好保存设置，本地记录按账号隔离。
- iOS：相册、分享、媒体播放、URL scheme 和隐私声明明确配置；不默认打开任意 HTTP 访问。
- 构建：固定 Flutter revision 和依赖锁；手动 GitHub Actions，未签名 IPA 内包含 device Runner.app 和完整依赖 framework。

## 验收顺序

1. 协议和存储静态检查，Flutter analyze，本地 Web 编译与可运行 UI 预览。
2. 未登录只读 API 探测。网络或服务端拒绝需保留证据，不把空列表当作成功。
3. 用户授权 GitHub 仓库和 Actions 后，macOS 编译、验证 IPA 结构和校验值，下载到本机。
4. 通过 Sideloadly 安装到 iPhone。由用户在百度页面完成登录，检查凭据隔离和退出。
5. 登录后浏览/消息/收藏等验证。发送内容、修改资料、关注、签到等写操作由用户主动选择测试；不自动发布测试内容。
6. 对照功能矩阵逐项关闭缺口，保留服务端接口变化和 iOS 平台差异，不把未验证项标成通过。

## 来源

- [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios)：macOS/Xcode 是 iOS 构建前提。
- [GitHub runner selection](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job)：macOS runner 和公开/私有仓库额度差异。
- [TiebaLite source](https://github.com/HuanCheng65/TiebaLite)：行为和协议基线。
