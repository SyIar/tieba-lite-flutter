import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_lite/core/models.dart';
import 'package:tieba_lite/platform/baidu_action_page.dart';
import 'package:tieba_lite/platform/baidu_web_session.dart';

void main() {
  test('only exact official HTTPS action origins accept credentials', () {
    expect(
      BaiduActionPolicy.accepts(
        Uri.parse('https://tieba.baidu.com/pmc'),
        initial: true,
      ),
      isTrue,
    );
    for (final value in [
      'https://tieba.baidu.com.evil.example/pmc',
      'https://evil.example/?url=https://tieba.baidu.com/',
      'https://tieba.baidu.com@evil.example/pmc',
      'https://user@tieba.baidu.com/pmc',
      'https://tieba.baidu.com:444/pmc',
      'http://tieba.baidu.com/pmc',
      'https://arbitrary.baidu.com/pmc',
      'file:///pmc',
    ]) {
      expect(
        BaiduActionPolicy.accepts(Uri.parse(value), initial: true),
        isFalse,
        reason: value,
      );
    }
    final login = Uri.parse('https://wappass.baidu.com/passport');
    expect(BaiduActionPolicy.accepts(login), isTrue);
    expect(BaiduActionPolicy.accepts(login, initial: true), isFalse);
  });

  test('action injection keeps only validated session cookie names', () {
    const session = TiebaSession(
      bduss: 'fixture-bduss',
      stoken: 'fixture-stoken',
      userId: '1001',
      rawCookie: 'ignored=fixture; baiduid=fixture-device; BDUSS=obsolete; other=ignored',
    );
    expect(BaiduActionPolicy.cookies(session), {
      'BDUSS': 'fixture-bduss',
      'STOKEN': 'fixture-stoken',
      'BAIDUID': 'fixture-device',
    });
    expect(
      () => BaiduActionPolicy.cookies(
        TiebaSession.fromJson({...session.toJson(), 'bduss': 'bad\r\nvalue'}),
      ),
      throwsFormatException,
    );
  });

  test('simultaneous views cannot share an account cookie store', () async {
    var clears = 0;
    final coordinator = BaiduWebSessionCoordinator(
      clearStore: () async {
        clears++;
      },
    );
    final first = await coordinator.acquire();
    await expectLater(coordinator.acquire(), throwsStateError);
    expect(clears, 1);
    await first.close();
    final second = await coordinator.acquire();
    final beforeStaleClose = clears;
    await first.close();
    expect(clears, beforeStaleClose);
    expect(second.active, isTrue);
    await second.close();
  });

  test('new credentials wait for disposal cleanup', () async {
    final events = <String>[];
    final gate = Completer<void>();
    var clears = 0;
    final coordinator = BaiduWebSessionCoordinator(
      clearStore: () async {
        clears++;
        events.add('clear-$clears');
        if (clears == 2) await gate.future;
      },
    );
    final first = await coordinator.acquire();
    final close = first.close();
    final next = coordinator.acquire(
      configure: () async {
        events.add('new-cookie');
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(events, ['clear-1', 'clear-2']);
    gate.complete();
    await close;
    final second = await next;
    expect(events, ['clear-1', 'clear-2', 'clear-3', 'new-cookie']);
    await second.close();
  });

  test(
    'failed configuration releases its lease and clears partial cookies',
    () async {
      var clears = 0;
      final coordinator = BaiduWebSessionCoordinator(
        clearStore: () async {
          clears++;
        },
      );
      await expectLater(
        coordinator.acquire(
          configure: () async {
            throw StateError('Fixture injection failure');
          },
        ),
        throwsStateError,
      );
      expect(clears, 2);
      final recovered = await coordinator.acquire();
      expect(clears, 3);
      await recovered.close();
    },
  );
}
