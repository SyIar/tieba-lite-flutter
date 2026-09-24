# Bundled font provenance

The application bundles the unmodified, static **Noto Sans CJK SC Regular 2.004**
OpenType font for offline Chinese rendering. This is the language-specific full
CJK font, not a subset extracted from the current interface strings. Forum and
post content can use the full coverage shipped by upstream.

## Source and license

- Official project: [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk).
- Upstream deployment guidance: [language-specific OTFs](https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/README.md#language-specific-otfs).
- Font file: [NotoSansCJKsc-Regular.otf at the font revision](https://github.com/notofonts/noto-cjk/blob/165c01b46ea533872e002e0785ff17e44f6d97d8/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf).
- Direct immutable download: [official raw OTF](https://raw.githubusercontent.com/notofonts/noto-cjk/165c01b46ea533872e002e0785ff17e44f6d97d8/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf).
- License: [SIL Open Font License 1.1 from upstream](https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/LICENSE).
- Font copyright metadata: **© 2014-2021 Adobe (http://www.adobe.com/).**

`assets/fonts/OFL.txt` contains that copyright attribution followed by the complete
upstream English OFL text. The font itself retains its original copyright and license
metadata. The license permits bundling with software under its stated conditions; the
font is not sold separately and has not been modified or renamed internally.

The font's last-changing revision is `165c01b46ea533872e002e0785ff17e44f6d97d8`.
The license and format guidance are pinned separately to repository revision
`f8d157532fbfaeda587e826d4cd5b21a49186f7c`, because `Sans/LICENSE` did not exist at its
current path in the older font revision.

## Local file and integrity

| Field | Verified value |
| --- | --- |
| Local file | `assets/fonts/NotoSansCJKsc-Regular.otf` |
| Internal family | `Noto Sans CJK SC` |
| Internal style | `Regular` |
| Internal PostScript name | `NotoSansCJKsc-Regular` |
| Internal version | `Version 2.004;hotconv 1.0.118;makeotfexe 2.5.65603` |
| File format | Static OpenType/CFF, `OTTO` header |
| File size | 16,437,364 bytes, about 15.68 MiB |
| SHA-256 | `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b` |
| Git blob SHA-1 | `dc15562470b4f842321894787a0d066879ccff8b` |
| Glyph count | 65,535 |
| Unicode code points in format-12 cmap | 44,810 |

On 2026-09-24 the downloaded file's Git blob digest matched the official GitHub API
metadata. Its OpenType tables and metadata were parsed locally. All 483 distinct Han
code points found in the current localization and emoticon `.arb` files were present
in the font's cmap. This is coverage verification; application screenshots and device
rendering remain separate checks. No font claims to cover every Unicode character,
and platform fallback remains useful for emoji and rare characters outside this font.

## Flutter registration

Use the stable application alias `NotoSansCJKsc`:

```yaml
flutter:
  assets:
    - assets/fonts/OFL.txt
  fonts:
    - family: NotoSansCJKsc
      fonts:
        - asset: assets/fonts/NotoSansCJKsc-Regular.otf
          weight: 400
```

Set the intended theme `fontFamily` or `fontFamilyFallback` to this alias. Register
`assets/fonts/OFL.txt` with Flutter's `LicenseRegistry` so users can view attribution
in the application's licenses page. The font registration bundles the OTF; it does
not require an additional generic asset entry for the same font file.

Only the static regular weight is bundled. Other requested weights may be synthesized
by the renderer. No external font download is required at runtime, and no UI-only
subsetting or third-party font conversion was performed.
