# iOS platform implementation and verification

The port uses native Flutter pages for reading and interaction. Account authentication and official account actions such as reporting use WKWebView on vetted Baidu origins. This document distinguishes implemented code from validation that still requires a signed iOS build and a physical device.

## Credentials and accounts

`SessionStore` saves `TiebaSession` and the associated `UserProfile` in one versioned `flutter_secure_storage` item. On iOS the plugin uses Keychain. Credentials are never written to `SharedPreferences`, debug logs, the repository, or GitHub Actions secrets. Browser preview is guest-only and rejects credential persistence.

The iOS options use `KeychainAccessibility.unlocked` and no explicit `groupId`. In the pinned `flutter_secure_storage_darwin` implementation, a `kSecAttrAccessGroup` query is added only when an explicit `groupId` exists. The application therefore uses its signing identity's default Keychain access. The plugin README documents an empty `keychain-access-groups` entitlement; no cross-application App Group is needed. Preserve the bundle identifier and signing team across Sideloadly updates. A different signing identity can make earlier Keychain items inaccessible; the UI must require sign-in again instead of assuming the session is valid.

Account mutations are serialized and published only after secure storage succeeds. Invalid saved JSON causes an error rather than replacement. Logout selects guest mode or removes the selected saved account, as chosen by the UI. It does not revoke the session on Baidu's servers.

`LocalStore` keeps thread and forum histories, forum pins, search history, blocking rules, and reply drafts in separate account namespaces. Thread history retains its `onlyAuthor` mode; older records default to false. Forum visits retain timestamps and support individual removal. Existing recent-forum records migrate with an unknown timestamp rather than an invented visit date. Removing forum history also removes the corresponding recent-forum shortcut. Switching to a corrupt namespace immediately exposes an empty state and rejects writes until successful loading, preserving the original data for recovery. The controller must disable interaction during account changes and fall back to guest mode after an account-load failure. Settings are application-wide and contain no authentication values.

