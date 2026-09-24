import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_lite/core/local_store.dart';
import 'package:tieba_lite/core/models.dart';
import 'package:tieba_lite/core/session_store.dart';
import 'package:tieba_lite/core/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  TiebaSession account(String id) => TiebaSession(
    bduss: 'fixture-bduss-$id',
    stoken: 'fixture-stoken-$id',
    userId: id,
    rawCookie: 'BDUSS=fixture-bduss-$id; STOKEN=fixture-stoken-$id',
    user: UserProfile(id: id, name: 'Fixture $id'),
  );

  test('accounts survive restart without credentials in preferences', () async {
    final sessions = SessionStore();
    await sessions.init();
    await sessions.saveSession(account('1001'));
    await sessions.saveSession(account('1002'), activate: false);
    final installId = sessions.installId;
    final restarted = SessionStore();
    await restarted.init();
    expect(restarted.accounts.map((item) => item.id), ['1001', '1002']);
    expect(restarted.currentAccount?.id, '1001');
    expect(restarted.installId, installId);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), isEmpty);
    await restarted.remove('1002');
    expect(restarted.currentAccount?.id, '1001');
    await restarted.activate(null);
    expect(restarted.currentAccount, isNull);
    expect(restarted.accounts, hasLength(1));
    await restarted.remove('1001');
    expect(restarted.accounts, isEmpty);
  });

  test('malformed secure data fails without replacing the original', () async {
    const key = 'tieba_lite.accounts.v1';
    FlutterSecureStorage.setMockInitialValues({key: '{invalid'});
    await expectLater(SessionStore().init(), throwsFormatException);
    expect(await const FlutterSecureStorage().read(key: key), '{invalid');
  });

  test(
    'malformed account shape is preserved instead of becoming empty accounts',
    () async {
      const key = 'tieba_lite.accounts.v1';
      const raw = '{"version":1,"installId":"fixture","accounts":{}}';
      FlutterSecureStorage.setMockInitialValues({key: raw});
      await expectLater(SessionStore().init(), throwsFormatException);
      expect(await const FlutterSecureStorage().read(key: key), raw);
    },
  );

  test(
    'profile identity cannot be paired with another account session',
    () async {
      final sessions = SessionStore();
      await sessions.init();
      await expectLater(
        sessions.save(
          StoredAccount(
            profile: const UserProfile(id: '1002'),
            session: account('1001'),
          ),
        ),
        throwsArgumentError,
      );
      expect(sessions.accounts, isEmpty);
    },
  );

  test(
    'failed secure write preserves current identity and the queue recovers',
    () async {
      final storage = _FailingStorage();
      final sessions = SessionStore(storage: storage);
      await sessions.init();
      await sessions.saveSession(account('1001'));
      storage.failWrites = true;
      await expectLater(
        sessions.saveSession(account('1002')),
        throwsStateError,
      );
      expect(sessions.currentAccount?.id, '1001');
      expect(sessions.accounts, hasLength(1));
      storage.failWrites = false;
      await sessions.saveSession(account('1002'));
      expect(sessions.currentAccount?.id, '1002');
    },
  );

  test(
    'queued account writes do not appear in another account namespace',
    () async {
      final local = LocalStore();
      await local.init(accountId: '1001');
      final history = local.recordHistory(
        HistoryEntry(threadId: '2001', title: 'Account one'),
      );
      final switched = local.activateAccount('1002');
      final draft = local.saveDraft(
        ReplyDraft(
          key: 'thread-2001',
          threadId: '2001',
          content: 'Account one draft',
        ),
      );
      await Future.wait([history, switched, draft]);
      expect(local.histories, isEmpty);
      expect(local.drafts, isEmpty);
      await local.recordHistory(
        HistoryEntry(threadId: '2002', title: 'Account two'),
      );
      await local.activateAccount('1001');
      expect(local.histories.single.threadId, '2001');
      expect(local.getDraft('thread-2001')?.content, 'Account one draft');
      await local.activateAccount(null);
      expect(local.histories, isEmpty);
    },
  );

  test('malformed local data remains available for recovery', () async {
    final key = 'tieba_lite.local.v1.${base64Url.encode(utf8.encode('1001'))}';
    SharedPreferences.setMockInitialValues({key: '{invalid'});
    await expectLater(
      LocalStore().init(accountId: '1001'),
      throwsFormatException,
    );
    expect((await SharedPreferences.getInstance()).getString(key), '{invalid');
  });

  test(
    'failed account activation hides old records and prevents overwrite',
    () async {
      final corruptKey =
          'tieba_lite.local.v1.${base64Url.encode(utf8.encode('1002'))}';
      SharedPreferences.setMockInitialValues({corruptKey: '{invalid'});
      final local = LocalStore();
      await local.init(accountId: '1001');
      await local.recordHistory(
        HistoryEntry(threadId: '2001', title: 'Private to account one'),
      );
      await expectLater(local.activateAccount('1002'), throwsFormatException);
      expect(local.histories, isEmpty);
      await expectLater(
        local.rememberSearch('Blocked write'),
        throwsStateError,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(corruptKey),
        '{invalid',
      );
      await local.activateAccount('1001');
      expect(local.histories.single.threadId, '2001');
    },
  );

  test(
    'block filtering covers user, thread, forum, and content keyword',
    () async {
      final local = LocalStore();
      await local.init();
      await local.blockUser(
        const UserProfile(id: '1001', name: 'Blocked user'),
      );
      expect(
        local.blocksPost(const Post(author: UserProfile(id: '1001'))),
        isTrue,
      );
      await local.unblockUser('1001');
      expect(
        local.blocksPost(const Post(author: UserProfile(id: '1001'))),
        isFalse,
      );
      await local.addBlock(
        const BlockRule(kind: BlockKind.forum, value: 'Games'),
      );
      expect(
        local.blocksThread(const ThreadSummary(forum: Forum(name: 'Games'))),
        isTrue,
      );
      await local.addBlock(
        const BlockRule(kind: BlockKind.keyword, value: 'Spoiler'),
      );
      expect(
        local.blocksThread(const ThreadSummary(title: 'Spoiler warning')),
        isTrue,
      );
      expect(
        local.blocksPost(
          const Post(content: [ContentPart(text: 'Spoiler text')]),
        ),
        isTrue,
      );
      await local.addBlock(
        const BlockRule(kind: BlockKind.thread, value: '2001'),
      );
      expect(local.blocksPost(const Post(threadId: '2001')), isTrue);
    },
  );

  test(
    'preference reset preserves records and rejects credential keys',
    () async {
      final settings = SettingsStore();
      final local = LocalStore();
      await settings.init();
      await local.init();
      await local.rememberSearch('Flutter');
      await settings.setDouble('fontScale', 1.5);
      expect(settings.fontScale, 1.5);
      await expectLater(
        settings.setString('BDUSS', 'fixture'),
        throwsArgumentError,
      );
      await settings.reset();
      expect(settings.fontScale, 1);
      expect(local.searchQueries, ['Flutter']);
    },
  );
  test(
    'sent draft is hidden immediately and new draft can use the same key',
    () async {
      final local = LocalStore();
      await local.init(accountId: '1001');
      await local.saveDraft(
        ReplyDraft(
          key: 'thread-2001',
          threadId: '2001',
          content: 'Already sent',
        ),
      );
      final cleanup = local.markDraftSent('thread-2001');
      expect(local.getDraft('thread-2001'), isNull);
      await cleanup;
      await local.saveDraft(
        ReplyDraft(key: 'thread-2001', threadId: '2001', content: 'New reply'),
      );
      expect(local.getDraft('thread-2001')?.content, 'New reply');
      await local.activateAccount('1002');
      expect(local.getDraft('thread-2001'), isNull);
    },
  );
  test('late reply success only removes the sending account draft', () async {
    final local = LocalStore();
    await local.init(accountId: '1001');
    await local.saveDraft(
      ReplyDraft(key: 'reply', threadId: '2001', content: 'First'),
    );
    await local.activateAccount('1002');
    await local.saveDraft(
      ReplyDraft(key: 'reply', threadId: '2001', content: 'Second'),
    );
    await local.markDraftSent('reply', expectedAccountId: '1001');
    expect(local.getDraft('reply')?.content, 'Second');
    await local.activateAccount('1001');
    expect(local.getDraft('reply'), isNull);
    await local.activateAccount('1002');
    expect(local.getDraft('reply')?.content, 'Second');
  });

  test('legacy recent forums migrate without inventing visit dates', () async {
    const key = 'tieba_lite.local.v1.guest';
    SharedPreferences.setMockInitialValues({
      key: jsonEncode({
        'version': 1,
        'history': [
          {'threadId': '2001', 'title': 'Legacy'},
        ],
        'recentForums': [
          const Forum(id: '3001', name: 'Legacy forum').toJson(),
        ],
      }),
    });
    final local = LocalStore();
    await local.init();
    expect(local.histories.single.onlyAuthor, isFalse);
    expect(local.forumHistories.single.forum.name, 'Legacy forum');
    expect(local.forumHistories.single.visitedAt, isNull);
    await local.recordForum(const Forum(id: '3001', name: 'Legacy forum'));
    expect(local.forumHistories, hasLength(1));
    expect(local.forumHistories.single.visitedAt, isNotNull);
    await local.recordHistory(
      HistoryEntry(threadId: '2001', title: 'Updated', onlyAuthor: true),
    );
    final restarted = LocalStore();
    await restarted.init();
    expect(restarted.histories.single.onlyAuthor, isTrue);
    expect(
      restarted.forumHistories.single.visitedAt,
      local.forumHistories.single.visitedAt,
    );
  });

  test(
    'forum history removal keeps recents consistent and stays account scoped',
    () async {
      final local = LocalStore();
      await local.init(accountId: '1001');
      await local.recordForum(const Forum(id: '3001', name: 'First'));
      await local.recordForum(const Forum(id: '3002', name: 'Second'));
      final remove = local.removeForumHistory('First');
      final change = local.activateAccount('1002');
      await Future.wait([remove, change]);
      expect(local.forumHistories, isEmpty);
      await local.recordForum(const Forum(id: '3001', name: 'First'));
      await local.activateAccount('1001');
      expect(local.forumHistories.map((entry) => entry.forum.name), ['Second']);
      expect(local.recentForums.map((forum) => forum.name), ['Second']);
      await local.clearForumHistory();
      expect(local.recentForums, isEmpty);
      await local.activateAccount('1002');
      expect(local.forumHistories.single.forum.name, 'First');
    },
  );

  test('keyword groups are case-sensitive AND matches with content-scoped allowlists', () async {
    final local = LocalStore();
    await local.init();
    await local.addBlock(
      const BlockRule(
        kind: BlockKind.keyword,
        value: 'group',
        keywords: ['Alpha', 'Beta'],
      ),
    );
    expect(local.blocksContent('Alpha only'), isFalse);
    expect(local.blocksContent('alpha Beta'), isFalse);
    expect(local.blocksContent('Alpha and Beta'), isTrue);
    expect(
      local.blocksThread(const ThreadSummary(title: 'Alpha', excerpt: 'Beta')),
      isFalse,
    );
    await local.addBlock(
      const BlockRule(
        kind: BlockKind.keyword,
        value: 'allowed',
        keywords: ['trusted', 'reference'],
        allow: true,
      ),
    );
    expect(local.blocksContent('Alpha Beta trusted'), isTrue);
    expect(local.blocksContent('Alpha Beta trusted reference'), isFalse);
    expect(
      local.blocksThread(
        const ThreadSummary(title: 'Alpha Beta', excerpt: 'trusted reference'),
      ),
      isTrue,
    );
    await local.addBlock(
      const BlockRule(
        kind: BlockKind.keyword,
        value: 'group',
        keywords: ['Alpha', 'Beta'],
        allow: true,
      ),
    );
    expect(local.blockRules, hasLength(3));
    await local.removeBlock(BlockKind.keyword, 'group', allow: true);
    expect(local.blocksContent('Alpha Beta'), isTrue);
    final restarted = LocalStore();
    await restarted.init();
    expect(restarted.blocksContent('Alpha Beta trusted reference'), isFalse);
    expect(restarted.blocksContent('Alpha Beta'), isTrue);
  });

  test('user allowlists do not override keyword blocks or conflate nickname with username', () async {
    final local = LocalStore();
    await local.init();
    const author = UserProfile(
      id: '1001',
      username: 'canonical',
      name: 'Nickname',
    );
    await local.addBlock(
      const BlockRule(kind: BlockKind.user, value: 'canonical'),
    );
    expect(local.blocksUser(author), isTrue);
    expect(
      local.blocksUser(
        const UserProfile(id: '2002', username: 'other', name: 'canonical'),
      ),
      isFalse,
    );
    await local.addBlock(
      const BlockRule(kind: BlockKind.user, value: '1001', allow: true),
    );
    expect(local.blocksUser(author), isFalse);
    expect(local.blockedUserIds, {'canonical'});
    await local.addBlock(
      const BlockRule(kind: BlockKind.keyword, value: 'blocked'),
    );
    expect(
      local.blocksThread(const ThreadSummary(author: author, title: 'blocked')),
      isTrue,
    );
    await local.removeBlock(BlockKind.user, '1001', allow: true);
    expect(local.blocksUser(author), isTrue);
  });
}

class _FailingStorage extends FlutterSecureStorage {
  bool failWrites = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (failWrites) {
      return Future.error(StateError('Fixture secure storage failure'));
    }
    return super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}
