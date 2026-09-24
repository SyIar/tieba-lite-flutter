import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_lite/platform/deep_links.dart';

void main() {
  test('thread deep links retain page and post identity', () {
    final link = TiebaLink.parse(
      Uri.parse('tblite://thread/12345?pid=67890&pn=4'),
    );
    expect(link?.kind, TiebaLinkKind.thread);
    expect(link?.value, '12345');
    expect(link?.postId, '67890');
    expect(link?.page, 4);
    final web = TiebaLink.parse(
      Uri.parse('https://tieba.baidu.com/p/12345?pn=-5'),
    );
    expect(web?.value, '12345');
    expect(web?.page, 1);
  });

  test('forum routes decode query and path values once', () {
    expect(
      TiebaLink.parse(Uri.parse('tblite://forum/Flutter%20dev'))?.value,
      'Flutter dev',
    );
    expect(
      TiebaLink.parse(Uri.parse('https://tieba.baidu.com/f?kw=Flutter%2Bdev'))
          ?.value,
      'Flutter+dev',
    );
  });

  test(
    'external hosts, unsupported actions, and malformed IDs are ignored',
    () {
      for (final value in [
        'https://tieba.baidu.com.evil.example/p/12345',
        'https://evil.example/p/12345',
        'javascript:alert(1)',
        'file:///p/12345',
        'tblite://thread/not-a-number',
        'tblite://thread/0',
        'tblite://thread/12345/extra',
        'tblite://login?BDUSS=fixture',
        'tblite://reply/12345?content=fixture',
      ]) {
        expect(TiebaLink.parse(Uri.parse(value)), isNull, reason: value);
      }
    },
  );
}
