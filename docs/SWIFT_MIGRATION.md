# Native Swift migration

## Protocol compatibility

The Swift generator uses the existing `.proto` field numbers and types. A temporary build-only schema adds explicit scalar presence to request messages, including `CommonRequest`: the legacy Dart implementation serializes assigned zero values, while SwiftProtobuf otherwise omits implicit proto3 defaults. The `pn=0` anchor request fixture detects this distinction. Generated schema copies stay under `native/.build`; original shared schemas are unchanged.

Reference: [Protocol Buffers field presence](https://protobuf.dev/programming-guides/field_presence/). Explicit presence preserves assigned defaults; Dart is a documented exception among proto3 APIs. Legacy binary fixtures verify the actual request encoding and response mapping.

用户确认仅使用 iOS，授权迁移到 Swift + SwiftUI / UIKit。

## Acceptance contract

- 发布 target 不包含 Flutter / Dart runtime。
- 按 FEATURE_MATRIX.md 对照功能，保留协议、账户隔离、草稿、收藏、历史、最近五个吧 FIFO、签到完成态及紧凑置顶。
- 保留 bundle identifier、Keychain service/account、UserDefaults key 和存储格式；升级不能清空原有数据。
- 中文只放本地化资源，其余代码、配置、测试内容使用英文。
- 使用原生系统导航和 Liquid Glass 控件，正文保持紧凑且可读，跟随系统外观。
- Swift 测试和 macOS/Xcode CI 验证；不运行 Gradle，不编写 Java 单测。
- 对无法在 CI 使用真实账户验收的功能，明确标注真机验证状态，不以编译通过代替验收。

## Execution

原生源码已覆盖主要功能，保留旧 Flutter 代码作功能和协议对照；新的 App target 不引用其运行时。

| Scope | Native implementation |
| --- | --- |
| Startup, account storage and settings | `AppState.swift`, same Keychain service/account and legacy UserDefaults prefixes |
| Tabs, navigation and pagination | SwiftUI `TabView`, `NavigationStack`, native toolbars and system Liquid Glass |
| Followed/pinned/recent forums | `HomeForum.swift`, five-entry FIFO, list/grid, nullable member counts and completed sign-in state |
| Forum/thread/floor reading | Compact pinned titles, native floor cards, page/anchor/author/reverse filters and reading position |
| Rich content and media | Native text/emoticons/images, photo picker, zoom gallery, Photos save/share and AVPlayer |
| API compatibility | Original 302 schemas, 13 generated request/response codecs, legacy signatures and device-verification format |
| Discovery and collections | Personalized/concern/hot feeds, search/suggestions, topics, notifications, profiles, favorites and history |
| Account actions | Explicit sign-in, follow, favorite, like, reply, report and own-content removal controls |
| Drafts and replies | Account-scoped legacy drafts, retained image files, upload markup and sent-draft tombstones |
| Profile editing | Native form, square image crop and existing account endpoints |
| Filtering | User/forum/thread/keyword rules, allow overrides, nested reply filtering |
| Official web flows | Isolated WKWebView for Baidu login, report and service center |

## Native adaptations

- System light/dark appearance and system font remain the defaults. Navigation and pagination use native system controls rather than matching every old Flutter visual option.
- Main tabs use the system tab bar; the Flutter swipe-between-tabs gesture is not retained.
- Gallery playback uses AVKit; image zoom uses UIKit. No Android playback or background-service code is included.
- No guaranteed background check-in timer is advertised. A previously enabled auto-check-in preference is evaluated while opening Home.
- New custom backgrounds are stored under `nativeBackground`; an older custom Flutter background selection is not automatically imported. Account data, reading records and draft attachments have separate compatibility paths.
- The old Flutter-only Noto Sans choice, toolbar coloring, alternating-row coloring and scrolling-time image deferral do not have identical native counterparts. No disconnected switches for those behaviors are presented.
- Existing public URLs and `tblite://` links supported by `Route.link` open native destinations. Other URLs use the system browser.

## Verification boundaries

- Local checks: repository language/localization policy, diff whitespace and fixture generation; no local Gradle or company Maven access.
- macOS checks: Swift syntax, core tests, iPhone Release compilation, package integrity and absence of Flutter runtime.
- Simulator checks were stopped at the user's explicit request on 2026-09-28 and removed from the build workflow. Device testing is performed by the user. The previous unsigned simulator run stopped at Keychain initialization; it is not evidence of a successful native launch. Diagnostic code remains available but is not invoked by CI.
- The iPhone IPA stays unsigned for Sideloadly; no Apple account, certificate or provisioning profile is supplied to CI.
- Device acceptance still required: same-account Sideloadly upgrade, Keychain and draft continuity, live login, authenticated operations, media and visual/scrolling quality. No authenticated account writes were performed during this migration.
- Previous Flutter version acceptance cannot be applied to this native version. This is a native migration build for upgrade verification, not a claim that every live endpoint has been re-accepted.

## Verified device package

Latest native style follow-up: [forum layout and reply colors, build 1011](NATIVE_LAYOUT_FIXES.md). It passed the nine core tests and iPhone Release build; visual acceptance remains with the user.

### Media edge return follow-up

ImageGallery and NativePlayer now install a native left-edge pan recognizer on their full-screen presentation container. A completed rightward swipe invokes the existing dismiss action; video is paused before dismissal and released on disappearance. The screen edge takes precedence over descendant pan gestures, while central gallery paging, image pinch/double-tap zoom and video scrubbing retain their original handlers. Short, reversed and cancelled edge gestures do not dismiss. The modal closing animation is unchanged.

Device acceptance is pending for edge return during image zoom, multiple-image paging, video playback/loading, reopening viewers, and retaining the underlying thread scroll position. No simulator checks are used.

- Version: `0.2.0 (1010)`.
- Source: `0cd055212af7ba9fe1df4220566ea9d236f6c84f`.
- [macOS CI run 36434497179](https://github.com/SyIar/tieba-lite-flutter/actions/runs/36434497179): success. Nine Swift core tests, iPhone Release compilation and package checks passed. No simulator checks ran in this workflow.
- Downloaded package: `D:\workspace\sideloadly-setup\TiebaLite-0.2.0-1010-unsigned.ipa`.
- SHA-256: `c62ce5c0179edca8dc5d08842adfe29825fd4b128f22b4c9f7b4cb7f81e7f290`.
- Size: `4,382,386` bytes.
- Local verification: intact ZIP, arm64 executable, original bundle identifier, correct display name/version, AppIcon/localization/emoticon/license resources and `tblite` scheme, no Flutter runtime.
- Not installed by this task. The user will perform iPhone acceptance. An in-place upgrade using the same Sideloadly account allows migration testing without first deleting old data.
