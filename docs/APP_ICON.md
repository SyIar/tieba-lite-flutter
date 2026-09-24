# App icon

用户于 2026-09-24 要求默认图标改为蓝底、白色、较圆润的“贴”字。

- 使用内置 `image_gen` 生成新的文字图标，没有复制原版 TiebaLite / 百度贴吧图标。
- 项目源图：`assets/branding/app-icon.png`。源图保持生成结果，Pillow 仅负责 RGB 格式和各平台尺寸适配。
- `python scripts/generate_icons.py` 更新默认 iPhone / iPad / App Store 图标及 Web 图标。源图保持方形、不透明，由 iOS 应用圆角遮罩。
- 既有可选 `AppIconBlue` / `AppIconDark` 保留，默认 `AppIcon` 使用本次新图。

## Final generation prompt

Create one final iOS app icon artwork, a square 1024x1024 raster PNG. This is a flat typographic logo asset, not a mockup. Entire canvas must be filled edge-to-edge with one rich clean blue color, approximately #2878EB, fully opaque, square outer corners (iOS applies its own corner mask). Center exactly one simplified Chinese character: “贴”. The character must be correct and immediately legible: 贝 on the left and 占 on the right. Pure white, very bold, friendly and rounded strokes, smoothly rounded ends and corners, balanced stroke spacing and generous counters, custom rounded Chinese sans-serif lettering. Glyph occupies approximately 70% of canvas width and height, visually centered with even comfortable margins. Minimal polished iOS icon, strong contrast and crisp anti-aliased edges for small sizes. No extra characters, no Latin text, no border, no speech bubble, no ornament, no logo copied from an existing app, no bevel, no embossing, no shadows, no texture, no gradients, no device frame, no background outside the icon, no transparency. Output only the finished blue square icon with the white rounded character.
