# Forum navigation and continuous pages

## Report and cause

Returning from a thread ran `ForumView`'s `.task` again. That task always fetched
the current page and called `scrollTo("top")`. Reapplying the saved sort on each
appearance could also schedule a page-one load. Next/Previous replaced the sole
page instead of maintaining a continuous feed.

## Behavior

- Initialize the saved sort once per navigation destination. A completed request
  does not run again when the destination reappears, including after an error.
- Retain the same scroll view, loaded page models and stable thread IDs while a
  thread covers the forum. Return does not request data or command a scroll.
- Load the next page within 240 points of the bottom during user scrolling.
  Append it without moving the viewport. Each drag requests at most one page;
  layout changes or navigation alone cannot start pagination.
- Keep already loaded pages reachable in both directions. Previous/Next moves
  within the loaded feed without a request, or loads the adjacent page. The
  displayed page follows the first visible thread.
- A previous page outside the loaded range can be prepended by pulling 56 points
  past the top. Apply that insertion after scrolling settles and retain the old
  visible row. Pulling at page one does not refresh.
- Refresh explicitly reloads the current page and retains neighboring pages.
  Sort/digest changes deliberately start a fresh feed at page one.
- Deduplicate overlapping live-sort rows and pins. Keep existing rows on their
  original loaded page so a reply that moves a server boundary does not duplicate
  or move them during prefetch. Page-one refresh is authoritative for old pins.
- Feed state belongs to the navigation destination and is released when that
  destination is removed. It holds display models, not full protocol responses
  or decoded images; the existing bounded image cache remains in use.

## Validation

`ForumFeedTests` covers return/load gating, append/prepend, moving duplicates,
pins, current-page refresh, query reset, empty/final pages and gesture gating.
Local repository language checks passed. Tree-sitter accepts the three changed
Swift files; it is syntax-only and has pre-existing parser limitations elsewhere.
CI results are recorded below. No simulator validation is used.

Physical-device checks: read through pages 1–3, open a thread halfway down page 3,
then use both the back button and interactive swipe to return. The same row and
offset should remain, without loading or jumping. Repeat offline, switch between
loaded pages, test refresh and sort/digest changes, and check the final page.

## Verified package

- Version: `0.2.0 (1012)`; source `85cdb862d18ad90ca9ca81ae4e96865ec399dbb3`.
- [GitHub Actions run 36667233756](https://github.com/SyIar/tieba-lite-flutter/actions/runs/36667233756)
  passed all 20 Swift core tests (11 new feed cases), Swift compiler parsing,
  repository checks and the iPhone arm64 Release build.
- Download: `D:\workspace\sideloadly-setup\TiebaLite-0.2.0-1012-unsigned.ipa`.
- Size: `4,443,711` bytes.
- SHA-256: `db80d7df2453112019af657c327b4e3d042cec492c410c128922becbaaadf8e4`.
- Local verification confirmed CI/source metadata, SHA-256, ZIP integrity,
  iPhoneOS/arm64 executable, original bundle identifier, build number, icon,
  localization and emoticon resources, and absence of the Flutter runtime.
- The package is unsigned for Sideloadly. Installation and physical-device
  verification of the exact return offset remain pending.
