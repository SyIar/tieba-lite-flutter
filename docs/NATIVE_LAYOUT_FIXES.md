# Native forum layout and reply colors

## Screenshot findings (2026-09-29)

- `ForumView` inserted a zero-height `Color.clear` scroll anchor as a `List` row. The list still supplied its row background/minimum height and grouped section spacing, producing the empty pill above the forum information.
- Forum introduction, statistics, and actions were separate automatic list rows. The feed also inherited list navigation chevrons and system group gaps instead of a deliberate forum layout.
- Forum/thread destinations kept the root tab bar while declaring their own bottom pagination toolbar. The screenshot shows page controls behind the tab bar.
- Nested-reply previews were automatic button labels with hierarchical `.secondary` styling on the whole combined text. In the screenshot, both author and body were rendered in the button tint.

## Changes

- The forum uses a lazy scrolling feed with explicit 12-point gaps. A single header card contains the forum avatar/name, wrapping statistics, introduction, follow and check-in actions. No transparent list row is created.
- Pinned threads remain a compact single-line list in one card. Filtered pinned rows do not leave an empty card.
- Normal thread cards have their own neutral background. Up to three thumbnails share the available width, use a consistent 88-point height and crop only their feed previews. The detailed image viewer retains the full image.
- Forum and thread destinations hide the root tab bar. Returning to a root tab lets the system restore it. Native pagination groups Previous / Page / Next on the left and Refresh on the right, with a real toolbar spacer between the glass surfaces.
- Nested-reply buttons use plain styling. Author names are semibold in the configured accent color; reply text uses the dynamic system label color. The View replies entry keeps the accent. Neutral action labels use the system secondary label color; a selected Like retains its accent.
- Account storage, API requests, thread filters, read history, follow/check-in state and media playback behavior are preserved. Manual image-loading preferences still apply; noninteractive feed thumbnails open their thread instead of nesting a retry button inside its navigation link.

## Validation boundary

No simulator runs or screenshot tests are used. Source/localization checks, existing core regression tests and an iPhone Release build validate policy, protocol/storage compatibility and compilation. They do not prove the reported layout/color defects are resolved on the user's device.

Physical-device acceptance:

1. Open a forum from Home: no empty top pill, one compact information card, single-line pinned threads, evenly spaced feed cards.
2. Check both one-image and three-image previews; tapping anywhere on a thread card opens that thread.
3. Check that the bottom tab bar is absent inside the forum/thread and page controls can be tapped; return to Home and verify tabs reappear.
4. Open a nested-reply preview in light and dark appearances: author accent and body black/white remain distinct. Tapping it still opens Floor replies.
5. Verify follow/check-in completion, first/last page disabled states, pull-to-refresh, filter changes and Back to top with the existing account.
