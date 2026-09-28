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

迁移中。保留旧 Flutter 代码作功能和协议对照，新的 App target 不引用其运行时。
