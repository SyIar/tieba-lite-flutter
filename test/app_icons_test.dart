import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_lite/platform/app_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.tblite.flutter/app_icons');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'icon selection uses only allowed bundled names and reflects system state',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var current = 'default';
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'supported':
            return true;
          case 'current':
            return current;
          case 'set':
            current = call.arguments as String;
            return null;
        }
        throw MissingPluginException();
      });
      await AppIcons.set('blue');
      expect(await AppIcons.current(), 'blue');
      await expectLater(AppIcons.set('../../outside'), throwsArgumentError);
      expect(await AppIcons.current(), 'blue');
      await AppIcons.set('default');
      expect(await AppIcons.current(), 'default');
    },
  );

  test('system icon failures propagate and unsupported platforms never invoke native channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'supported') return true;
      if (call.method == 'current') return 'default';
      throw PlatformException(code: 'icon_change_failed');
    });
    await expectLater(AppIcons.set('dark'), throwsA(isA<PlatformException>()));
    expect(await AppIcons.current(), 'default');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => fail('Unexpected native icon invocation'),
    );
    expect(await AppIcons.supported(), isFalse);
    expect(await AppIcons.current(), 'default');
    await expectLater(AppIcons.set('blue'), throwsUnsupportedError);
  });
}
