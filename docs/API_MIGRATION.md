# Tieba API migration and verification

## Source baseline

The implementation adapts public Tieba Lite `4.0-dev` at commit
`2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15`.

Source references:

- [API interfaces and transport](https://github.com/HuanCheng65/TiebaLite/tree/2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15/app/src/main/java/com/huanchengfly/tieba/post/api)
- [Protobuf schemas](https://github.com/HuanCheng65/TiebaLite/tree/2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15/app/src/main/protos)
- [Protocol request construction](https://github.com/HuanCheng65/TiebaLite/blob/2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15/app/src/main/java/com/huanchengfly/tieba/post/api/interfaces/impls/MixedTiebaApiImpl.kt)
- [Sofire device bootstrap](https://github.com/HuanCheng65/TiebaLite/blob/2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15/app/src/main/java/com/huanchengfly/tieba/post/utils/SofireUtils.kt)
- [Sofire RC442 transform](https://github.com/HuanCheng65/TiebaLite/blob/2885b2aabbbf47aba7bf12b1cd7cbc03b1f5ec15/app/src/main/java/com/huanchengfly/tieba/post/utils/RC442.kt)

This is an independent client of undocumented service APIs. Source-backed implementation,
offline protocol tests, guest live checks, and authenticated device acceptance are separate
verification states. A compiled app alone does not prove account-dependent functionality.

## Implementation

`lib/core/models.dart` defines immutable-field domain models, opaque string identifiers,
session serialization, paged results, notifications and content parts.

`lib/core/transport.dart` implements HTTPS transport, decoded-value form signatures,
protobuf multipart requests, service-error mapping, credential redaction and Sofire.
Requests never follow redirects automatically. No request body or credential logging is
installed. Login credential candidates are redacted even before an active session exists.

`lib/core/tieba_api.dart` maps service responses into domain models. It joins response
`user_list` to post/thread author IDs, tracks concern-feed page cursors per account, and
keeps fresh `anti.tbs` values scoped to the account that made the request. Unknown content
preserves its text instead of pretending to support every optional server extension.

### Signing and schemas

JSON/form `sign` is uppercase MD5 of UTF-8 encoded, lexicographically sorted decoded
`key=value` strings concatenated without `&`, followed by `tiebaclient!!!`.
The public upstream protocol constant is not a user credential.

All 302 upstream `.proto` files are preserved in `proto/`. Dart bindings in
`lib/core/proto/` were actually generated with official `protoc 33.2` and the project's
locked `protoc_plugin 25.1.0` / `protobuf 6.1.0`. No handwritten wire encoder is used.

The Windows compiler ZIP was downloaded from the official
[protobuf v33.2 release](https://github.com/protocolbuffers/protobuf/releases/tag/v33.2).
Its SHA-256 matched the release asset digest:
`376770cd4073beb63db56fdd339260edb9957b3c4472e05a75f5f9ec8f98d8f5`.

Regenerate after `flutter pub get`:

```powershell
./scripts/generate_protos.ps1 -Protoc '<protoc.exe>' -Dart '<dart.bat>'
```

The script uses the project's resolved package configuration and generates only local
bindings. It does not invoke Gradle, Java compilation, or company Maven.

## Implemented API surface

| Surface | Protocol / implementation |
| --- | --- |
| Baidu login validation | `/c/s/login`, `/c/s/initNickname`, returned account and `anti.tbs` |
| Device verification token | Sofire gzip + AES-CBC/PKCS7 + RC4 xor 42, encrypted response decode |
| Followed forums | `/c/f/forum/getforumlist` |
| Personalized feed | `/c/f/excellent/personalized?cmd=309264` protobuf |
| Following feed | `/c/f/concern/userlike?cmd=309474` protobuf and account-scoped `pageTag` |
| Hot feed | `/c/f/forum/hotThreadList?cmd=309661` protobuf |
| Hot ranking cards / category tabs / complete topic ranking | V11 HotThreadList with `tabId=1`, selected `tabCode`; TopicList with `call_from=newbang,list_type=all` |
| Topic metadata and available thread results | `/mo/q/newtopic/topicDetail`; mapped hybrid response, empty pages terminate pagination |
| Forum threads / digest / sorting | `/c/f/frs/page?cmd=301001` protobuf |
| Thread pages / author-only / sorting / post anchor | `/c/f/pb/page?cmd=302001&format=protobuf` |
| Sub-posts | `/c/f/pb/floor?cmd=302002&format=protobuf` |
| Search forums / threads / users / in-forum search | `/mo/q/search/forum`, `/thread`, `/user` hybrid JSON |
| Search suggestions | `/c/s/searchSug?cmd=309438&format=protobuf`, V12 generated request |
| Bookmarks, add/remove bookmark | `/c/f/post/threadstore`, `/c/c/post/addstore`, `/rmstore` |
| Replies, mentions, likes inbox and counts | `/c/u/feed/replyme`, `/atme`, `/agreeme`, `/c/s/msg` |
| User profile / authored threads and replies / followed forums | Profile and UserPost protobuf; `/c/f/forum/like` |
| Forum details and rules | GetForumDetail and ForumRuleDetail protobuf |
| Forum sign-in / follow / unfollow | Source-defined signed form endpoints |
| Official batch check-in | `/c/c/forum/msign`; server `level` / `msign_step_num` eligibility, only explicit `signed=1` IDs count |
| User follow / unfollow | Source-defined signed form endpoints using portrait identifier |
| Like / unlike | `/c/c/agree/opAgree` |
| Reply and sub-reply | AddPost protobuf with source-defined parent/sub-post fields |
| Image upload | `/c/s/uploadPicture`, chunked at 512000 bytes, dimensions and MD5 resource ID; user watermark and original-image options |
| Profile editing | `/c/c/profile/modify`; unspecified birthday/sex fields are omitted |
| Profile portrait | `/c/c/img/portrait`, `pic` multipart field and V11 version; square-image validation |
| Report preparation | `/c/f/ueg/checkjubao`, exact upstream `category=1,pid=...`; opens returned flow |
| Delete owned thread / post | Current upstream `/c/c/bawu/delthread` and `/delpost`; UI confirmation required |

Image reply markup is `#(pic,pictureId,width,height)`. Uploading a file alone does not send
a reply. All write actions require a signed-in session and explicit UI actions.

Content mappings include text types `0/9/27`, links `1`, emoji `2`, images `3/20`, mentions
`4`, video `5`, and voice `10`. Emoji preserve `sourceId` and `caption`; voice URLs use the
upstream playback endpoint. Emoji HTTPS URLs use `tieba.baidu.com`, since the legacy
`static.tieba.baidu.com` hostname failed normal certificate validation during verification.

## Verification evidence

Read-only checks were performed on **2026-09-24, approximately 17:30-17:45 Asia/Shanghai**
with a synthetic installation identifier, without any user credentials. Counts below
describe those responses, not fixed fixtures or promises about future service results.

| Guest check | Observed result |
| --- | --- |
| Search forums for `iPhone` | 51 parsed forums |
| `iPhone` forum page | 13 parsed threads, usable thread IDs |
| Personalized feed | 12 parsed threads |
| Open a returned thread | 3 parsed posts; author joined and forum/thread IDs present |
| Sub-post request for that first post | Valid response with zero sub-posts |
| Search threads for `iPhone` | 20 parsed results |
| Search users for `iPhone` | 44 parsed users |
| Hot feed | 4 parsed threads |
| Public author profile | Returned matching account ID |
| Public author's posts | 60 parsed records |
| Forum detail | Returned matching forum ID |
| Forum rules | 10 parsed rule sections |
| Sofire guest bootstrap | Nonempty token decoded; token was not printed or saved by the probe |

Additional read-only guest checks on **2026-09-24** returned 7 overview topics, 4 hot
threads, 4 category tabs, 30 full ranking topics, and 4 `iPhone` search suggestions.
The source-defined topic-detail endpoint returned valid topic metadata but empty thread
and related-forum lists, even with `has_more=true`; its next page returned service code
`300000`. The client stops pagination on an empty page. Topic-thread availability is not
claimed from this metadata-only response. The upstream revision defines this interface
but does not call it from the native ranking cards.

The API/model/transport and protocol test files passed `dart analyze` with no issues.
`test/core/api_protocol_test.dart` covers the independent signing vector, RC442 reference
vector, credential redaction, authentication gating, real generated protobuf request and
response fixtures, proto3 zero-value pagination, rich content mapping, fresh `tbs`, and
synthetic encrypted Sofire responses. Flutter test execution is tracked in the root
validation record rather than inferred from static analysis.

Additional offline fixtures cover ranking protobuf field names, hybrid topic identity
and thumbnail mapping, raw username versus display name, omitted profile fields, official
batch eligibility/explicit success, and portrait versus reply-image multipart contracts.
No fixture sends authenticated requests to Baidu.

Forum-rule sections retain typed `ContentPart` values from their protobuf `PbContent`
arrays, including links, images, and other supported rich content; they are not HTML.

A guest position-anchor probe on 2026-09-24 demonstrated that `pid` plus `pn=1`
returned posts after the requested floor and omitted the target. The upstream-style
`pid` plus `pn=0` included that target as the first returned post and reported its
actual `page.current_page`. `threadPosts` therefore sends zero internally for a nonzero
position anchor and exposes the actual server page. This verifies floor positioning
for the sampled public thread, not exact pixel scrolling or deleted-post behavior.

## Acceptance still required

- No real account was used in API probes. Login persistence, following feed, account-only
  lists and inbox must be checked on the user's device with the user's own sign-in.
- No real reply, image upload, like, follow, sign-in, bookmark change, profile edit, report,
  or deletion was executed during development. These implementations have source and
  offline verification, not authenticated service acceptance.
- Server verification/captcha remains server controlled. The client must display failures
  and open legitimate verification flows; it must not retry a possibly successful post
  automatically. An absent returned post ID is reported as unconfirmed.
- Sofire is attempted during login. If its optional service fails, the session can still
  browse with an empty `zid`; authenticated writes may require signing in again when the
  service recovers.
- The Flutter client uses the upstream Android-compatible API schema on iOS with an
  app-generated installation ID. It does not read hardware identifiers. Server fingerprint
  policy can change; guest success cannot establish every account's posting compatibility.
- This upstream revision exposes follower/following counts but no native follower/following
  list interface, and no native create-thread endpoint was found. These are not implemented
  by inventing API routes. The official website remains a possible explicit fallback.
- Rich optional advertising, live-streaming, commerce and unsupported content extensions
  are not claimed as fully reproduced. The client filters advertising/live entries and
  preserves readable unknown content where available.
