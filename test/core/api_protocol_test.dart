import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as image;
import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_lite/core/tieba_api.dart';
import 'package:tieba_lite/core/transport.dart';
import 'package:tieba_lite/core/proto/PbPage/PbPageRequest.pb.dart';
import 'package:tieba_lite/core/proto/PbPage/PbPageResponse.pb.dart';
import 'package:tieba_lite/core/proto/AddPost/AddPostRequest.pb.dart';
import 'package:tieba_lite/core/proto/AddPost/AddPostResponse.pb.dart';
import 'package:tieba_lite/core/proto/Personalized.pb.dart';
import 'package:tieba_lite/core/proto/HotThreadList/HotThreadList.pb.dart';
import 'package:tieba_lite/core/proto/TopicList/TopicList.pb.dart';
import 'package:tieba_lite/core/proto/Profile/ProfileResponse.pb.dart';
import 'package:tieba_lite/core/proto/ForumRuleDetail/ForumRuleDetailResponse.pb.dart';

typedef ResponseHandler = ResponseBody Function(RequestOptions, Uint8List);

class FixtureAdapter implements HttpClientAdapter {
  FixtureAdapter(this.handler);
  final ResponseHandler handler;
  int count = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    count++;
    final builder = BytesBuilder();
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        builder.add(chunk);
      }
    }
    return handler(options, builder.takeBytes());
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody binary(List<int> bytes) => ResponseBody.fromBytes(
  bytes,
  200,
  headers: {
    'content-type': ['application/octet-stream'],
  },
);
ResponseBody jsonBody(Object value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    'content-type': ['application/json'],
  },
);