Sources: [secure storage package documentation](https://pub.dev/packages/flutter_secure_storage), [Darwin implementation](https://github.com/juliansteenbakker/flutter_secure_storage/tree/develop/flutter_secure_storage_darwin).

## Native login

`BaiduLoginPage` loads `https://wappass.baidu.com/` and allows HTTPS main-frame navigation only within `baidu.com`. It uses the platform CookieManager backed by `WKHTTPCookieStore`, including HttpOnly cookies. It never reads password form fields or substitutes a password-entry form.

The dedicated authentication WebView store is cleared before and after each sign-in to isolate accounts. It intentionally does not use an incognito WebView: a separate nonpersistent website data store would not match the shared CookieManager. Cookies are passed in memory to the API for account validation. Only a validated session is stored. Login errors shown by the page are localized generic messages and do not include cookies or transport diagnostics.

On web preview, sign-in is unavailable because an iframe cannot reliably access the official site's HttpOnly cookies. A successful browser preview is not proof of iOS login behavior.

Source: [InAppWebView CookieManager](https://inappwebview.dev/docs/cookie-manager/).

## Authenticated report forms

`BaiduActionPage` accepts HTTPS report URLs from `tieba.baidu.com` or `tiebac.baidu.com`. It rejects user information, alternate ports, lookalike domains, arbitrary Baidu subdomains, and external main-frame navigation. Official `wappass.baidu.com` and `passport.baidu.com` redirects may load, but stored credentials are injected only for the initial vetted Tieba host. Only `BDUSS`, `STOKEN`, and `BAIDUID` are injected; each is Secure and HttpOnly. No cookie values are placed in URLs or JavaScript.

Login and action pages share `BaiduWebSessionCoordinator`. Only one page can own the shared native cookie store. Cookie and website storage cleanup completes before another page configures its session. An old lease cannot clear a newer page's session. Cleanup failures prevent a later page from loading until cleanup succeeds. The report form remains interactive and the user chooses whether to submit it; opening it does not submit a report.

The upstream `TiebaUtil.reportPost` obtains a report URL from `/c/f/ueg/checkjubao` and navigates to its WebView. An authenticated response and physical-device report flow have not been exercised, so other official report origins remain unsupported until verified rather than receiving credentials automatically.

## Profile editing

`EditProfilePage` supports nickname, introduction, sex, and avatar selection. The avatar uses a native gallery picker and a Flutter square crop with pan/zoom. Decoding and 512-pixel JPEG preparation run outside the UI isolate; image size and dimensions are bounded. Only an explicit Save uploads the prepared avatar. The API uses the upstream portrait multipart endpoint and profile-update fields; unchanged birthday fields are omitted because this upstream revision does not expose an active birthday editor.

Avatar and profile fields are separate remote mutations. If the avatar succeeds and the text update fails, the pending avatar is cleared and the UI reports partial success. A network/ambiguous result disables another Save until the user explicitly reloads their profile. No failed mutation is automatically replayed. Avatar crop tests verify viewport geometry and resulting pixel content; authenticated updates still require device verification.

## Block and draft semantics

Block rules retain the upstream distinction between denied and allowed users or keyword groups. Keywords are case-sensitive; every keyword in a group must appear in the same content string. Thread title and abstract are evaluated separately. An allowed user does not override blocked text, and a keyword exemption in the abstract does not override a blocked title. ID and canonical username can match a user rule; display nicknames are not treated as canonical usernames when both are available. Existing rules without an `allow` field remain denied rules.

Reply-success cleanup accepts the sending account ID. A reply that finishes after an account switch removes only the original account's draft and cannot hide or overwrite the newly active account's draft with the same key.

## Media and drafts

`MediaActions.saveImage` requests the system Photos permission after the user chooses Save, downloads the HTTPS image, checks the response type and a 50 MB cap, then uses `Gal.putImageBytes`. Required `Info.plist` key: `NSPhotoLibraryAddUsageDescription`. `NSPhotoLibraryUsageDescription` supports the image picker and older Photos access paths. No camera or microphone permission is required for selecting existing images and playing media.

`DraftAttachments.retainImage` copies selected images into the app's documents directory before draft persistence. `restoreImage` resolves the content-addressed filename against the current documents directory, so an iOS container path change does not invalidate the reference. A retained image has a 20 MB limit. Files are local and are uploaded only when the user explicitly submits a reply. Retained attachments currently remain in app storage after removing a draft; automatic orphan cleanup is not implemented.

The UI's share action must pass a `sharePositionOrigin` for iPad popovers. Image and media plugins still require real-device checks for GIFs, HEIC, inline video, audio interruptions, denied Photos permissions, and large files.

`ImageCacheActions` uses the existing `CachedNetworkImageProvider.defaultCacheManager`. Size inspection sums the actual lengths of its indexed files, including resized image variants whose metadata length may be unset. Clearing delegates to the manager's `emptyCache` API and clears Flutter's in-memory image cache. It does not traverse or delete documents, retained draft files, history, or credentials. In-progress image loads can populate the cache again. Browser preview cannot measure or clear browser-managed HTTP storage; the API reports an unknown disk size there.

Sources: [Gal setup and APIs](https://pub.dev/packages/gal), [share_plus iPad requirements](https://pub.dev/packages/share_plus), [image_picker](https://pub.dev/packages/image_picker).

## Alternate application icons

`AppIcons` exposes the system-reported icon and explicit `default`, `blue`, and `dark` choices. The iOS method channel is registered through `FlutterImplicitEngineBridge.applicationRegistrar` after the implicit engine exists, matching Flutter's UIScene lifecycle. Swift validates the choice against bundled asset names, checks `supportsAlternateIcons`, prevents concurrent changes, and reports completion on the main queue. A failed system request does not change an application preference or claim that the icon changed.

The default icon uses the user-requested blue background and rounded white character; its generation prompt and source are recorded in `APP_ICON.md`. The optional blue/dark palettes retain the original geometric speech bubble. `scripts/generate_icons.py` generates opaque RGB PNGs for the existing iPhone/iPad icon slots. Xcode's `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` includes `AppIconBlue` and `AppIconDark` in Debug, Profile, and Release so the asset compiler generates the corresponding `CFBundleAlternateIcons` entries. Android wallpaper-themed icons are not copied. Windows Dart tests verify the channel contract and error handling; actual asset compilation, iOS system confirmation, Home Screen appearance, and Sideloadly-installed behavior require macOS CI and a physical iPhone.

Sources: [Apple alternate app icon configuration](https://developer.apple.com/documentation/xcode/configuring-your-app-to-use-alternate-app-icons), [Apple icon-changing API](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname(_:completionhandler:)), [Flutter UIScene platform channel registration](https://docs.flutter.dev/platform-integration/platform-channels).

## Deep links

Register the `tblite` URL scheme in `CFBundleURLTypes`. Set `FlutterDeepLinkingEnabled` to `false` when using `app_links`. Instantiate `DeepLinks` early and subscribe once the navigator is ready. The stream includes a cold-start link and subsequent links.

Supported routes are `tblite://thread/<id>`, `forum/<name>`, `user/<id>`, `notifications/<tab>`, `history`, `favorite`, and `search`. Known Tieba HTTPS thread/forum links are parsed for in-app navigation. Unknown hosts, unsupported action routes, and malformed IDs are ignored. No incoming link can automatically log in, post, sign in to a forum, or remove content.

Custom URL schemes do not require Universal Link domain ownership. The project cannot register Baidu's domain as its own Universal Link association. A copied Tieba HTTPS link can still be handled by the in-app parser; this does not guarantee Safari will open it in this app.

Sources: [app_links](https://pub.dev/packages/app_links), [app_links iOS integration](https://github.com/llfbandit/app_links/blob/main/doc/README_ios.md).

## Background execution and Android-specific features

The Android implementation uses services, scheduled work, boot receivers, and quick-settings integration. iOS does not provide equivalent unrestricted background execution. Foreground/manual sign-in and message refresh are the reliable behavior. Background scheduling must be described as best effort if added, never as exact-time or continuous execution. This code currently does not register BGTaskScheduler work or a remote push service. Local notification reminders alone would not perform server-side sign-in.

Android APK update installation, MIUI/battery-optimization dialogs, OAID, and Android launcher aliases are not portable iOS features. The iOS installation/update path is the generated IPA plus Sideloadly. Do not mark those platform mechanisms as silently implemented by the Flutter migration.

Source: [Apple background execution guidance](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app), [BGTaskRequest.earliestBeginDate does not guarantee an exact launch time](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate).

## Native dependency manager

Flutter 3.47 supports Swift Package Manager and CocoaPods. The current `flutter_inappwebview_ios` version provides a Podspec but no Swift package. Other native iOS dependencies in the resolved package set have Podspecs; `path_provider_foundation` has no native dependency-manager manifest because this version uses Dart native interoperability.

For a CocoaPods build, disable Swift Package Manager before `flutter pub get` and build. Flutter's `darwin_dependency_management.dart` explicitly generates an empty `FlutterGeneratedPluginSwiftPackage` for a project whose Xcode references remain after disabling SwiftPM. Existing references need not be removed manually. Flutter's documentation also distinguishes disabling SwiftPM from removing its Xcode integration. The project-local `flutter.config.enable-swift-package-manager: false` setting is preferable for reproducibility if CocoaPods is the chosen build mode.

This is a source-level compatibility assessment. Only the macOS build can verify Xcode, CocoaPods, deployment targets, and plugin linking together.

Source: [Flutter Swift Package Manager documentation](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers).

## Validation record

- Local Dart tests cover restart persistence, absence of credentials in preferences, corrupt-data preservation, queued account isolation, failed-account activation, block filtering, preference reset scope, and strict deep-link parsing.
- Local static analysis checks the persistence and platform Dart code.
- iOS build, Keychain entitlement behavior after signing, WKWebView login, Photos permission behavior, share sheets, media codecs, cold-start links, and app-update persistence require macOS CI and a physical iPhone. These have not been established by local Windows checks.
- No Gradle or Java tests are involved in these checks.
