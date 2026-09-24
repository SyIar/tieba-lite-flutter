# Tieba Lite Flutter feature matrix

Reference: [HuanCheng65/TiebaLite, 4.0-dev](https://github.com/HuanCheng65/TiebaLite/tree/4.0-dev), commit `2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15`.

This document distinguishes implemented Flutter code from verified behavior. A screen, a successful guest API request, a signed IPA build, and an authenticated iPhone acceptance test are separate milestones. No production account writes were executed during development.

## Native routes

| Upstream behavior | Flutter implementation | Verification / remaining difference |
| --- | --- | --- |
| Four main destinations; optional hidden Explore | `MainShell`, Home, Discover, Inbox, Me; optional swipe navigation | Dart analysis; phone layout still requires device acceptance |
| Followed, pinned, recent forums; list/grid | `HomePage`, account-scoped pins and recents; recent forums appear before followed forums | Recents retain five distinct forums in FIFO order, newest arrivals displayed first; revisits update metadata without changing queue position. Full forum history remains separate. Followed forums need an authenticated account |
| One-key sign-in for followed forums | Explicit confirmation; optional official batch request counts confirmed forum IDs only, sequential fallback for remaining forums, configurable one-second pause | No authenticated sign-in requests executed |
| Concern, personalized, hot feed | Three native tabs; real API loaders, hot categories and topic ranking | Guest personalized/hot endpoints probed; concern needs account |
| Hot topic list | Native ranking list and topic metadata screen | Guest ranking/overview endpoints probed; current topic detail endpoint returns metadata but no thread list, so an honest empty state is shown rather than synthesized discussions |
| Reply/mention notifications | Native two-tab inbox; opens thread anchored to reply | Authenticated acceptance pending; background push is not implemented |
| Forum information, following, sign-in, ordinary/featured lists and sort | Native forum header, API actions, digest/sort filters, paginated cards | Guest forum list/detail/rules API probed; writes pending |
| Forum rules | Native expandable `PbContent` rules through the same text/link/emoticon/image renderer as posts | API fixture confirms links and images survive mapping; rule content is not arbitrary HTML, and no HTML or WebView dependency is needed |
| Forum search | Native scoped thread search | Guest API probed |
| Thread pagination, author-only, forward/reverse order, jump | `ThreadPage` and `PagedList`; anchored responses use actual server page and overlapping post IDs are deduplicated | Guest thread API probed; anchored pagination is covered by focused Flutter tests |
| Reading history / continued reading | Account-scoped thread, page, top-visible post and `onlyAuthor`; updated after scrolling settles | Saved post uses the upstream `pn=0` / `pid` anchor; a guest probe starts at the requested floor; visible-item tracking is covered by a Flutter widget test |
| Thread and forum history | Separate native tabs, per-item removal and per-tab clearing; forum history and recent-forum list stay consistent | Store migration retains older records without inventing visit timestamps |
| Immersive reading | Reading mode hides reply previews and action bar | Implemented preference and per-thread toggle |
| Thread/floor favorite and like | API-backed buttons | Authenticated acceptance pending |
| Floor replies | Native floor screen, previews, nested target IDs | Guest thread content probed; nested reply writes pending |
| Rich content | Inline text, links, mentions, native Tieba emoticons; images, video and voice | Native media playback and photo permission acceptance pending |
| Emoticon picker | Actual `#(name)` wire tokens and upstream canonical catalog; bundled assets and learned server captions | Not substituted with Unicode emoji; catalog tests maintained by platform owner |
| Reply text and image uploads | Native editor, image picker, original-image toggle, upstream image markup, reply target IDs, signature | No messages sent; remote success is committed before local cleanup |
| Drafts | Account-scoped drafts; persistent content-addressed image files; target IDs retained | Sent drafts immediately hidden using a tombstone even if cleanup persistence fails |
| Native create-thread publishing | Not offered | The reference branch itself routes this FAB action to `toast_feature_unavailable`; an apparent setting is not an implemented upstream feature |
| Own post/thread removal | Controls only on own content, explicit destructive confirmation, verified upstream request structure | No delete request executed; unrelated to MySQL operations |
| Reporting | Retrieves server report URL using `category=1` and actual post ID; restricted genuine Baidu action WebView | Session cookies are scoped to exact Tieba origins and isolated between accounts; authenticated iPhone acceptance pending |
| Search forums/threads/users | Native tabs, debounced live suggestions, search history, sorting, pagination | Guest search and suggestion endpoints probed |
| User profile, posts/replies, liked forums | Native screens and profile counters | Guest profile and posts endpoints probed |
| Follow user | API-backed native action | Authenticated acceptance pending |
| Edit nickname/bio/sex/avatar | Native form, image picker, square avatar crop and upstream upload; unchanged demographic fields omitted | Crop math checks passed; no authenticated profile changes executed; uncertain/partial writes are explicitly reported |
| Following/follower counters | Native profile counters | The reference branch has no implemented native follow/fan list route to migrate |
| Account login and switching | Genuine Baidu WebView login, validated session, Keychain storage, account-scoped local data | iOS WebView/cookie/session acceptance pending |
| Saved posts | Native API list, saved-floor anchor | Authenticated acceptance pending |
| Local filtering | Separate block/allow rules for user/forum/thread/keyword; case-sensitive AND keyword groups; hide/notice/reveal modes; blocked nested previews removed | Allow rules override matching deny rules of the same kind; title and excerpt evaluated separately; store behavior checked by platform tests |
| Image viewing, save/share | Native zoom/page gallery, system share, Photos save | iPhone Photos permission / file export acceptance pending |
| Image cache management | Displays actual indexed cache-file sizes and clears viewing-image cache, preserving drafts and background assets | Native cache service verified separately; browser preview reports unavailable disk size |
| Service center | Authenticated official service-center page inside restricted `BaiduActionPage` | Exact Tieba HTTPS origin, shared isolated cookie lifecycle; iPhone account acceptance pending |
| Video and voice | Native `video_player` / `just_audio` controllers | No custom Android ExoPlayer code copied; live native media acceptance pending |
| Deep links | `tblite://`, supported Tieba thread/forum URLs, native dispatch | Parsing tests; actual iOS incoming-link acceptance pending |
| About/licenses | Native attribution and license routes | Redistribution must preserve upstream notices and corresponding source |

## Preference audit

Only options with a connected behavior are exposed. Some reference keys are old implementation details or unused switches; they are listed to avoid implying that storing a key means porting its behavior.

| Reference key(s) | Port status |
| --- | --- |
| `theme`, `darkTheme`, `followSystemNight` | Adapted to system/light/dark `themeMode` and original grey / blue / AMOLED dark palette choices |
| `customPrimaryColor` | Native accent palette; root theme uses stored ARGB integer |
| `toolbarPrimaryColor` | Root theme applies accent-colored toolbar |
| `fontScale` | Native app text scaling |
| `radius` | Root theme uses configurable corner radius |
| `listSingle` | Home list/grid toggle |
| `hideExplore` | Removes Discover destination |
| `homePageScroll` | Enables swipe between main pages |
| `homePageShowHistoryForum` | Shows/hides recently visited forums |
| `showTopForumInNormalList` | Keeps/removes pinned forums from followed list |
| `hideForumIntroAndStat` | Hides forum description and statistics |
| `defaultSortType` / `default_sort_type` | Forum initial reply/post order, with per-forum choice remembered |
| `hideMedia` | Hides inline and card image/video media |
| `hideReply` | Hides floor reply previews |
| `blockVideo` | Filters video feed/forum cards |
| `imageDarkenWhenNightMode` | Dims inline/card images in dark mode |
| `collectThreadSeeLz` / `collect_thread_see_lz` | Saved-thread initial author-only mode |
| `collectThreadDescSort` / `collect_thread_desc_sort` | Saved-thread initial reverse order |
| `postOrReplyWarning` | Explicit confirmation before reply submission |
| `littleTail` / `little_tail` | Reply signature appended to submitted content |
| `oksignSlowMode` | Adapted to `signSlowMode`, sequential request pause |
| `picWatermarkType` | Connected to upload API: none / username / forum |
| `imageLoadType` | Connected smart original (Wi-Fi original / cellular thumbnail), Wi-Fi-only, always original, and tap-to-load policies |
| `loadPictureWhenScroll` | Defers starting new image loads during fast scrolling when disabled |
| `hideBlockedContent`, `showBlockTip` | Remove matching cards, or display a collapsed notice with an explicit reveal action |
| `showBothUsernameAndNickname` | Native author labels can show both display name and raw username |
| `listItemsBackgroundIntermixed` | Alternating backgrounds on native paginated lists; can be disabled |
| `forumFabFunction` | Refresh (scroll to top + reload), back to top, or hide; original unimplemented post action is not presented |
| `showShortcutInThread` | Shows/hides author-only/order/previous-page shortcut row; menu actions remain available |
| `hideForumIntroAndStat` | Connected, including both prose and counters |
| `useWebView`, `useCustomTabs` | Regular links choose external browser or iOS SafariViewController via `useWebView`; credential injection is limited to restricted official report/login pages |
| `translucentThemeBackgroundPath`, `translucentBackgroundAlpha`, `translucentBackgroundBlur`, `translucentBackgroundTheme`, `translucentPrimaryColor` | Adapted to retained background image, blur, surface opacity, shade, light/dark mode and accent palette |
| `useDynamicColorTheme` | Android wallpaper-derived palette not copied; manual accent selection available |
| `appIcon`, `useThemedIcon` | Adapted to bundled default / blue / dark iOS alternate icon choices; Android wallpaper-adaptive icon behavior is platform-specific |
| `customStatusBarFontDark`, `statusBarDarker` | Android status bar specifics replaced by Flutter/iOS theme behavior |
| `liftUpBottomBar`, `imeHeight` | Replaced by iOS SafeArea and native keyboard insets |
| `doNotUsePhotoPicker` | Android picker fallback not copied; iOS uses system photo picker |
| `ignoreBatteryOptimizationsDialog` | Android-only; not applicable |
| `autoSign`, `autoSignTime`, `signDay` | Android foreground service/alarm/boot receiver not copied; no guaranteed iOS background timer advertised |
| `oksignUseOfficialOksign` | Uses official batch endpoint subject to server eligibility; confirmed IDs count as signed, remainder falls back to individual requests |
| `checkCIUpdate` | Android APK/AppCenter updater not applicable to sideloaded IPA |
| `showExperimentalFeatures` | Upstream hidden debug switch not presented |
| `oldTheme`, `userLikeLastRequestUnix` | Internal migration/cache bookkeeping, not user-facing port requirements |

Additional Flutter preferences (`compactCards`, `restoreReading`, `readerMode`, `originalImages`) support the implemented native screens; they do not imply equivalent unimplemented upstream keys.

## iOS differences and acceptance

- APK updating, boot receivers, quick-settings tiles, launcher aliases, Android permission dialogs and vendor window integrations are not portable iOS behavior.
- Login, official report submission and the original service center use restricted genuine Baidu WebViews. Reading, search, feeds, forums, profiles, replies and media use Flutter/native widgets rather than displaying Tieba pages in a browser shell.
- A macOS/Xcode build and unsigned IPA packaging are separate from successful Windows Dart checks. Sideloadly signing and an iPhone run remain required for release acceptance.
- The matrix describes implemented source behavior and explicit iOS adaptations. Authenticated flows still require validation on the user's device; compilation alone does not establish release acceptance.

## Asset attribution

The emoticon assets are carried from the referenced repository or fetched from the same official Tieba CDN paths the original client uses. Original source/provenance is recorded in `THIRD_PARTY_NOTICES.md` by the platform owner. Other original logos, fonts, launch artwork and unrelated animations are not copied. Upstream includes GPL v3 in `LICENSE` and a non-commercial statement in its README; this audit records the texts without resolving their legal interaction.
