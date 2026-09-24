# Native Tieba emoticons

The catalog follows upstream `EmoticonManager.kt` and `ReplyPage.kt` at commit `2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15`.

- The upstream picker inserts `#(canonicalName)`. It does not insert Unicode emoji or the image ID.
- The initial mapping contains 58 unique names after Kotlin's duplicate-key semantics. The duplicate name for IDs 31 and 61 resolves to ID 61, matching the upstream map.
- The canonical names live in `assets/l10n/emoticons_zh.arb`, within the user's approved Chinese localization-resource exception. These strings also form wire tokens and must remain unchanged when the UI language changes.
- The 51 WebP files under `assets/emoticons/` are copied byte-for-byte from upstream `app/src/main/res/drawable/image_emoticon*.webp`. They total 143,676 bytes. No fonts, launcher artwork, or unrelated assets were copied.
- Nine missing images for the known picker labels were retrieved from Baidu's verified HTTPS endpoint and are bundled as PNG files: IDs 61 and 77 through 84. All 58 initial picker labels therefore have offline image assets.
- The legacy `static.tieba.baidu.com` hostname has a certificate hostname mismatch when accessed over HTTPS. The app uses `https://tieba.baidu.com/tb/editor/images/client/<id>.png`, which was verified with normal TLS validation to return actual PNG data. The alternative host serves the same public Baidu asset path; the app does not disable TLS verification or broaden iOS transport-security settings. Rendering retains caption/token fallbacks if a newly learned image cannot load.
- As in upstream, the catalog can learn a validated `image_emoticon...` ID and canonical caption from a Tieba content response. Learned labels are a non-secret disposable local cache. Invalid IDs or control characters are ignored.

The upstream repository license and attribution apply to the copied source mapping and files as distributed in that repository. This port does not claim independent ownership or a broader standalone license to Baidu's emoticon artwork. Preserve the original notices with any redistributed derivative.

Sources: [upstream EmoticonManager](https://github.com/HuanCheng65/TiebaLite/blob/2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15/app/src/main/java/com/huanchengfly/tieba/post/utils/EmoticonManager.kt), [upstream ReplyPage](https://github.com/HuanCheng65/TiebaLite/blob/2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15/app/src/main/java/com/huanchengfly/tieba/post/ui/page/reply/ReplyPage.kt), [upstream LICENSE](https://github.com/HuanCheng65/TiebaLite/blob/2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15/LICENSE).
