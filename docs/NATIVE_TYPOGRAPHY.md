# Native mixed-script typography

The native app uses Apple's system primary font with Source Han Serif as the
CJK fallback. Han characters, Japanese kana and Korean Hangul use the serif;
Latin text, digits and emoji retain system faces. Regular and Bold are both
bundled. The remaining system cascade handles unsupported characters.

The policy covers native titles, navigation, tab/search labels, body text and
nested replies. SwiftUI styles follow Dynamic Type and the existing in-app
font-size preference. Reply colors remain separate: author/link accents do
not turn reply bodies blue. Original website pages keep their own styling.

## Asset handling

The owner already uploaded both OTFs to Forum Lite. The pinned manifest in
`native/Resources/Fonts/fonts.json` references that exact public commit and
verifies byte counts and SHA-256 digests. CI retrieves them before building;
the phone uses bundled resources without a runtime font download. Large
files are not uploaded a second time from this computer.

## Verification scope

CoreText checks inspect actual shaped runs for Latin, digits, accented Latin,
Greek, emoji, Han, kana, Hangul and mixed paragraphs at both weights. The
workflow also runs Swift compiler parsing, existing Core tests and a generic
iPhoneOS Release build. Packaging checks font registration, binary integrity
and license inclusion.

No simulator is used. Physical-device acceptance remains pending.

## Build 1013

- Version: `0.2.0 (1013)`.
- Source: `991f4da78b28a6722e09b4309bb0bb927cffd4f2` on `main`.
- [Actions run 36680927218](https://github.com/SyIar/tieba-lite-flutter/actions/runs/36680927218)
  succeeded on 2026-09-30 with Xcode 26.3.
- Swift compiler parsing, mixed-script CoreText checks, all 20 existing Core
  tests, iPhoneOS arm64 Release compilation and packaging checks passed.
- Prepared font hashes match the owner-uploaded Regular and Bold resources.
- Local unsigned IPA: `D:/workspace/sideloadly-setup/TiebaLite-0.2.0-1013-unsigned.ipa`.
- Size: `45,627,537` bytes.
- SHA-256: `5e5ce2cef9d5790a1ab07e2b354c5b2be4804319b1963f29d04a5ab28b0f5acb`.
- Local verification passed ZIP CRC, CI/source/run metadata, checksum,
  version/build, unchanged bundle identity, arm64 executable and unsigned
  status. Both bundled fonts match the pinned hashes and local inputs. Icons,
  Chinese localization, emoticons, deep links and font license are present.
- The installation-directory copy is byte-identical to the CI artifact;
  its adjacent `.ipa.sha256` records the checksum. Installation was not run.