List<int> multipartData(RequestOptions options, Uint8List bytes) {
  final boundary = (options.data as FormData).boundary;
  final body = latin1.decode(bytes);
  final part = body.indexOf('name="data"');
  final start = body.indexOf('\r\n\r\n', part) + 4;
  final end = body.indexOf('\r\n--$boundary', start);
  expect(part, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  return bytes.sublist(start, end);
}

void main() {
  test(
    'followed forums distinguish missing member counts from real zero',
    () async {
      final adapter = FixtureAdapter((options, _) {
        expect(options.path, endsWith('/c/f/forum/getforumlist'));
        return jsonBody({
          'error_code': '0',
          'forum_info': [
            {
              'forum_id': '1',
              'forum_name': 'Missing count',
              'user_level': '5',
              'is_sign_in': '1',
            },
            {'forum_id': '2', 'forum_name': 'Empty forum', 'member_num': '0'},
            {
              'forum_id': '3',
              'forum_name': 'Populated forum',
              'member_num': '456',
            },
          ],
        });
      });
      final api = TiebaApi(
        sessionProvider: () => const TiebaSession(
          userId: '42',
          bduss: 'fixture-bduss',
          stoken: 'fixture-stoken',
        ),
        dio: Dio()..httpClientAdapter = adapter,
      );
      final forums = await api.followedForums();
      expect(forums.map((forum) => forum.memberCount), [null, 0, 456]);
      expect(forums.first.level, 5);
      expect(forums.first.isSigned, isTrue);
      expect(forums.every((forum) => forum.isFollowing), isTrue);
      expect(Forum.fromJson(forums.first.toJson()).memberCount, isNull);
      expect(adapter.count, 1);
      api.close();
    },
  );

  test(
    'same-account login replaces a tbs cached under the previous session',
    () async {
      var session = const TiebaSession(
        bduss: 'old-fixture-bduss',
        stoken: 'old-fixture-stoken',
        userId: '42',
        tbs: 'old-session-tbs',
      );
      final threadResponse = PbPageResponse()
        ..mergeFromProto3Json({
          'data': {
            'anti': {'tbs': 'old-read-tbs'},
            'thread': {'id': '123'},
          },
        });
      final adapter = FixtureAdapter((options, bytes) {
        if (options.path.contains('/pb/page')) {
          return binary(threadResponse.writeToBuffer());
        }
        if (options.path.contains('/c/s/login')) {
          return jsonBody({
            'error_code': '0',
            'user': {'id': '42', 'name': 'Fixture'},
            'anti': {'tbs': 'new-login-tbs'},
          });
        }
        if (options.path.contains('/initNickname')) {
          return jsonBody({'error_code': '0'});
        }
        if (options.uri.host == 'sofire.baidu.com') return jsonBody({});
        expect(options.path, endsWith('/c/c/forum/sign'));
        expect(
          Uri.splitQueryString(utf8.decode(bytes))['tbs'],
          'new-login-tbs',
        );
        return jsonBody({'error_code': '0'});
      });
      final api = TiebaApi(
        sessionProvider: () => session,
        dio: Dio()..httpClientAdapter = adapter,
      );
      await api.threadPosts('123');
      session = await api.login(
        bduss: 'new-fixture-bduss',
        stoken: 'new-fixture-stoken',
      );
      expect(session.tbs, 'new-login-tbs');
      await api.signForum(const Forum(id: '9', name: 'Forum'));
      expect(adapter.count, 5);
      api.close();
    },
  );
  test(
    'forum rules preserve protobuf links and images as typed content',
    () async {
      final response = ForumRuleDetailResponse()
        ..mergeFromProto3Json({
          'data': {
            'title': 'Rules',
            'preface': 'Introduction',
            'bazhu': {'user_name': 'Moderator'},
            'rules': [
              {
                'title': 'Rule one',
                'content': [
                  {'type': 0, 'text': 'Text'},
                  {
                    'type': 1,
                    'text': 'Linked terms',
                    'link': 'https://example.test/terms',
                  },
                  {'type': 3, 'src': 'https://example.test/rule.png'},
                ],
              },
            ],
          },
        });
      final api = TiebaApi(
        sessionProvider: () => null,
        dio: Dio()
          ..httpClientAdapter = FixtureAdapter(
            (_, _) => binary(response.writeToBuffer()),
          ),
      );
      final rules = await api.forumRules('9');
      expect(rules.first.parts.single.text, 'Introduction');
      expect(rules.last.author, 'Moderator');
      expect(rules.last.parts.map((part) => part.type), [
        ContentType.text,
        ContentType.link,
        ContentType.image,
      ]);
      expect(rules.last.parts[1].url, 'https://example.test/terms');
      expect(rules.last.parts[2].url, 'https://example.test/rule.png');
      api.close();
    },
  );
  test(
    'hot rankings use upstream legacy fields and preserve tabs and topics',
    () async {
      final adapter = FixtureAdapter((options, bytes) {
        if (options.path.contains('/hotThreadList')) {
          final request = HotThreadListRequest.fromBuffer(
            multipartData(options, bytes),
          );
          expect(request.data.tabCode, 'games');
          expect(request.data.tabId, '1');
          final response = HotThreadListResponse()
            ..mergeFromProto3Json({
              'data': {
                'topicList': [
                  {
                    'topicId': '7',
                    'topicName': 'Topic',
                    'discussNum': '81',
                    'tag': 2,
                  },
                ],
                'hotThreadTabInfo': [
                  {'tabId': 2, 'tabTitle': 'Games', 'tabCode': 'games'},
                ],
              },
            });
          return binary(response.writeToBuffer());
        }
        final request = TopicListRequest.fromBuffer(
          multipartData(options, bytes),
        );
        expect(request.data.callFrom, 'newbang');
        expect(request.data.listType, 'all');
        final response = TopicListResponse()
          ..mergeFromProto3Json({
            'data': {
              'topic_list': [
                {
                  'topic_id': '8',
                  'topic_name': 'Ranked topic',
                  'discuss_num': '19',
                  'topic_image': 'http://example.com/topic.jpg',
                },
              ],
            },
          });
        return binary(response.writeToBuffer());
      });
      final api = TiebaApi(
        sessionProvider: () => null,
        dio: Dio()..httpClientAdapter = adapter,
      );
      final overview = await api.hotOverview(tabCode: 'games');
      expect(overview.topics.single.id, '7');
      expect(overview.topics.single.hotCount, 81);
      expect(overview.tabs.single.code, 'games');
      expect(
        (await api.hotTopics()).single.imageUrl,
        'https://example.com/topic.jpg',
      );
      api.close();
    },
  );

  test('hybrid topic pages join thread data and stop empty pages', () async {
    final adapter = FixtureAdapter(
      (options, _) => jsonBody({
        'no': 0,
        'data': {
          'topic_info': {'topic_id': '7', 'topic_name': 'Topic'},
          'has_more': true,
          'relateForum': [
            {'forum_id': '9', 'forum_name': 'Forum'},
          ],
          'relate_thread': {
            'thread_list': options.queryParameters['pn'] == 1
                ? [
                    {
                      'user_agree': 1,
                      'thread_info': {
                        'id': 999,
                        'tid': 123,
                        'title': 'Thread',
                        'abstract': 'Excerpt',
                        'user_id': 42,
                        'forum_id': 9,
                        'media': [
                          {
                            'big_pic': 'http://example.com/full.jpg',
                            'small_pic': 'http://example.com/small.jpg',
                          },
                        ],
                      },
                    },
                  ]
                : [],
          },
        },
      }),
    );
    final api = TiebaApi(
      sessionProvider: () => null,
      dio: Dio()..httpClientAdapter = adapter,
    );
    final page = await api.topicThreads('7', topicName: 'Topic');
    expect(page.items.single.id, '123');
    expect(page.items.single.author.id, '42');
    expect(page.items.single.excerpt, 'Excerpt');
    expect(
      page.items.single.imageThumbnails.single,
      'https://example.com/small.jpg',
    );
    expect(page.items.single.isLiked, true);
    expect(page.relatedForums.single.id, '9');
    expect(
      (await api.topicThreads('7', topicName: 'Topic', page: 2)).hasMore,
      false,
    );
    api.close();
  });

  test('profile mapping preserves raw name and optional edits omit birthday and sex', () async {
    const session = TiebaSession(
      bduss: 'synthetic',
      stoken: 'synthetic',
      userId: '42',
    );
    final response = ProfileResponse()
      ..mergeFromProto3Json({
        'data': {
          'user': {
            'id': '42',
            'name': 'raw-name',
            'nameShow': 'Display name',
            'sex': 2,
            'birthday_info': {
              'birthday_time': '946684800',
              'birthday_show_status': 1,
            },
          },
        },
      });
    final adapter = FixtureAdapter((options, bytes) {
      if (options.path.contains('/profile/modify')) {
        final body = Uri.splitQueryString(utf8.decode(bytes));
        expect(body.containsKey('sex'), false);
        expect(body.containsKey('birthday_time'), false);
        expect(body.containsKey('birthday_show_status'), false);
        return jsonBody({'error_code': '0'});
      }
      return binary(response.writeToBuffer());
    });
    final api = TiebaApi(
      sessionProvider: () => session,
      dio: Dio()..httpClientAdapter = adapter,
    );
    final profile = await api.userProfile('42');
    expect(profile.username, 'raw-name');
    expect(profile.name, 'Display name');
    expect(profile.sex, 2);
    expect(profile.birthday, '946684800');
    expect(profile.showBirthday, true);
    await api.updateProfile(nickname: 'Display name', intro: 'About');
    api.close();
  });

  test('official batch sign respects eligibility and counts only explicit signed IDs', () async {
    const session = TiebaSession(
      bduss: 'synthetic',
      stoken: 'synthetic',
      userId: '42',
      tbs: 'synthetic',
    );
    final adapter = FixtureAdapter((options, bytes) {
      if (options.path.contains('/getforumlist')) {
        return jsonBody({
          'error_code': '0',
          'level': '3',
          'msign_step_num': '2',
          'forum_info': [
            {'forum_id': '1', 'user_level': '1'},
            {'forum_id': '2', 'user_level': '4'},
            {'forum_id': '3', 'user_level': '5'},
            {'forum_id': '4', 'user_level': '6'},
          ],
        });
      }
      expect(Uri.splitQueryString(utf8.decode(bytes))['forum_ids'], '2,3');
      return jsonBody({
        'error_code': '0',
        'info': [
          {'forum_id': '2', 'signed': '1'},
          {'forum_id': '3', 'signed': '0'},
          {'forum_id': '99', 'signed': '1'},
        ],
      });
    });
    final api = TiebaApi(
      sessionProvider: () => session,
      dio: Dio()..httpClientAdapter = adapter,
    );
    expect(
      await api.officialBatchSign([
        for (var id = 1; id <= 4; id++) Forum(id: '$id'),
      ]),
      {'2'},
    );
    api.close();
  });

  test('portrait and reply-image uploads use distinct multipart fields and preferences', () async {
    const session = TiebaSession(
      bduss: 'synthetic',
      stoken: 'synthetic',
      userId: '42',
    );
    final adapter = FixtureAdapter((options, bytes) {
      final body = options.data as FormData;
      final fields = Map.fromEntries(body.fields);
      if (options.path.contains('/img/portrait')) {
        expect(body.files.single.key, 'pic');
        expect(fields['_client_version'], '11.10.8.6');
        return jsonBody({'error_code': '0'});
      }
      expect(body.files.single.key, 'chunk');
      expect(fields['pic_water_type'], '1');
      expect(fields['saveOrigin'], '0');
      return jsonBody({
        'error_code': '0',
        'pic_id': 'image-id',
        'pic_info': {
          'origin_pic': {'pic_url': 'https://example.com/image.jpg'},
        },
      });
    });
    final api = TiebaApi(
      sessionProvider: () => session,
      dio: Dio()..httpClientAdapter = adapter,
    );
    final bytes = Uint8List.fromList(
      image.encodePng(image.Image(width: 2, height: 2)),
    );
    await api.uploadPortrait(bytes);
    await api.uploadImage(
      bytes,
      filename: 'image.png',
      watermarkType: 1,
      saveOriginal: false,
    );
    api.close();
  });
  test(
    'feed forum identity never falls back to the thread identifier',
    () async {
      final response = PersonalizedResponse()
        ..mergeFromProto3Json({
          'data': {
            'thread_list': [
              {
                'id': '123',
                'forumId': '9',
                'forumName': 'Forum',
                'title': 'Thread',
              },
            ],
          },
        });
      final adapter = FixtureAdapter(
        (_, _) => binary(response.writeToBuffer()),
      );
      final api = TiebaApi(
        sessionProvider: () => null,
        dio: Dio()..httpClientAdapter = adapter,
      );
      final result = await api.feed();
      expect(result.items.single.id, '123');
      expect(result.items.single.forum.id, '9');
      expect(result.items.single.forum.name, 'Forum');
      api.close();
    },
  );
  test('form signing hashes decoded sorted values with uppercase hex', () {
    expect(
      TiebaTransport.sign({'b': 'two', 'a': 'x y'}),
      '1D9722E384CAA1E7693DB1062F7ADFEA',
    );
    expect(
      TiebaTransport.sign({'sign': 'ignored', 'b': 'two', 'a': 'x y'}),
      '1D9722E384CAA1E7693DB1062F7ADFEA',
    );
  });

  test('RC442 matches the RC4 reference vector with xor42', () {
    final encrypted = rc442(
      Uint8List.fromList(utf8.encode('Plaintext')),
      Uint8List.fromList(utf8.encode('Key')),
    );
    expect(encrypted, [0x91, 0xd9, 0x3c, 0xc2, 0xf3, 0x6a, 0x85, 0x20, 0xf9]);
    expect(
      utf8.decode(rc442(encrypted, Uint8List.fromList(utf8.encode('Key')))),
      'Plaintext',
    );
  });

  test(
    'server errors redact credentials and reject untrusted verification URLs',
    () {
      try {
        TiebaTransport.checkError(
          {
            'error': {
              'error_code': 4,
              'error_msg': 'denied synthetic-private-token',
            },
            'vcode_url': 'https://unrelated.example/check',
          },
          secrets: ['synthetic-private-token'],
        );
        fail('Expected server failure');
      } on TiebaApiException catch (error) {
        expect(error.requiresLogin, isTrue);
        expect(error.message, isNot(contains('synthetic-private-token')));
        expect(error.verificationUrl, isNull);
      }
    },
  );

  test('writes require a session before making a request', () async {
    final adapter = FixtureAdapter((_, _) => jsonBody({'error_code': 0}));
    final api = TiebaApi(
      sessionProvider: () => null,
      dio: Dio()..httpClientAdapter = adapter,
    );
    await expectLater(
      api.bookmark(threadId: '1'),
      throwsA(
        isA<TiebaApiException>().having(
          (error) => error.requiresLogin,
          'requiresLogin',
          true,
        ),
      ),
    );
    expect(adapter.count, 0);
    api.close();
  });

  test('generated protobuf request and response preserve anchors, authors and content variants', () async {
    final response = PbPageResponse()
      ..mergeFromProto3Json({
        'data': {
          'forum': {'id': '9', 'name': 'Forum'},
          'thread': {'id': '123', 'title': 'Thread'},
          'page': {'current_page': 7, 'has_more': 0},
          'anti': {'tbs': 'fresh-tbs'},
          'user_list': [
            {'id': '42', 'nameShow': 'Author'},
          ],
          'post_list': List.generate(
            15,
            (index) => {
              'id': '${index + 100}',
              'author_id': '42',
              'floor': index + 1,
              'content': [
                {'type': 9, 'text': 'text'},
                {
                  'type': 20,
                  'src': 'https://example.test/image.png',
                  'bsize': '80,60',
                },
                {'type': 2, 'text': 'image_emoticon25', 'c': 'Smile'},
                {'type': 10, 'voiceMD5': 'voice-id'},
              ],
            },
          ),
        },
      });
    final adapter = FixtureAdapter((options, bytes) {
      final request = PbPageRequest.fromBuffer(multipartData(options, bytes));
      expect(request.data.kz.toString(), '123');
      expect(request.data.pid.toString(), '106');
      expect(
        request.data.pn,
        0,
        reason: 'A pid is a position anchor only when pn is zero.',
      );
      expect(request.data.lz, 1);
      expect(options.uri.scheme, 'https');
      expect(options.followRedirects, false);
      return binary(response.writeToBuffer());
    });
    final api = TiebaApi(
      sessionProvider: () => null,
      dio: Dio()..httpClientAdapter = adapter,
    );
    final page = await api.threadPosts(
      '123',
      page: 2,
      onlyAuthor: true,
      anchorPostId: '106',
    );
    expect(page.items, hasLength(15));
    expect(
      page.page,
      7,
      reason: 'An anchored post can move to a different server page.',
    );
    expect(
      page.hasMore,
      false,
      reason:
          'Proto3 omits zero has_more; a full last page must stop pagination.',
    );
    expect(page.items.first.author.name, 'Author');
    expect(page.items.first.content.map((item) => item.type), [
      ContentType.text,
      ContentType.image,
      ContentType.emoji,
      ContentType.audio,
    ]);
    expect(page.items.first.content[1].width, 80);
    expect(page.items.first.content[2].sourceId, 'image_emoticon25');
    expect(page.items.first.content[2].caption, 'Smile');
    expect(page.items.first.content[3].url, contains('voice_md5=voice-id'));
    api.close();
  });

  test('reply uses the latest account tbs from a fetched thread', () async {
    const session = TiebaSession(
      bduss: 'synthetic-bduss',
      stoken: 'synthetic-stoken',
      userId: '42',
      tbs: 'old-tbs',
    );
    final adapter = FixtureAdapter((options, bytes) {
      if (options.path.contains('/pb/page')) {
        final response = PbPageResponse()
          ..mergeFromProto3Json({
            'data': {
              'anti': {'tbs': 'fresh-tbs'},
              'thread': {'id': '123'},
            },
          });
        return binary(response.writeToBuffer());
      }
      final request = AddPostRequest.fromBuffer(multipartData(options, bytes));
      final json = normalizeJson(request.toProto3Json());
      final data = objectValue(json['data']);
      expect(objectValue(data['common'])['tbs'], 'fresh-tbs');
      expect(data['quote_id'], '100');
      expect(data['sub_post_id'], '101');
      expect(data['content'], 'A synthetic reply.');
      final response = AddPostResponse()
        ..mergeFromProto3Json({
          'data': {'pid': '999'},
        });
      return binary(response.writeToBuffer());
    });
    final api = TiebaApi(
      sessionProvider: () => session,
      dio: Dio()..httpClientAdapter = adapter,
    );
    await api.threadPosts('123');
    expect(
      await api.reply(
        content: 'A synthetic reply.',
        forum: const Forum(id: '9', name: 'Forum'),
        threadId: '123',
        parentPostId: '100',
        subPostId: '101',
      ),
      '999',
    );
    api.close();
  });

  test('Sofire decodes a synthetic encrypted device-token response', () async {
    const deviceId = 'synthetic-installation-id';
    final cuid =
        '${md5.convert(utf8.encode(deviceId)).toString().toUpperCase()}|0';
    final cuidHash = Uint8List.fromList(
      utf8.encode(md5.convert(utf8.encode(cuid)).toString()),
    );
    final key = Uint8List.fromList(utf8.encode('0123456789abcdef'));
    final adapter = FixtureAdapter((options, bytes) {
      expect(options.uri.host, 'sofire.baidu.com');
      expect(options.headers.containsKey('Cookie'), false);
      final payload = Uint8List.fromList(
        utf8.encode(jsonEncode({'token': 'synthetic-zid'})),
      );
      return jsonBody({
        'skey': base64Encode(rc442(key, cuidHash)),
        'data': base64Encode([
          ...sofireAes(payload, key, encrypt: true),
          ...List.filled(16, 0),
        ]),
      });
    });
    final transport = TiebaTransport(
      sessionProvider: () => null,
      deviceId: deviceId,
      dio: Dio()..httpClientAdapter = adapter,
    );
    expect(await transport.fetchZid(), 'synthetic-zid');
    transport.close();
  });
}
