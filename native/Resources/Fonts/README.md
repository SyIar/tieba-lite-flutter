# Source Han Serif CJK fallback

The native app uses Apple's system font for Latin text, numbers and emoji.
Source Han Serif supplies Han characters, Japanese kana and Korean Hangul,
with separate unmodified Regular and Bold faces. The existing system fallback
chain remains available for unsupported characters.

The owner already uploaded these large OTF assets to the public Forum Lite
repository. `fonts.json` pins that upload's complete commit ID, file sizes and
SHA-256 digests. CI runs `python3 scripts/prepare_native_fonts.py` to retrieve
and validate those exact files before compiling; no second owner upload is
needed. Both fonts and their OFL license are embedded in the IPA. The phone
does not download fonts at runtime.

For local integration, reuse existing files without network transfer:

```powershell
python scripts/prepare_native_fonts.py --from-directory D:/workspace/clean-forum-flutter/native/Resources/Fonts
```

The prepared OTFs are ignored by Git. Future large asset uploads remain the
repository owner's responsibility; provide the folder and exact source links,
then validate the uploaded asset rather than repeatedly trying local uploads.

Official upstream: [Adobe Source Han Serif](https://github.com/adobe-fonts/source-han-serif/tree/release/OTF/SimplifiedChinese).
`SourceHanSerif-LICENSE.txt` accompanies the unmodified font files.

`MixedScriptFont` builds a CoreText cascade with the system face first.
`AppTypography` applies it to SwiftUI styles and native navigation/search/tab
labels. `ScaledMetric` retains Dynamic Type, and SwiftUI styles also honor the
app's existing font-size preference. Link colors and reply hierarchy remain
separate from typography. Symbols, monospaced license text and website pages
keep their existing presentation.

CI checks actual shaped font runs for Latin, digits, emoji, Han, kana, Hangul
and mixed paragraphs in both weights. Packaging requires the registered OTFs
to match the pinned checksums and local inputs. No simulator is used.
